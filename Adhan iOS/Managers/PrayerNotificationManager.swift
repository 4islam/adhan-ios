import Foundation
import UserNotifications
import CoreLocation
import AVFoundation

class PrayerNotificationManager: NSObject {
    static let shared = PrayerNotificationManager()
    
    // No fixed interval anymore. Driven by file duration.
    // private let chainInterval: TimeInterval = 29.0 
    
    // Schedule a chain of notifications
    func scheduleAdhanChain(startTime: Date, prayerName: String, adhanType: String = "regular") {
        LogManager.shared.log("PrayerManager: Scheduling chain for \(prayerName) (\(adhanType)) starting at \(startTime.formatted(date: .abbreviated, time: .standard))")
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                LogManager.shared.log("PrayerManager: Aborting chain. Not authorized.")
                return
            }
            
            self.performScheduling(startTime: startTime, prayerName: prayerName, adhanType: adhanType)
        }
    }
    
    private func performScheduling(startTime: Date, prayerName: String, adhanType: String) {
        // User Specs:
        // Regular: 1r.mp3 ... 6r.mp3
        // Fajr: 1f.mp3 ... 10f.mp3
        
        let isFajr = (adhanType == "fajr")
        let chunkCount = isFajr ? 10 : 6
        let fileSuffix = isFajr ? "f" : "r"
        
        var currentOffset: TimeInterval = 0
        
        for i in 1...chunkCount {
            // Filename: "1r.caf" or "10f.caf"
            let fileNameBase = "\(i)\(fileSuffix)"
            let soundName = "\(fileNameBase).caf"
            
            var chunkDuration: TimeInterval = 29.0 // Fallback
            
            // Resolve File and Duration
            let resolution = resolveSoundPath(for: fileNameBase)
            let fileUrl = resolution.absoluteUrl
            let finalSoundName = resolution.relativePath
            
            if let foundUrl = fileUrl {
                // Calculate Duration for Chaining
                chunkDuration = getAudioDuration(url: foundUrl)
                if i == 1 { LogManager.shared.log("PrayerManager: Found \(soundName), using path: \(finalSoundName), duration: \(String(format: "%.2f", chunkDuration))s") }
            } else {
                LogManager.shared.log("PrayerManager: ❌ MISSING FILE: \(soundName) (Path checked: \(finalSoundName))")
            }
            
            // ...
            
            let triggerDate = startTime.addingTimeInterval(currentOffset)
            
            let content = UNMutableNotificationContent()
            content.title = prayerName
            content.body = (i == 1) ? "Time for \(prayerName)" : "Adhan is playing..."
            
            // Critical: soundName must allow iOS to find it.
            content.sound = UNNotificationSound(named: UNNotificationSoundName(finalSoundName))
            
            content.categoryIdentifier = "PRAYER_CHAIN"
            content.threadIdentifier = "prayer_chain_\(prayerName)"
            content.userInfo = [
                "PRAYER_NAME": prayerName
            ]
            
            // Time Sensitive Entitlement Check
            // Ideally this requires "com.apple.developer.usernotifications.time-sensitive" entitlement.
            // On Free Tier, this might be ignored or cause silent delivery if entitlement is missing.
            // User can toggle this in settings.
            let isTimeSensitive = UserDefaults.standard.bool(forKey: "time_sensitive_\(prayerName)")
            if isTimeSensitive {
                if #available(iOS 15.0, *) {
                    content.interruptionLevel = .timeSensitive
                }
            }
            
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
            let requestID = makeNotificationId(prayer: prayerName, chunk: i, date: triggerDate)
            let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    LogManager.shared.log("PrayerManager: Failed to schedule chunk \(i): \(error.localizedDescription)")
                }
            }
            
            // Advance offset by THIS chunk's duration for the NEXT chunk
            currentOffset += chunkDuration
        }
        
        LogManager.shared.log("PrayerManager: Scheduled \(chunkCount) chunks for \(prayerName) on \(startTime.formatted(date: .abbreviated, time: .omitted)). Total duration: \(String(format: "%.1f", currentOffset))s")
    }
    
    private func getAudioDuration(url: URL) -> TimeInterval {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            return duration
        } catch {
            LogManager.shared.log("PrayerManager: Error reading duration for \(url.lastPathComponent): \(error)")
            return 29.0 // Fallback
        }
    }
    
    // Test helper
    func testChainNow() {
        LogManager.shared.log("PrayerManager: Test Button Pressed.")
        let now = Date().addingTimeInterval(5)
        // Test Regular
        scheduleAdhanChain(startTime: now, prayerName: "Test_Dhuhr", adhanType: "regular")
    }

    // MARK: - Background Queue Refill (Stationary Batch)
    
    func refillQueue(location: CLLocation) {
        // ... (No Changes Needed Here) ...
        // Except we call scheduleForDate which calls scheduleAdhanChain
        
        LogManager.shared.log("PrayerManager: Refilling notification queue...")
        
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            
            // 1. Calculate Times for Today and Tomorrow
            let calendar = Calendar.current
            let today = Date()
            
            for dayOffset in 0...1 {
                guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
                self.scheduleForDate(date: targetDate, location: location)
            }
        }
    }
    
    private func scheduleForDate(date: Date, location: CLLocation) {
        // Instantiate Logic (Mirrors DashboardViewModel)
        let pt = PrayerTimes()
        
        // Load Preferences
        let defaults = UserDefaults.standard
        let calcMethod = defaults.integer(forKey: "calcMethod") 
        let asrHanafi = defaults.bool(forKey: "asrForHanafi")
        let highLatMethod = defaults.integer(forKey: "highLatMethod")
        
        if let method = PrayerTimes.CalculationMethod(rawValue: calcMethod) { pt.setCalcMethod(method) }
        pt.setAsrMethod(asrHanafi ? .hanafi : .shafii)
        if let highLat = PrayerTimes.HighLatMethod(rawValue: highLatMethod) { pt.setHighLatsMethod(highLat) }
        
        pt.lat = location.coordinate.latitude
        pt.lng = location.coordinate.longitude
        // Timezone
        pt.timeZone = pt.effectiveTimeZone(
            year: Calendar.current.component(.year, from: date),
            month: Calendar.current.component(.month, from: date),
            day: Calendar.current.component(.day, from: date),
            timeZone: nil
        )
        
        let floatTimes = pt.getPrayerTimes(date: date, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        
        // Map to Names: [Fajr, Sunrise, Dhuhr, Asr, Sunset, Maghrib, Isha]
        let names = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Sunset", "Maghrib", "Isha"]
        let validIndices = [0, 2, 3, 5, 6] // Skip Sunrise/Sunset
        
        let now = Date()
        
        for idx in validIndices {
            guard idx < floatTimes.count, let floatTime = Double(floatTimes[idx]) else { continue }
            
            // Offsets
            var offset: Double = 0
            if idx == 0 { offset = defaults.double(forKey: "fajrOffset") }
            else if idx == 5 { offset = defaults.double(forKey: "maghribOffset") }
            else if idx == 6 { offset = defaults.double(forKey: "ishaOffset") }
            
            let adjustedTime = (floatTime + offset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
            
            // Convert to Date
            let hour = Int(adjustedTime)
            let remainderMinutes = (adjustedTime - Double(hour)) * 60
            let minute = Int(remainderMinutes)
            let second = Int((remainderMinutes - Double(minute)) * 60)
            
            var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
            components.hour = hour
            components.minute = minute
            components.second = second
            
            if let prayerDate = Calendar.current.date(from: components) {
                let name = names[idx]
                
                // Check if notification is enabled for this specific prayer
                let enabledKey = "notification_enabled_\(name)"
                // Default to true if key missing
                let isEnabled = defaults.object(forKey: enabledKey) as? Bool ?? true
                
                if !isEnabled {
                    LogManager.shared.log("PrayerManager: Skipping \(name) - Notification Disabled by user.")
                    continue
                }
                
                // Check if notification is enabled for this specific day of the week
                let daysKey = "notification_days_\(name)"
                let allowedDaysString = defaults.string(forKey: daysKey) ?? "1,2,3,4,5,6,7"
                let allowedDays = allowedDaysString.split(separator: ",").compactMap { Int($0) }
                let weekday = Calendar.current.component(.weekday, from: prayerDate)
                
                if !allowedDays.contains(weekday) {
                    LogManager.shared.log("PrayerManager: Skipping \(name) - Disabled for weekday \(weekday). Allowed: [\(allowedDaysString)]")
                    continue
                }
                
                let prefKey = "adhan_\(name.lowercased())"
                let soundName = defaults.string(forKey: prefKey) ?? "adhan_regular"
                
                if prayerDate > now {
                    if soundName == "adhan_regular" || soundName == "adhan_fajr" {
                        // NEW: Pass explicit 'fajr' or 'regular' type
                        let type = (soundName == "adhan_fajr") ? "fajr" : "regular"
                        scheduleAdhanChain(startTime: prayerDate, prayerName: name, adhanType: type)
                    } else {
                        // Fallback Legacy (Custom User Imported) - No chaining support yet?
                        // Or just play the one file (30s limit)
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
    
    // MARK: - Helpers (Testable)
    
    internal func makeNotificationId(prayer: String, chunk: Int, date: Date) -> String {
        return "\(prayer)_chain_\(chunk)_\(Int(date.timeIntervalSince1970))"
    }
    
    internal func resolveSoundPath(for baseName: String, extension ext: String = "caf") -> (absoluteUrl: URL?, relativePath: String) {
        let rootSoundName = "\(baseName).\(ext)"
        LogManager.shared.log("DebugAudio: Resolving \(rootSoundName)...")
        
        let fileManager = FileManager.default
        var foundUrl: URL? = nil
        let finalRelativePath = rootSoundName // Always use simple name now (Library/Sounds)
        
        // 1. Check Library/Sounds (Priority)
        if let libraryUrl = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first {
            let soundUrl = libraryUrl.appendingPathComponent("Sounds").appendingPathComponent(rootSoundName)
            if fileManager.fileExists(atPath: soundUrl.path) {
                foundUrl = soundUrl
                LogManager.shared.log("DebugAudio: Found in Library/Sounds: \(soundUrl.path)")
                return (foundUrl, finalRelativePath)
            }
        }
        
        // 2. Fallback: Bundle Loopup (if verify fails)
        if let url = Bundle.main.url(forResource: baseName, withExtension: ext) {
             foundUrl = url
             LogManager.shared.log("DebugAudio: Found in Bundle (Fallback): \(url.path)")
        } else if let url = Bundle.main.url(forResource: baseName, withExtension: ext, subdirectory: "AudioSegments") {
             foundUrl = url
             LogManager.shared.log("DebugAudio: Found in Bundle Subdir (Fallback): \(url.path)")
        } else {
             LogManager.shared.log("DebugAudio: ❌ FILE NOT FOUND anywhere for \(rootSoundName)")
        }
        
        return (foundUrl, finalRelativePath)
    }
}
