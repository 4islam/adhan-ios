import Foundation
import UserNotifications

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
    
    func schedulePrayerNotification(id: String, title: String, body: String, date: Date, soundName: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        // Note: For custom sounds in iOS notifications, the file must be in the app bundle.
        // For now, we use a 30s short clip for the actual alert sound, 
        // and the "PLAY_ADHAN" action will trigger the full audio via AudioManager.
        content.sound = UNNotificationSound(named: UNNotificationSoundName("adhan_short.caf"))
        content.categoryIdentifier = "PRAYER_ALERT"
        content.userInfo = [
            "PRAYER_TITLE": title,
            "ADHAN_FILE": soundName ?? "adhan_regular"
        ]
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == "PLAY_ADHAN" {
            let adhanFile = response.notification.request.content.userInfo["ADHAN_FILE"] as? String
            // Tell AudioManager to play the specific audio selected
            AudioManager.shared.playAdhan(fileName: adhanFile)
        }
        completionHandler()
    }
}
