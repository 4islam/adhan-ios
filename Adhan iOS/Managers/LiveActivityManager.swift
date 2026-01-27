import Foundation
import ActivityKit
import Combine

class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()
    
    @Published var isEnabled: Bool = UserDefaults.standard.bool(forKey: "useLiveActivity") {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "useLiveActivity")
            if !isEnabled {
                endActivity()
            } else {
                // If enabled, we probably want to start it, but we need data. 
                // It will start on next update call.
            }
        }
    }
    
    private var activity: Any? = nil // Type-erased Activity<AdhanActivityAttributes>
    
    private init() {}
    
    func start(nextPrayer: String, time: String, remaining: String, progress: Double, location: String) {
        guard isEnabled else { return }
        guard #available(iOS 16.1, *) else { return }
        
        // If already running, just update
        if activity != nil {
            update(nextPrayer: nextPrayer, time: time, remaining: remaining, progress: progress)
            return
        }
        
        // End any existing stale activities from this app
        Task {
            for a in Activity<AdhanActivityAttributes>.activities {
                await a.end(nil, dismissalPolicy: .immediate)
            }
            
            let attributes = AdhanActivityAttributes(locationName: location)
            let state = AdhanActivityAttributes.ContentState(
                nextPrayerName: nextPrayer,
                nextPrayerTime: time,
                timeRemaining: remaining,
                progress: progress
            )
            
            do {
                let activity = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
                self.activity = activity
                LogManager.shared.log("Live Activity Started: \(activity.id)")
            } catch {
                LogManager.shared.log("Error starting Live Activity: \(error.localizedDescription)")
            }
        }
    }
    
    func update(nextPrayer: String, time: String, remaining: String, progress: Double) {
        guard isEnabled else { return }
        guard #available(iOS 16.1, *) else { return }
        
        guard let activity = self.activity as? Activity<AdhanActivityAttributes> else {
            // Try to recover activity if it was lost from memory but still running?
            // For now, simpler to just start a new one if needed or ignore.
            // If we have data, let's try to start if missing.
            // start(...) // Potential recursion if not careful.
            return 
        }
        
        let state = AdhanActivityAttributes.ContentState(
            nextPrayerName: nextPrayer,
            nextPrayerTime: time,
            timeRemaining: remaining,
            progress: progress
        )
        
        Task {
            await activity.update(using: state)
        }
    }
    
    func endActivity() {
        guard #available(iOS 16.1, *) else { return }
        
        Task {
            for a in Activity<AdhanActivityAttributes>.activities {
                await a.end(nil, dismissalPolicy: .immediate)
            }
            self.activity = nil
            LogManager.shared.log("Live Activity Ended")
        }
    }
}
