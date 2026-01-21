import Foundation
import UserNotifications

class PrayerNotificationManager: NSObject {
    static let shared = PrayerNotificationManager()
    
    // Interval between notifications in the chain (must be < 30s)
    private let chainInterval: TimeInterval = 29.0
    
    // Number of chunks generated (we got 11 from the script, likely 10-12 usually)
    private let chunkCount = 8 // Phase 1 goal said 8 chunks
    
    // Schedule a chain of notifications
    func scheduleAdhanChain(startTime: Date, prayerName: String, adhanType: String = "regular") {
        LogManager.shared.log("PrayerManager: Scheduling chain for \(prayerName) starting at \(startTime.formatted(date: .omitted, time: .standard))")
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                LogManager.shared.log("PrayerManager: Aborting chain. Not authorized.")
                return
            }
            
            self.performScheduling(startTime: startTime, prayerName: prayerName, adhanType: adhanType)
        }
    }
    
    private func performScheduling(startTime: Date, prayerName: String, adhanType: String) {
        for i in 1...chunkCount {
            // Filename format: adhan_regular_01.caf
            let chunkIndex = String(format: "%02d", i)
            let soundName = "adhan_\(adhanType)_\(chunkIndex).caf"
            
            // DIAGNOSTIC: Check if file exists in bundle
            if let fileUrl = Bundle.main.url(forResource: "adhan_\(adhanType)_\(chunkIndex)", withExtension: "caf") {
                if i == 1 { 
                    LogManager.shared.log("PrayerManager: ✅ Found file at: \(fileUrl.path)")
                    if fileUrl.path.contains("/Resources/") || fileUrl.path.contains("/AudioSegments/") {
                         LogManager.shared.log("⚠️ WARNING: File appears to be in a subdirectory! Notifications might NOT play it.")
                    }
                }
            } else {
                LogManager.shared.log("PrayerManager: ❌ MISSING FILE: \(soundName) (Check Xcode Target Membership!)")
            }
            
            let offset = TimeInterval(i - 1) * chainInterval
            let triggerDate = startTime.addingTimeInterval(offset)
            
            let content = UNMutableNotificationContent()
            content.title = prayerName
            content.body = (i == 1) ? "Time for \(prayerName)" : "Adhan is playing..."
            content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
            content.categoryIdentifier = "PRAYER_CHAIN"
            content.threadIdentifier = "prayer_chain_\(prayerName)" // Grouping
            content.interruptionLevel = .timeSensitive // Higher priority
            
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
            let requestID = "\(prayerName)_chain_\(i)"
            let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    LogManager.shared.log("PrayerManager: Failed to schedule chunk \(i): \(error.localizedDescription)")
                } else {
                    // Only log the first and last to avoid spamming
                    if i == 1 || i == self.chunkCount {
                        LogManager.shared.log("PrayerManager: Scheduled chunk \(i) at \(triggerDate.formatted(date: .omitted, time: .standard))")
                    }
                }
            }
        }
    }
    
    // Test helper
    func testChainNow() {
        LogManager.shared.log("PrayerManager: Test Button Pressed. Checking auth...")
        // Schedule test chain starting 10 seconds from now
        let now = Date().addingTimeInterval(10)
        scheduleAdhanChain(startTime: now, prayerName: "Test Chain")
    }
}
