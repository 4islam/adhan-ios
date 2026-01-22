import Foundation
import UserNotifications
import Combine

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if granted {
                    self.setupNotificationCategories()
                    LogManager.shared.log("Notifications: Authorization granted")
                } else {
                    let msg = "Notifications: Authorization denied. Error: \(String(describing: error))"
                    LogManager.shared.log(msg)
                }
            }
        }
    }
    
    private func setupNotificationCategories() {
        let playAction = UNNotificationAction(identifier: "PLAY_ADHAN",
                                              title: "Play Adhan",
                                              options: [.foreground])
        
        let category = UNNotificationCategory(identifier: "PRAYER_ALERT",
                                              actions: [playAction],
                                              intentIdentifiers: [],
                                              options: [])
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                var msg = "Notifications: Authorization Status: \(settings.authorizationStatus.rawValue)"
                msg += " | Sound: \(settings.soundSetting.rawValue)"
                msg += " | Alert: \(settings.alertSetting.rawValue)"
                msg += " | Badge: \(settings.badgeSetting.rawValue)"
                LogManager.shared.log(msg)
                
                if settings.authorizationStatus != .authorized {
                    LogManager.shared.log("WARNING: Notifications not fully authorized!")
                }
            }
        }
    }

    func scheduleTestNotification(seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Test Adhan"
        content.body = "Testing background playback"
        
        // Changed to .wav for easier Xcode import
        if Bundle.main.url(forResource: "adhan_short", withExtension: "wav") != nil {
            content.sound = UNNotificationSound(named: UNNotificationSoundName("adhan_short.wav"))
            LogManager.shared.log("Notifications: Found adhan_short.wav, using custom sound.")
        } else {
             content.sound = .default
             LogManager.shared.log("Notifications: adhan_short.wav NOT found in bundle. Using default sound.")
        }
        
        content.categoryIdentifier = "PRAYER_ALERT"
        content.userInfo = [
            "PRAYER_TITLE": "Test Adhan",
            "ADHAN_FILE": "adhan_regular"
        ]
        
        // Use TimeInterval trigger for explicit countdown test
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        
        let request = UNNotificationRequest(identifier: "test_adhan", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                LogManager.shared.log("Notifications: Failed to schedule Test Adhan: \(error.localizedDescription)")
            } else {
                LogManager.shared.log("Notifications: Scheduled Test Adhan in \(seconds) seconds")
            }
        }
    }
    
    func scheduleDefaultSoundTest(seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Test (System Sound)"
        content.body = "If you hear this beep, notifications work."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: "test_default", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
             if let error = error {
                 LogManager.shared.log("Notifications: Failed Default Test: \(error)")
             } else {
                 LogManager.shared.log("Notifications: Scheduled Default Sound Test in \(seconds)s")
             }
        }
    }

    func schedulePrayerNotification(id: String, title: String, body: String, date: Date, soundName: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        // Note: For custom sounds in iOS notifications, the file must be in the app bundle.
        // For now, we use a 30s short clip for the actual alert sound.
        // If "adhan_short.caf" is not found in the bundle, we should fallback to default.
        if Bundle.main.url(forResource: "adhan_short", withExtension: "caf") != nil {
            content.sound = UNNotificationSound(named: UNNotificationSoundName("adhan_short.caf"))
        } else {
             // Fallback to default sound so the user at least hears something
             content.sound = .default
        }
        
        content.categoryIdentifier = "PRAYER_ALERT"
        content.userInfo = [
            "PRAYER_TITLE": title,
            "PRAYER_NAME": title, // Used for lookup of settings (fade/volume)
            "ADHAN_FILE": soundName ?? "adhan_regular"
        ]
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                LogManager.shared.log("Notifications: Failed to schedule \(title): \(error.localizedDescription)")
            } else {
                LogManager.shared.log("Notifications: Scheduled \(title) at \(date.formatted(date: .omitted, time: .standard))")
            }
        }
    }
    
    func logPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                LogManager.shared.log("--- PENDING NOTIFICATIONS AUDIT ---")
                if requests.isEmpty {
                    LogManager.shared.log("No pending notifications found.")
                } else {
                    for req in requests {
                        var triggerInfo = "Unknown time"
                        if let trig = req.trigger as? UNCalendarNotificationTrigger, let date = trig.nextTriggerDate() {
                            triggerInfo = date.formatted(date: .omitted, time: .standard)
                        } else if let trig = req.trigger as? UNTimeIntervalNotificationTrigger, let date = trig.nextTriggerDate() {
                            triggerInfo = date.formatted(date: .omitted, time: .standard)
                        }
                        LogManager.shared.log("ID: \(req.identifier) | Trigger: \(triggerInfo)")
                    }
                }
                LogManager.shared.log("-----------------------------------")
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        LogManager.shared.log("Notifications: willPresent called. App is FOREGROUND.")
        
        // Manual Playback Handoff:
        // System notification sound in foreground can be unreliable or ducked.
        // Since we are in the foreground, we play the audio directly via AudioManager for full control.
        
        let userInfo = notification.request.content.userInfo
        
        // Try to get specific file from payload, otherwise default
        if let adhanFile = userInfo["ADHAN_FILE"] as? String {
             let prayerName = userInfo["PRAYER_NAME"] as? String
             LogManager.shared.log("Notifications: Manual Foreground Playback -> \(adhanFile) for \(prayerName ?? "Unknown")")
             AudioManager.shared.playAdhan(fileName: adhanFile, prayerName: prayerName)
        } else {
             // Fallback if no specific file linked
             LogManager.shared.log("Notifications: Manual Foreground Playback -> adhan_regular")
             AudioManager.shared.playAdhan(fileName: "adhan_regular")
        }
        
        // Show banner, but DO NOT play system sound (to avoid double audio or truncation)
        completionHandler([.banner, .list]) 
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        LogManager.shared.log("Notifications: didReceive called. ActionID: \(response.actionIdentifier)")
        
        if response.actionIdentifier == "PLAY_ADHAN" {
            let userInfo = response.notification.request.content.userInfo
            let adhanFile = userInfo["ADHAN_FILE"] as? String
            let prayerName = userInfo["PRAYER_NAME"] as? String
            LogManager.shared.log("Notifications: Payload: \(userInfo)")
            
            // Tell AudioManager to play the specific audio selected
            AudioManager.shared.playAdhan(fileName: adhanFile, prayerName: prayerName)
        }
        completionHandler()
    }
}
