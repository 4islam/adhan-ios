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
    }
    
    // MARK: - Background Queue Refill (Stationary Batch)
    
    func refillQueue(location: CLLocation) {
        LogManager.shared.log("PrayerManager: Refilling notification queue...")
        
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                LogManager.shared.log("PrayerManager: Cannot refill. Notifications not authorized.")
                return
            }
            
            // 1. Calculate Times for Today and Tomorrow
            let calendar = Calendar.current
            let today = Date()
            
            // We schedule for Today (remaining) and Tomorrow (full)
            // This ensures ~1.5 - 2 days coverage
            for dayOffset in 0...1 {
                guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
                self.scheduleForDate(date: targetDate, location: location)
            }
        }
    }
    
    private func scheduleForDate(date: Date, location: CLLocation) {
        // Instantiate Logic (Mirrors DashboardViewModel)
        let pt = PrayerTimes()
        
        // Load Preferences (Manual UserDefaults since @AppStorage isn't here)
        let defaults = UserDefaults.standard
        let calcMethod = defaults.integer(forKey: "calcMethod") // Default 0 if missing
        let asrHanafi = defaults.bool(forKey: "asrForHanafi")
        let highLatMethod = defaults.integer(forKey: "highLatMethod")
        
        if let method = PrayerTimes.CalculationMethod(rawValue: calcMethod) {
            pt.setCalcMethod(method)
        }
        pt.setAsrMethod(asrHanafi ? .hanafi : .shafii)
        if let highLat = PrayerTimes.HighLatMethod(rawValue: highLatMethod) {
            pt.setHighLatsMethod(highLat)
        }
        pt.setTimeFormat(.float)
        
        // Set Coords
        pt.lat = location.coordinate.latitude
        pt.lng = location.coordinate.longitude
        // Timezone
        pt.timeZone = pt.effectiveTimeZone(
            year: Calendar.current.component(.year, from: date),
            month: Calendar.current.component(.month, from: date),
            day: Calendar.current.component(.day, from: date),
            timeZone: nil
        )
        
        // Calculate
        let floatTimes = pt.getPrayerTimes(
            date: date,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        
        // Map to Names
        // [Fajr, Sunrise, Dhuhr, Asr, Sunset, Maghrib, Isha]
        // Indices: 0, 1, 2, 3, 4, 5, 6
        let names = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Sunset", "Maghrib", "Isha"]
        let validIndices = [0, 2, 3, 5, 6] // Skip Sunrise/Sunset for Adhan
        
        let now = Date()
        
        for idx in validIndices {
            guard idx < floatTimes.count else { continue }
            let floatTime = Double(floatTimes[idx])
            
            // Offsets
            var offset: Double = 0
            if idx == 0 { offset = defaults.double(forKey: "fajrOffset") }
            else if idx == 5 { offset = defaults.double(forKey: "maghribOffset") }
            else if idx == 6 { offset = defaults.double(forKey: "ishaOffset") }
            
            // Adjust time
            let adjustedTime = (floatTime + offset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
            
            // Convert to Date
            let hour = Int(adjustedTime)
            let minute = Int((adjustedTime - Double(hour)) * 60)
            let second = Int(((adjustedTime * 60) - floor(adjustedTime * 60)) * 60)
            
            var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
            components.hour = hour
            components.minute = minute
            components.second = second
            
            if let prayerDate = Calendar.current.date(from: components) {
                // Determine Audio Preference
                let name = names[idx]
                let prefKey = "adhan_\(name.lowercased())"
                let soundName = defaults.string(forKey: prefKey) ?? "adhan_regular"
                
                // Only schedule if in future
                if prayerDate > now {
                    if soundName == "adhan_regular" || soundName == "adhan_fajr" {
                        let type = (soundName == "adhan_fajr") ? "fajr" : "regular"
                        scheduleAdhanChain(startTime: prayerDate, prayerName: name, adhanType: type)
                    } else {
                        // Fallback Legacy
                        NotificationManager.shared.schedulePrayerNotification(
                            id: "prayer_\(name)",
                            title: "\(name) Prayer",
                            body: "It is time for \(name) prayer.",
                            date: prayerDate,
                            soundName: soundName
                        )
                    }
                }
            }
        }
    }
}
