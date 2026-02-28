import Foundation
import StoreKit
import Combine

/// Manages IAP for the Pro unlock using StoreKit 2.
/// Persists entitlement to App Group UserDefaults so the complication extension can read it.
@MainActor
class StoreKitManager: ObservableObject {
    
    static let shared = StoreKitManager()
    
    static let proProductID = "com.filamentlabs.HRVSpark.pro"
    static let appGroupID = "group.com.filamentlabs.HRVSpark"
    static let proUnlockedKey = "isProUnlocked"
    
    // MARK: - Beta Auto-Unlock (TEMPORARY — remove before production paid launch)
    /// Returns true when running as a TestFlight beta build.
    static var isTestFlight: Bool {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else { return true }
        return receiptURL.lastPathComponent == "sandboxReceipt"
    }
    
    @Published var isProUnlocked: Bool = false
    @Published var proProduct: Product?
    @Published var purchaseInProgress: Bool = false
    @Published var statusMessage: String?
    
    private var transactionListener: Task<Void, Error>?
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: StoreKitManager.appGroupID)
    }
    
    private init() {
        // Beta auto-unlock: grant Pro to all TestFlight testers (TEMPORARY)
        if StoreKitManager.isTestFlight {
            isProUnlocked = true
            sharedDefaults?.set(true, forKey: StoreKitManager.proUnlockedKey)
        } else {
            // Read cached entitlement from App Group
            isProUnlocked = sharedDefaults?.bool(forKey: StoreKitManager.proUnlockedKey) ?? false
        }
        
        // Start listening for transaction updates (family sharing, refunds, etc.)
        transactionListener = listenForTransactions()
        
        // Check current entitlement + fetch product
        Task {
            await updateEntitlementStatus()
            await fetchProduct()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Fetch Product
    
    func fetchProduct() async {
        do {
            let products = try await Product.products(for: [StoreKitManager.proProductID])
            proProduct = products.first
        } catch {
            print("StoreKitManager: Failed to fetch products: \(error)")
        }
    }
    
    // MARK: - Purchase
    
    func purchase() async throws {
        purchaseInProgress = true
        statusMessage = nil
        defer { purchaseInProgress = false }
        
        // Retry product fetch if not yet loaded
        if proProduct == nil {
            await fetchProduct()
        }
        guard let product = proProduct else {
            statusMessage = "Pro upgrade not yet available — please try again in a few minutes."
            return
        }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updateEntitlementStatus()
            
        case .userCancelled:
            break
            
        case .pending:
            // Ask-to-buy or similar — will resolve via transaction listener
            break
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Restore
    
    func restore() async {
        try? await AppStore.sync()
        await updateEntitlementStatus()
    }
    
    // MARK: - Entitlement Check
    
    func updateEntitlementStatus() async {
        // Don't overwrite beta auto-unlock with real entitlement check
        if StoreKitManager.isTestFlight {
            isProUnlocked = true
            sharedDefaults?.set(true, forKey: StoreKitManager.proUnlockedKey)
            return
        }
        let entitled = await checkEntitlement()
        isProUnlocked = entitled
        sharedDefaults?.set(entitled, forKey: StoreKitManager.proUnlockedKey)
    }
    
    private func checkEntitlement() async -> Bool {
        guard let result = await Transaction.currentEntitlement(for: StoreKitManager.proProductID) else {
            return false
        }
        do {
            let transaction = try checkVerified(result)
            return transaction.revocationDate == nil
        } catch {
            return false
        }
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try self?.checkVerified(result)
                    await transaction?.finish()
                    await self?.updateEntitlementStatus()
                } catch {
                    print("StoreKitManager: Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Verification
    
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
