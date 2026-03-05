import Foundation
import WatchConnectivity
import WidgetKit

/// Receives Pro unlock status sent from the iPhone via WCSession.transferUserInfo.
/// Writes to the App Group UserDefaults so the watch app and complication extension can read it.
class ProStatusReceiver: NSObject, WCSessionDelegate {
    
    static let shared = ProStatusReceiver()
    
    /// Callback when Pro status changes — watch ContentView observes this.
    var onProStatusChanged: ((Bool) -> Void)?
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // No action needed
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let unlocked = userInfo["isProUnlocked"] as? Bool {
            let defaults = UserDefaults(suiteName: "group.com.filamentlabs.HRVSpark")
            defaults?.set(unlocked, forKey: "isProUnlocked")
            
            // Reload complications so they pick up the new Pro status
            WidgetCenter.shared.reloadAllTimelines()
            
            // Notify the watch app UI
            DispatchQueue.main.async {
                self.onProStatusChanged?(unlocked)
            }
        }
    }
}
