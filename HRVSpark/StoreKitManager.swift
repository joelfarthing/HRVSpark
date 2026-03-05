import Foundation
import StoreKit
import Combine
import WatchConnectivity
import WidgetKit

/// Manages IAP for the Pro unlock using StoreKit 2.
/// Persists entitlement to App Group UserDefaults so the complication extension can read it.
@MainActor
class StoreKitManager: ObservableObject {
    
    static let shared = StoreKitManager()
    
    static let proProductID = "com.filamentlabs.HRVSpark.pro"
    static let appGroupID = "group.com.filamentlabs.HRVSpark"
    static let proUnlockedKey = "isProUnlocked"
    
    static let tipJarProductID = "com.filamentlabs.HRVSpark.tipjar"
    
    @Published var isProUnlocked: Bool = false
    @Published var proProduct: Product?
    @Published var tipJarProduct: Product?
    @Published var purchaseInProgress: Bool = false
    @Published var statusMessage: String?
    
    private var transactionListener: Task<Void, Error>?
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: StoreKitManager.appGroupID)
    }
    
    private init() {
        // Read cached entitlement from App Group
        isProUnlocked = sharedDefaults?.bool(forKey: StoreKitManager.proUnlockedKey) ?? false
        
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
            let products = try await Product.products(for: [
                StoreKitManager.proProductID,
                StoreKitManager.tipJarProductID
            ])
            proProduct = products.first { $0.id == StoreKitManager.proProductID }
            tipJarProduct = products.first { $0.id == StoreKitManager.tipJarProductID }
        } catch {
            #if DEBUG
            print("StoreKitManager: Failed to fetch products: \(error.localizedDescription)")
            #endif
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
            // Directly unlock — we've already verified the transaction
            isProUnlocked = true
            sharedDefaults?.set(true, forKey: StoreKitManager.proUnlockedKey)
            syncProStatusToWatch(true)
            
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
        do {
            try await AppStore.sync()
        } catch {
            statusMessage = "Restore failed — check your internet connection and try again."
            #if DEBUG
            print("StoreKitManager: AppStore.sync() failed: \(error.localizedDescription)")
            #endif
        }
        await updateEntitlementStatus()
    }
    
    // MARK: - Tip Jar
    
    func purchaseTipJar() async throws {
        guard let product = tipJarProduct else { return }
        let result = try await product.purchase()
        if case .success(let verification) = result {
            let transaction = try checkVerified(verification)
            await transaction.finish()
            statusMessage = "Thank you! ☕"
        }
    }
    
    // MARK: - Entitlement Check
    
    func updateEntitlementStatus() async {
        let entitled = await checkEntitlement()
        isProUnlocked = entitled
        sharedDefaults?.set(entitled, forKey: StoreKitManager.proUnlockedKey)
        syncProStatusToWatch(entitled)
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
                    #if DEBUG
                    print("StoreKitManager: Transaction verification failed: \(error.localizedDescription)")
                    #endif
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
    
    // MARK: - Watch Sync
    
    nonisolated private func syncProStatusToWatch(_ unlocked: Bool) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        
        if session.activationState == .activated {
            session.transferUserInfo(["isProUnlocked": unlocked])
            WidgetCenter.shared.reloadAllTimelines()
        } else {
            // Session not yet activated — retry after a short delay
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                if session.activationState == .activated {
                    session.transferUserInfo(["isProUnlocked": unlocked])
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        }
    }
}
