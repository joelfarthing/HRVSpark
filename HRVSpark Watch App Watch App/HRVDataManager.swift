import Foundation
import HealthKit
import WidgetKit
import WatchConnectivity

@Observable
class HRVDataManager: NSObject, WCSessionDelegate {
    
    // Core HealthKit Properties
    private let healthStore = HKHealthStore()
    private let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    private let sharedSuiteName = "group.com.filamentlabs.HRVSpark"
    
    // Published State for the UI
    var isAuthorized: Bool = false
    var errorMessage: String? = nil
    var lastCompanionContextSyncDate: Date? = nil
    
    // The Data Cards
    var freeCardReading: Int? = nil // Free: Latest reading
    var proCard2Reading: Int? = nil // Pro: Last 60-min average
    var proCard3Reading: Int? = nil // Pro: Rolling 24-hour average
    var proCard4Reading: Int? = nil // Pro: Rolling 24-hour average (same number, different context in UI)
    
    var sparklineData8Hours: [Double?] = []
    var hourlyAverages8Hours: [Double?] = []
    var dailyAverages7Days: [Double?] = []
    var dailyAverages30Days: [Double?] = []
    
    private enum SharedCacheKey {
        static let dailyAverages7d = "companion.dailyAverages7d"
        static let dailyAverages30d = "companion.dailyAverages30d"
        static let rollingAvg24h = "companion.rollingAvg24h"
        static let contextUpdatedAt = "companion.contextUpdatedAt"
    }
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    // MARK: - WCSessionDelegate
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) { }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // Required for iOS compilation even inside watch extensions.
        session.activate()
    }
    #endif
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        guard isAuthorized else { return }
        _ = hydrateLongTermFromCompanionContext()
        requestLongTermDataFromCompanion()
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if applyLongTermPayloadToUI(applicationContext) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        if applyLongTermPayloadToUI(userInfo) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    // MARK: - 1. Authorization
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            DispatchQueue.main.async {
                self.errorMessage = "HealthKit is not available on this device."
                self.isAuthorized = false
            }
            completion(false)
            return
        }
        
        let typesToRead: Set = [hrvType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                }
                self.isAuthorized = success
                if success {
                    // Start fetching data immediately upon success
                    self.fetchAllData()
                }
            }
            completion(success)
        }
    }
    
    // MARK: - 2. Data Fetching Coordinator
    
    func fetchAllData() {
        guard isAuthorized else { return }
        
        // This is the main refresh function called by the UI
        fetchRawReadings(hoursBack: 8) { latest, sparkline in
            DispatchQueue.main.async {
                self.freeCardReading = latest
                self.sparklineData8Hours = sparkline
            }
        }
        fetchHourlyAveragesUI(hoursBack: 24)
        
        // Prefer companion-computed long-term payload when available.
        let didHydrateFromCompanion = hydrateLongTermFromCompanionContext()
        
        // Only use watch-local long-term queries when companion payload is unavailable.
        if !didHydrateFromCompanion {
            fetchDailyAverages(daysBack: 7) { averages in
                DispatchQueue.main.async { self.dailyAverages7Days = averages }
            }
            fetchDailyAverages(daysBack: 30) { averages in
                DispatchQueue.main.async { self.dailyAverages30Days = averages }
            }
            fetchRollingAverageUI(hoursBack: 24)
        }
        
        // Ask iPhone for a fresh payload when reachable, then apply it asynchronously.
        requestLongTermDataFromCompanion()
        
        // Always tell the watch face complications to update when we fetch new data!
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - 3. Specific Fetchers
    
    // Complication Data (Returns exactly what the widget needs)
    func fetchAllComplicationData(completion: @escaping (
        Int?,       // 1. latestReading
        [Double?],   // 2. sparkline8h
        [Double?],   // 3. hourlyAverages24h
        Int?,       // 4. rollingAvg1h
        Int?,       // 5. rollingAvg24h
        [Double?],   // 6. dailyAverages7d
        [Double?]    // 7. dailyAverages30d
    ) -> Void) {
        
        let group = DispatchGroup()
        
        var outLatestReading: Int? = nil
        var outSparkline8h: [Double?] = []
        var outHourlyAverages24h: [Double?] = []
        var outRollingAvg1h: Int? = nil
        var outRollingAvg24h: Int? = nil
        var outDailyAverages7d: [Double?] = []
        var outDailyAverages30d: [Double?] = []

        let applyLongTermPayload: ([String: Any]) -> Bool = { payload in
            let parsed = self.parseLongTermPayload(payload)
            var hasLongTermData = false
            
            if let series7d = parsed.dailyAverages7d, !series7d.isEmpty {
                outDailyAverages7d = series7d
                hasLongTermData = true
            }
            
            if let series30d = parsed.dailyAverages30d, !series30d.isEmpty {
                outDailyAverages30d = series30d
                hasLongTermData = true
            }
            
            if let val = parsed.rollingAvg24h {
                outRollingAvg24h = val
                hasLongTermData = true
            }
            
            if let updatedAt = parsed.updatedAt {
                DispatchQueue.main.async {
                    self.lastCompanionContextSyncDate = updatedAt
                }
            }
            
            return hasLongTermData
        }
        
        let applyKnownLongTermFromState: () -> Bool = {
            let has7d = !self.dailyAverages7Days.isEmpty
            let has30d = !self.dailyAverages30Days.isEmpty
            let has24h = self.proCard4Reading != nil
            guard has7d || has30d || has24h else { return false }
            
            if has7d {
                outDailyAverages7d = self.dailyAverages7Days
            }
            if has30d {
                outDailyAverages30d = self.dailyAverages30Days
            }
            if let rolling24h = self.proCard4Reading {
                outRollingAvg24h = rolling24h
            }
            return true
        }
        
        // Query 1: 8H Raw Sparkline & Latest Reading
        group.enter()
        fetchRawReadings(hoursBack: 8) { latest, sparkline in
            outLatestReading = latest
            outSparkline8h = sparkline
            group.leave()
        }
        
        // Query 2: 24H Hourly Averages & 1H Rolling Avg
        group.enter()
        fetchHourlyAverages(hoursBack: 24) { averages, mostRecentAvg in
            outHourlyAverages24h = averages
            outRollingAvg1h = mostRecentAvg
            group.leave()
        }
        
        let fallbackLocalLongTermFetches = {
            // Because we are called from inside the sendMessage reply,
            // we are already balancing the group.enter() made before sendMessage.
            // We just need to add *more* work to the group.
            
            // Query 3: 24H Rolling Average
            group.enter()
            self.fetchRollingAverage(hoursBack: 24) { avg in
                outRollingAvg24h = avg
                group.leave()
            }
            
            // Query 4: 7-Day Averages
            group.enter()
            self.fetchDailyAverages(daysBack: 7) { averages in
                outDailyAverages7d = averages
                group.leave()
            }
            
            // Query 5: 30-Day Averages
            group.enter()
            self.fetchDailyAverages(daysBack: 30) { averages in
                outDailyAverages30d = averages
                group.leave()
            }
        }
        
        // Prefer any already-hydrated companion payload/state before doing connectivity decisions.
        _ = self.hydrateLongTermFromCompanionContext()
        let hasLongTermFromState = applyKnownLongTermFromState()
        let hasLongTermFromSharedCache = applyLongTermPayload(self.loadLongTermPayloadFromSharedCache())
        let hasLongTermFromCachedContext = applyLongTermPayload(WCSession.isSupported() ? WCSession.default.receivedApplicationContext : [:])
        let alreadyHasLongTermData = hasLongTermFromState || hasLongTermFromSharedCache || hasLongTermFromCachedContext
        
        if alreadyHasLongTermData {
            group.notify(queue: .main) {
                completion(
                    outLatestReading,
                    outSparkline8h,
                    outHourlyAverages24h,
                    outRollingAvg1h,
                    outRollingAvg24h,
                    outDailyAverages7d,
                    outDailyAverages30d
                )
            }
            return
        }
        
        // Determine whether to utilize iOS Companion App for Queries 3-5.
        if WCSession.isSupported() && WCSession.default.isReachable {
            group.enter()
            WCSession.default.sendMessage(["request": "fetchLongTermData"], replyHandler: { reply in
                
                let didApplyReply = applyLongTermPayload(reply)
                if !didApplyReply {
                    let cachedPayload = WCSession.default.receivedApplicationContext
                    if !applyLongTermPayload(cachedPayload) {
                        fallbackLocalLongTermFetches()
                    }
                }
                
                group.leave()
                
            }, errorHandler: { _ in
                // Message failed: use cached companion context if present, otherwise fall back local.
                let cachedPayload = WCSession.default.receivedApplicationContext
                if !applyLongTermPayload(cachedPayload) {
                    fallbackLocalLongTermFetches()
                }
                group.leave()
            })
        } else {
            // Watch is not interactively reachable. Prefer cached companion payload; otherwise run local fallback.
            let cachedPayload = WCSession.isSupported() ? WCSession.default.receivedApplicationContext : [:]
            if !applyLongTermPayload(cachedPayload) {
                // We need to enter the group here because we aren't inside the sendMessage callback
                group.enter()
                fallbackLocalLongTermFetches()
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(
                outLatestReading,
                outSparkline8h,
                outHourlyAverages24h,
                outRollingAvg1h,
                outRollingAvg24h,
                outDailyAverages7d,
                outDailyAverages30d
            )
        }
    }
    
    // Long-term context hydration from iOS companion app.
    @discardableResult
    private func hydrateLongTermFromCompanionContext() -> Bool {
        guard WCSession.isSupported() else { return false }
        return applyLongTermPayloadToUI(WCSession.default.receivedApplicationContext)
    }
    
    private func requestLongTermDataFromCompanion() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard session.isReachable else { return }
        
        session.sendMessage(["request": "fetchLongTermData"], replyHandler: { reply in
            if self.applyLongTermPayloadToUI(reply) {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }, errorHandler: { _ in
            // Keep existing values; cached context/local data remains visible.
        })
    }
    
    @discardableResult
    private func applyLongTermPayloadToUI(_ payload: [String: Any]) -> Bool {
        let parsed = parseLongTermPayload(payload)
        let has7dSeries = parsed.dailyAverages7d?.isEmpty == false
        let has30dSeries = parsed.dailyAverages30d?.isEmpty == false
        let hasLongTermData = has7dSeries || has30dSeries || parsed.rollingAvg24h != nil
        
        guard hasLongTermData || parsed.updatedAt != nil else { return false }
        
        DispatchQueue.main.async {
            if let updated7d = parsed.dailyAverages7d, !updated7d.isEmpty {
                self.dailyAverages7Days = updated7d
            }
            if let updated30d = parsed.dailyAverages30d, !updated30d.isEmpty {
                self.dailyAverages30Days = updated30d
            }
            if let updated24h = parsed.rollingAvg24h {
                self.proCard3Reading = updated24h
                self.proCard4Reading = updated24h
            }
            if let updatedAt = parsed.updatedAt {
                self.lastCompanionContextSyncDate = updatedAt
            }
        }
        
        persistLongTermPayloadToSharedCache(
            dailyAverages7d: parsed.dailyAverages7d,
            dailyAverages30d: parsed.dailyAverages30d,
            rollingAvg24h: parsed.rollingAvg24h,
            updatedAt: parsed.updatedAt
        )
        
        return hasLongTermData
    }
    
    private func parseLongTermPayload(_ payload: [String: Any]) -> (dailyAverages7d: [Double?]?, dailyAverages30d: [Double?]?, rollingAvg24h: Int?, updatedAt: Date?) {
        let decodeOptionalSeries: (Any?) -> [Double?]? = { raw in
            guard let rawArray = raw as? [Any] else { return nil }
            return rawArray.map { element in
                if let value = element as? Double {
                    return value == -999.0 ? nil : value
                }
                if let number = element as? NSNumber {
                    let value = number.doubleValue
                    return value == -999.0 ? nil : value
                }
                return nil
            }
        }
        
        let dailyAverages7d = decodeOptionalSeries(payload["dailyAverages7d"])
        let dailyAverages30d = decodeOptionalSeries(payload["dailyAverages30d"])
        let rollingAvg24h = (payload["rollingAvg24h"] as? Int) ?? (payload["rollingAvg24h"] as? NSNumber).map { $0.intValue }
        let updatedAt = (payload["contextUpdatedAt"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
        return (dailyAverages7d, dailyAverages30d, rollingAvg24h, updatedAt)
    }
    
    private func persistLongTermPayloadToSharedCache(dailyAverages7d: [Double?]?, dailyAverages30d: [Double?]?, rollingAvg24h: Int?, updatedAt: Date?) {
        guard let defaults = UserDefaults(suiteName: sharedSuiteName) else { return }
        
        if let series7d = dailyAverages7d, !series7d.isEmpty {
            defaults.set(series7d.map { $0 ?? -999.0 }, forKey: SharedCacheKey.dailyAverages7d)
        }
        if let series30d = dailyAverages30d, !series30d.isEmpty {
            defaults.set(series30d.map { $0 ?? -999.0 }, forKey: SharedCacheKey.dailyAverages30d)
        }
        if let rollingAvg24h {
            defaults.set(rollingAvg24h, forKey: SharedCacheKey.rollingAvg24h)
        }
        if let updatedAt {
            defaults.set(updatedAt.timeIntervalSince1970, forKey: SharedCacheKey.contextUpdatedAt)
        }
    }
    
    private func loadLongTermPayloadFromSharedCache() -> [String: Any] {
        guard let defaults = UserDefaults(suiteName: sharedSuiteName) else { return [:] }
        
        var payload: [String: Any] = [:]
        
        if let series7d = defaults.array(forKey: SharedCacheKey.dailyAverages7d) as? [Double], !series7d.isEmpty {
            payload["dailyAverages7d"] = series7d
        }
        if let series30d = defaults.array(forKey: SharedCacheKey.dailyAverages30d) as? [Double], !series30d.isEmpty {
            payload["dailyAverages30d"] = series30d
        }
        if let rollingRaw = defaults.object(forKey: SharedCacheKey.rollingAvg24h) as? NSNumber {
            payload["rollingAvg24h"] = rollingRaw.intValue
        }
        if let updatedAtRaw = defaults.object(forKey: SharedCacheKey.contextUpdatedAt) as? NSNumber {
            payload["contextUpdatedAt"] = updatedAtRaw.doubleValue
        }
        
        return payload
    }
    
    private func fetchRawReadings(hoursBack: Int, completion: @escaping (Int?, [Double?]) -> Void) {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -hoursBack, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        var interval = DateComponents()
        interval.minute = 5 // Bucket the "raw" readings into 5-minute intervals to establish a strict timeline
        
        // Define anchor date to the start of the 5-minute block
        let anchorDate = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: startDate), minute: (Calendar.current.component(.minute, from: startDate) / 5) * 5, second: 0, of: startDate)!
        
        let query = HKStatisticsCollectionQuery(quantityType: hrvType, quantitySamplePredicate: predicate, options: .discreteAverage, anchorDate: anchorDate, intervalComponents: interval)
        
        query.initialResultsHandler = { _, results, error in
            guard let statsCollection = results, error == nil else {
                completion(nil, [])
                return
            }
            
            var readings: [Double?] = []
            var latestReading: Int? = nil
            
            statsCollection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                if let quantity = statistics.averageQuantity() {
                    let valueInMs = quantity.doubleValue(for: HKUnit.second()) * 1000
                    readings.append(valueInMs)
                    latestReading = Int(round(valueInMs)) // Will retain the last non-nil value
                } else {
                    readings.append(nil) // Explicitly denote missing data bucket for the dashed line
                }
            }
            
            completion(latestReading, readings)
        }
        healthStore.execute(query)
    }
    
    // Pro Card 2: Hourly averages + last 60 minutes
    private func fetchHourlyAverages(hoursBack: Int, completion: @escaping ([Double?], Int?) -> Void) {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -hoursBack, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        var interval = DateComponents()
        interval.hour = 1
        
        // Find exactly the start of the hour from X hours ago
        let anchorDate = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: startDate), minute: 0, second: 0, of: startDate)!
        
        let query = HKStatisticsCollectionQuery(quantityType: hrvType, quantitySamplePredicate: predicate, options: .discreteAverage, anchorDate: anchorDate, intervalComponents: interval)
        
        query.initialResultsHandler = { _, results, error in
            guard let statsCollection = results, error == nil else {
                completion([], nil)
                return
            }
            
            var averages: [Double?] = []
            var mostRecentHourAvg: Double? = nil
            
            statsCollection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                if let quantity = statistics.averageQuantity() {
                    let valueInMs = quantity.doubleValue(for: HKUnit.second()) * 1000
                    averages.append(valueInMs)
                    mostRecentHourAvg = valueInMs // Will end up holding the very last valid bucket
                } else {
                    averages.append(nil) // Explicitly denote missing data bucket
                }
            }
            
            if let lastAvg = mostRecentHourAvg {
                completion(averages, Int(round(lastAvg)))
            } else {
                completion(averages, nil)
            }
        }
        healthStore.execute(query)
    }
    
    // Overload for the UI's fetchAllData()
    private func fetchHourlyAveragesUI(hoursBack: Int) {
        fetchHourlyAverages(hoursBack: hoursBack) { averages, mostRecentHourAvg in
            DispatchQueue.main.async {
                self.hourlyAverages8Hours = averages
                self.proCard2Reading = mostRecentHourAvg
            }
        }
    }
    
    // Pro Cards 3 & 4 Graph Data
    private func fetchDailyAverages(daysBack: Int, completion: @escaping ([Double?]) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        // Build exactly N day buckets, ending with today.
        let startDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -(daysBack - 1), to: now)!)
        let endDate = now
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        var interval = DateComponents()
        interval.day = 1
        
        let anchorDate = calendar.startOfDay(for: startDate)
        
        let query = HKStatisticsCollectionQuery(quantityType: hrvType, quantitySamplePredicate: predicate, options: .discreteAverage, anchorDate: anchorDate, intervalComponents: interval)
        
        query.initialResultsHandler = { _, results, error in
            guard let statsCollection = results, error == nil else {
                completion([])
                return
            }
            
            var averagesByDay: [Date: Double] = [:]
            
            statsCollection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                if let quantity = statistics.averageQuantity() {
                    let valueInMs = quantity.doubleValue(for: HKUnit.second()) * 1000
                    let dayStart = calendar.startOfDay(for: statistics.startDate)
                    averagesByDay[dayStart] = valueInMs
                }
            }
            
            let normalizedSeries: [Double?] = (0..<daysBack).map { dayOffset in
                let day = calendar.date(byAdding: .day, value: dayOffset, to: startDate)!
                let dayStart = calendar.startOfDay(for: day)
                return averagesByDay[dayStart]
            }
            
            completion(normalizedSeries)
        }
        healthStore.execute(query)
    }
    
    // Pro Cards 3 & 4 Top Number (Rolling 24hr Avg)
    private func fetchRollingAverage(hoursBack: Int, completion: @escaping (Int?) -> Void) {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -hoursBack, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: hrvType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
            guard let result = result, let average = result.averageQuantity(), error == nil else {
                completion(nil)
                return
            }
            
            let valueInMs = average.doubleValue(for: HKUnit.second()) * 1000
            completion(Int(round(valueInMs)))
        }
        healthStore.execute(query)
    }
    
    // Overload for the UI's fetchAllData()
    private func fetchRollingAverageUI(hoursBack: Int) {
        fetchRollingAverage(hoursBack: hoursBack) { avg in
            DispatchQueue.main.async {
                self.proCard3Reading = avg
                self.proCard4Reading = avg
            }
        }
    }
}
