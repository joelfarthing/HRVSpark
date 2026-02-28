import Foundation
import HealthKit
import WatchConnectivity
import SwiftUI

@Observable
class iOSDataManager: NSObject, WCSessionDelegate {
    
    // Core HealthKit Properties
    private let healthStore = HKHealthStore()
    private let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    
    // Published State for the UI
    var isAuthorized: Bool = false
    var errorMessage: String? = nil
    var lastCompanionContextPublishDate: Date? = nil
    
    // The Data Cards
    var freeCardReading: Int? = nil // Free: Latest reading
    var proCard2Reading: Int? = nil // Pro: Last 60-min average
    var proCard3Reading: Int? = nil // Pro: Rolling 24-hour average
    var proCard4Reading: Int? = nil // Pro: Rolling 24-hour average (same number, different context in UI)
    
    var sparklineData8Hours: [Double?] = []
    var hourlyAverages8Hours: [Double?] = []
    var dailyAverages7Days: [Double?] = []
    var dailyAverages30Days: [Double?] = []
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
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
                    self.fetchAllData()
                }
            }
            completion(success)
        }
    }
    
    // MARK: - 2. Data Fetching Coordinator (UI)
    
    func fetchAllData() {
        guard isAuthorized else { return }
        
        // This is the main refresh function called by the iOS UI
        fetchRawReadings(hoursBack: 8) { latest, sparkline in
            DispatchQueue.main.async {
                self.freeCardReading = latest
                self.sparklineData8Hours = sparkline
            }
        }
        fetchHourlyAveragesUI(hoursBack: 24)
        fetchDailyAverages(daysBack: 7) { averages in
            DispatchQueue.main.async { self.dailyAverages7Days = averages }
        }
        fetchDailyAverages(daysBack: 30) { averages in
            DispatchQueue.main.async { self.dailyAverages30Days = averages }
        }
        fetchRollingAverageUI(hoursBack: 24)
        
        // Publish long-term aggregates for complications via cached WCSession context.
        publishLongTermComplicationContext()
    }
    
    // MARK: - Watch Connectivity Payload Service
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        guard isAuthorized else { return }
        publishLongTermComplicationContext()
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) { }
    
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif
    
    // When the watch asks for heavy lifting:
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        if message["request"] as? String == "fetchLongTermData" {
            let group = DispatchGroup()
            
            var array7D: [Double?] = []
            var array30D: [Double?] = []
            var current24: Int? = nil
            
            group.enter()
            fetchDailyAverages(daysBack: 7) { averages in
                array7D = averages
                group.leave()
            }
            
            group.enter()
            fetchDailyAverages(daysBack: 30) { averages in
                array30D = averages
                group.leave()
            }
            
            group.enter()
            fetchRollingAverage(hoursBack: 24) { avg in
                current24 = avg
                group.leave()
            }
            
            group.notify(queue: .global()) {
                // Since dictionaries over WCSession cannot easily hold `nil` values in arrays,
                // we map `nil` to a special sentinel value (-999.0) to represent gaps across the bridge.
                let safe7D = array7D.map { $0 ?? -999.0 }
                let safe30D = array30D.map { $0 ?? -999.0 }
                let updatedAt = Date().timeIntervalSince1970
                
                var replyDict: [String: Any] = [
                    "dailyAverages7d": safe7D,
                    "dailyAverages30d": safe30D,
                    "contextUpdatedAt": updatedAt
                ]
                
                if let val = current24 {
                    replyDict["rollingAvg24h"] = val
                }
                
                replyHandler(replyDict)
                
                // Also refresh cached context so non-reachable watch updates can use the same payload.
                do {
                    try session.updateApplicationContext(replyDict)
                    DispatchQueue.main.async {
                        self.lastCompanionContextPublishDate = Date(timeIntervalSince1970: updatedAt)
                    }
                } catch {
                    // Best-effort cache update; interactive reply already succeeded.
                }
                
                // Best-effort complication-priority push for watch-side timeline refresh.
                #if os(iOS)
                if session.isPaired && session.isWatchAppInstalled && session.remainingComplicationUserInfoTransfers > 0 {
                    _ = session.transferCurrentComplicationUserInfo(replyDict)
                }
                #endif
            }
        }
    }
    
    // MARK: - 3. Specific Fetchers
    
    private func publishLongTermComplicationContext() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.activationState != .activated {
            session.activate()
            return
        }
        
        let group = DispatchGroup()
        
        var array7D: [Double?] = []
        var array30D: [Double?] = []
        var current24: Int? = nil
        
        group.enter()
        fetchDailyAverages(daysBack: 7) { averages in
            array7D = averages
            group.leave()
        }
        
        group.enter()
        fetchDailyAverages(daysBack: 30) { averages in
            array30D = averages
            group.leave()
        }
        
        group.enter()
        fetchRollingAverage(hoursBack: 24) { avg in
            current24 = avg
            group.leave()
        }
        
        group.notify(queue: .global(qos: .utility)) {
            let safe7D = array7D.map { $0 ?? -999.0 }
            let safe30D = array30D.map { $0 ?? -999.0 }
            
            var context: [String: Any] = [
                "dailyAverages7d": safe7D,
                "dailyAverages30d": safe30D,
                "contextUpdatedAt": Date().timeIntervalSince1970
            ]
            
            if let val = current24 {
                context["rollingAvg24h"] = val
            }
            
            do {
                try session.updateApplicationContext(context)
                DispatchQueue.main.async {
                    self.lastCompanionContextPublishDate = Date()
                }
            } catch {
                // Context updates are best-effort; do not disrupt the UI fetch flow.
            }
            
            // Best-effort complication-priority push for watch-side timeline refresh.
            #if os(iOS)
            if session.isPaired && session.isWatchAppInstalled && session.remainingComplicationUserInfoTransfers > 0 {
                _ = session.transferCurrentComplicationUserInfo(context)
            }
            #endif
        }
    }
    
    // Free Card: Raw sparkline + most recent reading
    private func fetchRawReadings(hoursBack: Int, completion: @escaping (Int?, [Double?]) -> Void) {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -hoursBack, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        var interval = DateComponents()
        interval.minute = 5 // Bucket the "raw" readings into 5-minute intervals to establish a strict timeline
        
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
                    latestReading = Int(round(valueInMs))
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
                    mostRecentHourAvg = valueInMs
                } else {
                    averages.append(nil)
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
    
    private func fetchRollingAverageUI(hoursBack: Int) {
        fetchRollingAverage(hoursBack: hoursBack) { avg in
            DispatchQueue.main.async {
                self.proCard3Reading = avg
                self.proCard4Reading = avg
            }
        }
    }
}
