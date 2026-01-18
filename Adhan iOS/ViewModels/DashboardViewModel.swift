import Foundation
import SwiftUI
import Combine
import CoreLocation

struct DashboardItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let time: String
    let type: ItemType
    let isNext: Bool
    
    enum ItemType {
        case prayer
        case sunnah
        case event
        case combinedPrayer
    }
}

class DashboardViewModel: ObservableObject {
    @Published var dashboardItems: [DashboardItem] = []
    // Keep these for internal logic or basic legacy if needed, but reducing usage
    @Published var prayerTimes: [String] = [] 
    @Published var prayerNames: [String] = []
    
    @Published var nextPrayerIndex: Int = -1 // Index in the items array now? Or logic index? logic index.
    @Published var nextPrayerName: String = "--"
    @Published var timeRemaining: String = "--:--"
    @Published var currentVerseArabic: String = ""
    @Published var currentVerseEnglish: String = ""
    @Published var currentDateString: String = ""
    @Published var solarNoon: String = "--:--"
    @Published var sunRise: String = "--:--"
    @Published var sunSet: String = "--:--"
    @Published var moonrise: String = "--:--"
    @Published var moonset: String = "--:--"
    @Published var isCombinedDhuhrAsr: Bool = false
    @Published var isCombinedMaghribIsha: Bool = false
    
    // UI Helpers
    @Published var progressToNextPrayer: Double = 0.0
    @Published var hijriDateString: String = ""
    @Published var locationName: String = "Locating..."
    
    // Celestial Positions for Background
    @Published var sunPosition: AstroPosition?
    @Published var moonPosition: AstroPosition?
    
    private var lastCalculatedFloats: [Double] = []
    private var lastCalculationDate: Date?
    private var lastTriggeredPrayer: String? // Track to avoid double Adhan
    
    @Published var isLocationAuthorized: Bool = false
    @Published var isNotificationsAuthorized: Bool = false
    
    private var timer: AnyCancellable?
    
    // User Settings
    @AppStorage("calcMethod") private var startCalcMethod: Int = PrayerTimes.CalculationMethod.ahmadiyya.rawValue
    @AppStorage("asrForHanafi") private var asrForHanafi: Bool = false
    @AppStorage("highLatMethod") private var highLatMethod: Int = PrayerTimes.HighLatMethod.angleBased.rawValue
    @AppStorage("timeFormat") private var timeFormat: Int = PrayerTimes.TimeFormat.time12.rawValue
    
    // Phase 2 Settings
    @AppStorage("tahajjudOffset") private var tahajjudOffset: Double = 60 // minutes before Fajr
    @AppStorage("combineThreshold") private var combineThreshold: Double = 30 // minutes gap
    @AppStorage("tahajjudEnabled") private var tahajjudEnabled: Bool = true
    
    // Offsets
    @AppStorage("fajrOffset") private var fajrOffset: Double = 0
    @AppStorage("maghribOffset") private var maghribOffset: Double = 0
    @AppStorage("ishaOffset") private var ishaOffset: Double = 0
    
    // Per-prayer Adhan Selection
    @AppStorage("adhan_fajr") private var adhanFajrPref: String = "adhan_fajr"
    @AppStorage("adhan_dhuhr") private var adhanDhuhrPref: String = "adhan_regular"
    @AppStorage("adhan_asr") private var adhanAsrPref: String = "adhan_regular"
    @AppStorage("adhan_maghrib") private var adhanMaghribPref: String = "adhan_regular"
    @AppStorage("adhan_isha") private var adhanIshaPref: String = "adhan_regular"
    
    init() {
        startTimer()
        updateBanner()
        checkPermissions()
    }
    
    func checkPermissions() {
        // Location status
        let locStatus = CLLocationManager().authorizationStatus
        self.isLocationAuthorized = (locStatus == .authorizedAlways || locStatus == .authorizedWhenInUse)
        
        // Notification status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isNotificationsAuthorized = (settings.authorizationStatus == .authorized)
            }
        }
    }
    
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    func startTimer() {
        // App refresh every 60 seconds to conserve battery as per USER request
        // However, we'll use a more robust background-safe timer if needed.
        timer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.handleTimerTick()
            }
        
        // Listen for background transitions to manage persistence
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.beginBackgroundPersistence()
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.endBackgroundPersistence()
        }
    }
    
    private func handleTimerTick() {
        updateTime()
        // If we are in background, we might need to extend the task or trigger silent audio
        // but for now, rely on LocationManager's 'Always' state + BACKGROUND audio session.
    }
    
    private func beginBackgroundPersistence() {
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "AdhanPersistence") { [weak self] in
            self?.endBackgroundPersistence()
        }
        print("Background persistence started.")
    }
    
    private func endBackgroundPersistence() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
            print("Background persistence ended.")
        }
    }
    
    func updateBanner() {
        let weekday = Calendar.current.component(.weekday, from: Date())
        // Sunday=1, Friday=6
        
        if weekday == 6 {
            currentVerseArabic = "يَٰٓأَيُّهَا ٱلَّذِينَ ءَامَنُوٓا۟ إِذَا نُودِىَ لِلصَّلَوٰةِ مِن يَوْمِ ٱلْجُمُعَةِ فَٱسْعَوْا۟ إِلَىٰ ذِكْرِ ٱللَّهِ وَذَرُوا۟ ٱلْبَيْعَ ۚ ذَٰلِكُمْ خَيْرٌ لَّكُمْ إِن كُنتُمْ تَعْلَمُونَ"
            currentVerseEnglish = "O ye who believe! when the call is made for Prayer on Friday, hasten to the remembrance of Allah, and leave off all business. That is better for you, if you only knew. 62:10"
        } else {
            currentVerseArabic = "...إِنَّ ٱلصَّلَوٰةَ كَانَتْ عَلَى ٱلْمُؤْمِنِينَ كِتَٰبًا مَّوْقُوتًا"
            currentVerseEnglish = "...verily Prayer is enjoined on the believers to be performed at fixed hours. 4:104"
        }
    }
    
    func updateTime() {
        let date = Date()
        
        // Refresh countdown and celestial positions from cached data every minute (timer tick)
        if !lastCalculatedFloats.isEmpty {
            determineNextPrayer(validFloatTimes: lastCalculatedFloats, date: date)
        }
        
        // Full recalculations (astronomical positions AND prayer times) 
        // are throttled to once per hour to conserve battery, unless it's the very first run.
        let oneHour: TimeInterval = 3600
        if lastCalculationDate == nil || date.timeIntervalSince(lastCalculationDate!) >= oneHour {
            print("Performing throttled 1-hour full calculation...")
            // We need to use the LocationManager directly as the method expects it
            calculatePrayerTimes(location: LocationManager.shared)
        }
    }
    
    func scheduleNotifications() {
        guard isNotificationsAuthorized, !lastCalculatedFloats.isEmpty else { return }
        
        // Clear old ones
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let calendar = Calendar.current
        let today = Date()
        let year = calendar.component(.year, from: today)
        let month = calendar.component(.month, from: today)
        let day = calendar.component(.day, from: today)
        
        // validFloatTimes index mapping matches prayerNames
        // [Fajr, Sunrise, SolarNoon, Dhuhr, Asr, Sunset, Maghrib, Isha, (Tahajjud)]
        for (idx, name) in prayerNames.enumerated() {
            guard idx < lastCalculatedFloats.count else { continue }
            
            // Skip events
            if name == "Sunrise" || name == "Sunset" || name == "Solar Noon" { continue }
            
            let floatTime = lastCalculatedFloats[idx]
            let hour = Int(floatTime)
            let minute = Int((floatTime - Double(hour)) * 60)
            let second = Int(((floatTime * 60) - floor(floatTime * 60)) * 60)
            
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            components.hour = hour
            components.minute = minute
            components.second = second
            
            if let date = calendar.date(from: components), date > today {
                // Determine which Adhan file to use based on user preference
                let adhanFile = getAdhanFile(for: name)
                
                NotificationManager.shared.schedulePrayerNotification(
                    id: "prayer_\(name)",
                    title: "\(name) Prayer",
                    body: "It is time for \(name) prayer.",
                    date: date,
                    soundName: adhanFile // We'll update NotificationManager to accept this
                )
            }
        }
    }
    
    func calculatePrayerTimes(location: LocationManager) {
        guard let loc = location.location else { return }
        
        let date = Date()
        let pt = PrayerTimes()
        
        // Apply Settings
        if let method = PrayerTimes.CalculationMethod(rawValue: startCalcMethod) {
            pt.setCalcMethod(method)
        }
        
        pt.setAsrMethod(asrForHanafi ? .hanafi : .shafii)
        if let highLat = PrayerTimes.HighLatMethod(rawValue: highLatMethod) {
            pt.setHighLatsMethod(highLat)
        }
        
        let originalFormat = PrayerTimes.TimeFormat(rawValue: timeFormat) ?? .time12
        pt.setTimeFormat(.float) // Use float for internal processing
        
        // 1. Solar Noon (Zawal)
        // JS version might not return this explicitly in the array, but it's a midDay calculation.
        // We set coordinates first.
        pt.lat = loc.coordinate.latitude
        pt.lng = loc.coordinate.longitude
        pt.timeZone = pt.effectiveTimeZone(year: Calendar.current.component(.year, from: date), 
                                           month: Calendar.current.component(.month, from: date), 
                                           day: Calendar.current.component(.day, from: date), 
                                           timeZone: nil)
        pt.jDate = pt.julianDate(year: Calendar.current.component(.year, from: date), 
                                month: Calendar.current.component(.month, from: date), 
                                day: Calendar.current.component(.day, from: date)) - pt.lng / (15 * 24)
        
        let zawalFloat = pt.computeMidDay(t: 12.0/24.0) + (pt.timeZone - pt.lng / 15.0)
        self.solarNoon = pt.floatToTimeFormat(zawalFloat, format: originalFormat)
        
        // 2. Dhuhr must be 10 mins after Solar Noon
        pt.setDhuhrMinutes(10.0) // This adds 10 mins to mid-day in adjustTimes
        
        // 3. Main Calculation
        let floatTimes = pt.getPrayerTimes(date: date, latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
        let validFloatTimes = floatTimes.compactMap { Double($0) }
        
        // 4. Tahajjud (minutes before Fajr)
        // We'll calculate this after applying offsets to ensure consistency
        _ = (validFloatTimes[0] - tahajjudOffset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
        
        // 5. Combining Logic
        // validFloatTimes: [Fajr, Sunrise, Dhuhr, Asr, Sunset, Maghrib, Isha]
        var fajrFloat = validFloatTimes[0]
        let dhuhrFloat = validFloatTimes[2]
        let asrFloat = validFloatTimes[3]
        var maghribFloat = validFloatTimes[5]
        var ishaFloat = validFloatTimes[6]
        
        // Apply Manual Offsets (minutes to hours)
        fajrFloat = (fajrFloat + fajrOffset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
        maghribFloat = (maghribFloat + maghribOffset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
        ishaFloat = (ishaFloat + ishaOffset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
        
        // Update validFloatTimes with adjusted values
        var adjustedFloatTimes = validFloatTimes
        adjustedFloatTimes[0] = fajrFloat
        adjustedFloatTimes[5] = maghribFloat
        adjustedFloatTimes[6] = ishaFloat
        
        self.isCombinedDhuhrAsr = (asrFloat - dhuhrFloat) * 60.0 <= combineThreshold
        self.isCombinedMaghribIsha = (ishaFloat - maghribFloat) * 60.0 <= combineThreshold
        
        // 6. Format Strings for individual display
        pt.setTimeFormat(originalFormat)
        self.prayerTimes = pt.adjustTimesFormat(adjustedFloatTimes)
        
        // Expose astronomical times explicitly
        self.sunRise = self.prayerTimes[1]
        self.sunSet = self.prayerTimes[4]
        // Solar Noon is already set via zawalFloat above
        
        // 7. Names and Tahajjud
        var names = ["Fajr", "Sunrise", "Solar Noon", "Dhuhr", "Asr", "Sunset", "Maghrib", "Isha"]
        let weekday = Calendar.current.component(.weekday, from: date)
        if weekday == 6 {
            names[3] = "Jummah (or Dhuhr)"
        }
        
        var finalTimes = self.prayerTimes
        // Insert Solar Noon at index 2
        finalTimes.insert(self.solarNoon, at: 2)
        
        let actualTahajjudFloat = (fajrFloat - tahajjudOffset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
        
        if tahajjudEnabled {
            names.append("Tahajjud")
            finalTimes.append(pt.floatToTimeFormat(actualTahajjudFloat, format: originalFormat))
        }
        
        self.prayerNames = names
        self.prayerTimes = finalTimes
        
        // 8. Build Dashboard Items (Handling Combined & Events)
        var newItems: [DashboardItem] = []
        
        // Raw list order: Fajr, Sunrise, Solar Noon, Dhuhr, Asr, Sunset, Maghrib, Isha, (Tahajjud)
        // Indices:        0     1        2           3      4    5       6        7     8
        
        // We iterate through the parallel arrays and construct items, skipping if combined
        
        var i = 0
        while i < names.count {
            let name = names[i]
            let time = finalTimes[i]
            let isEvent = (name == "Sunrise" || name == "Sunset" || name == "Solar Noon")
            
            // Determine "Next" status (we need to map the logic index `nextPrayerIndex` to this visual item)
            // But `nextPrayerIndex` currently refers to the global float array. 
            // Better to check name match against `nextPrayerName` self-consistency or re-derive.
            // Let's use name matching for now as it's safer with the row reduction.
            let isNext = (name == self.nextPrayerName)
            
            if name == "Dhuhr" || name == "Jummah" {
                if isCombinedDhuhrAsr {
                    // Combine with Asr
                    let pairTitle = "\(name) & Asr"
                    let pairTime = time // Start time is Dhuhr time
                    let isPairNext = (name == self.nextPrayerName || "Asr" == self.nextPrayerName)
                    
                    newItems.append(DashboardItem(title: pairTitle, time: pairTime, type: .combinedPrayer, isNext: isPairNext))
                    i += 2 // Skip Dhuhr and Asr
                    continue
                }
            } else if name == "Maghrib" {
                if isCombinedMaghribIsha {
                    // Combine with Isha
                    let pairTitle = "Maghrib & Isha"
                    let pairTime = time
                    let isPairNext = (name == self.nextPrayerName || "Isha" == self.nextPrayerName)
                    
                    newItems.append(DashboardItem(title: pairTitle, time: pairTime, type: .combinedPrayer, isNext: isPairNext))
                    i += 2 // Skip Maghrib and Isha
                    continue
                }
            }
            
             // Regular Item - ONLY IF NOT AN EVENT
            if !isEvent {
                let itemType: DashboardItem.ItemType = (name == "Tahajjud") ? .sunnah : .prayer
                newItems.append(DashboardItem(title: name, time: time, type: itemType, isNext: isNext))
            }
            i += 1
        }
        
        self.dashboardItems = newItems
        
        // 8. Astrology: Moon times
        updateMoonTimes(loc: loc, date: date)
        
        // 9. Determine Next Prayer using floats
        // Include Tahajjud in the comparison if enabled
        var compareTimes = adjustedFloatTimes
        compareTimes.insert(zawalFloat, at: 2)
        if tahajjudEnabled {
            let tahajjudF = (fajrFloat - tahajjudOffset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
            compareTimes.append(tahajjudF)
        }
        self.lastCalculatedFloats = compareTimes
        self.lastCalculationDate = date
        determineNextPrayer(validFloatTimes: compareTimes, date: date)
        
        // Update Date Strings
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        self.currentDateString = formatter.string(from: date)
        
        // Hijri Date
        let hijriCalendar = Calendar(identifier: .islamicCivil)
        let hijriFormatter = DateFormatter()
        hijriFormatter.calendar = hijriCalendar
        hijriFormatter.dateStyle = .long
        hijriFormatter.timeStyle = .none
        hijriFormatter.locale = Locale(identifier: "en_US") // Ensure English numerals
        self.hijriDateString = hijriFormatter.string(from: date)
        
        // Celestial Positions for Background
        self.sunPosition = Astrology.getSunPosition(date: date, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
        self.moonPosition = Astrology.getMoonPosition(date: date, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
        
        // Update Location Name (Geocoding)
        reverseGeocode(loc)
    }
    
    private func reverseGeocode(_ location: CLLocation) {
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                let city = placemark.locality ?? ""
                let state = placemark.administrativeArea ?? ""
                DispatchQueue.main.async {
                    if !city.isEmpty && !state.isEmpty {
                        self.locationName = "\(city), \(state)"
                    } else {
                        self.locationName = city.isEmpty ? (state.isEmpty ? "Unknown" : state) : city
                    }
                }
            }
        }
    }
    
    // func isEvent(_ name: String) -> Bool ... removed, logic moved to ItemType
    
    func updateMoonTimes(loc: CLLocation, date: Date) {
        if let rise = Astrology.getMoonrise(date: date, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude) {
            self.moonrise = formatTime(rise)
        }
        if let `set` = Astrology.getMoonset(date: date, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude) {
            self.moonset = formatTime(`set`)
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func determineNextPrayer(validFloatTimes: [Double], date: Date) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let currentHour = Double(components.hour!) + Double(components.minute!) / 60.0 + Double(components.second!) / 3600.0
        
        var nextIdx = -1
        let prayerIndices = [0, 3, 4, 6, 7] + (tahajjudEnabled ? [validFloatTimes.count - 1] : [])
        
        for idx in prayerIndices {
            if validFloatTimes[idx] > currentHour {
                nextIdx = idx
                break
            }
        }
        
        if nextIdx != -1 {
            self.nextPrayerIndex = nextIdx
            // Keep nextPrayerName strictly as the *upcoming* prayer for countdown purposes
            self.nextPrayerName = prayerNames[nextIdx]
            
            let diff = validFloatTimes[nextIdx] - currentHour
            self.timeRemaining = formatRemaining(diff)
            
            // --- FOCUS LOGIC (User Request) ---
            // Highlight "Current" prayer until 15 mins before "Next" prayer
            var focusName = self.nextPrayerName
            if diff > (15.0 / 60.0) {
                // We are comfortably in the current prayer window. Highlight Current.
                // Current is index before Next.
                // Find index in prayerIndices
                if let idxInIndices = prayerIndices.firstIndex(of: nextIdx) {
                    let prevIndexInIndices = (idxInIndices - 1 + prayerIndices.count) % prayerIndices.count
                    let prevIdx = prayerIndices[prevIndexInIndices]
                    focusName = prayerNames[prevIdx]
                }
            } else {
                // Less than 15 mins to next prayer, switch focus to Next
                focusName = self.nextPrayerName
            }
            
            // Update DashboardItems 'isNext' state dynamically
            // We must create a new array to trigger publisher if needed, or mutate
            var newItems = self.dashboardItems
            for i in 0..<newItems.count {
                // Clear all
                let title = newItems[i].title
                // Handle combined names e.g. "Dhuhr & Asr"
                _ = title.contains(focusName) // Simple contains might be risky if names overlap, but specific names should be fine.
                             || (focusName == "Jummah (or Dhuhr)" && title.contains("Dhuhr"))
                
                // Precise matching
                let exactMatch = (title == focusName)
                // Combined match: if focus is Dhuhr and item is "Dhuhr & Asr", that's the one.
                // If focus is Asr and item is "Dhuhr & Asr", that's ALSO the one.
                
                var shouldHighlight = exactMatch
                if newItems[i].type == .combinedPrayer {
                    if title.contains(focusName) { shouldHighlight = true }
                    // Special case: if Focus is Jummah, matches Dhuhr
                    if focusName.contains("Jummah") && title.contains("Dhuhr") { shouldHighlight = true }
                }
                
                // Reconstruct item with new isNext
                if newItems[i].isNext != shouldHighlight {
                     newItems[i] = DashboardItem(
                        title: newItems[i].title,
                        time: newItems[i].time,
                        type: newItems[i].type,
                        isNext: shouldHighlight
                    )
                }
            }
            if newItems != self.dashboardItems {
                self.dashboardItems = newItems
            }
            // ----------------------------------
            
            // Calculate Progress
            // Find previous prayer time in the circular list of prayers
            var prevTime: Double = 0
            if let indexInPrayerIndices = prayerIndices.firstIndex(of: nextIdx) {
                if indexInPrayerIndices == 0 {
                    // Previous was the last prayer of yesterday
                    let lastIdx = prayerIndices.last!
                    prevTime = validFloatTimes[lastIdx] - 24.0
                } else {
                    let lastIdx = prayerIndices[indexInPrayerIndices - 1]
                    prevTime = validFloatTimes[lastIdx]
                }
            }
            
            let totalInterval = validFloatTimes[nextIdx] - prevTime
            let elapsed = currentHour - prevTime
            self.progressToNextPrayer = min(max(elapsed / totalInterval, 0.0), 1.0)
            
            // Auto-Play Logic: If elapsed time is small (started in last 65 seconds to catch 1-min poll)
            // and it's not the one we just triggered.
            if elapsed >= 0 && elapsed < (65.0 / 3600.0) {
                let prayerToTrigger = prayerNames[nextIdx] // Trigger aligns with ACTUAL time, not focus
                if lastTriggeredPrayer != prayerToTrigger {
                    // (Logic for trigger remains using nextPrayerName/nextIdx)
                    let items = dashboardItems
                    // Check existence loosely
                    if items.contains(where: { $0.title.contains(prayerToTrigger) }) {
                         let adhanFile = getAdhanFile(for: prayerToTrigger)
                         AudioManager.shared.playAdhan(fileName: adhanFile)
                         lastTriggeredPrayer = prayerToTrigger
                    }
                }
            } else if elapsed > (30.0 / 3600.0) {
                // Reset trigger if we are well past the start (e.g. 30 seconds)
                if lastTriggeredPrayer == prayerNames[nextIdx] {
                    lastTriggeredPrayer = nil
                }
            }
            
        } else {
            // Next is Fajr tomorrow
            self.nextPrayerName = "Fajr (Tomorrow)"
            let diff = (24 - currentHour) + validFloatTimes[0]
            self.timeRemaining = formatRemaining(diff)
            
            // Progress: Between last prayer of today and Fajr tomorrow
            let lastPrayerIdx = prayerIndices.last!
            let lastPrayerTime = validFloatTimes[lastPrayerIdx]
            let nextFajrTime = validFloatTimes[0] + 24.0
            
            let totalInterval = nextFajrTime - lastPrayerTime
            let elapsed = currentHour - lastPrayerTime
            self.progressToNextPrayer = min(max(elapsed / totalInterval, 0.0), 1.0)
        }
    }
    
    func formatRemaining(_ diff: Double) -> String {
        let hourStr = Int(diff)
        let minStr = Int((diff - Double(hourStr)) * 60)
        // Removed seconds to conserve battery/simplify UI
        return String(format: "%02d:%02d", hourStr, minStr)
    }
    
    private func getAdhanFile(for prayerName: String) -> String {
        switch prayerName.lowercased() {
        case "fajr": return adhanFajrPref
        case "dhuhr", "jummah": return adhanDhuhrPref
        case "asr": return adhanAsrPref
        case "maghrib": return adhanMaghribPref
        case "isha": return adhanIshaPref
        default: return "adhan_regular"
        }
    }
    
    func importCustomAdhan(url: URL, for prayer: String) {
        // Start accessing security scoped resource
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            
            // Generate a unique filename to avoid collisions
            let ext = url.pathExtension
            let fileName = "custom_adhan_\(prayer.lowercased())_\(UUID().uuidString).\(ext)"
            let destinationURL = documentsURL.appendingPathComponent(fileName)
            
            // Remove old custom file if it exists (optional, but cleaner)
            // For now, just copy the new one
            try fileManager.copyItem(at: url, to: destinationURL)
            
            // Update Preference
            DispatchQueue.main.async {
                switch prayer.lowercased() {
                case "fajr": self.adhanFajrPref = fileName
                case "dhuhr", "jummah": self.adhanDhuhrPref = fileName
                case "asr": self.adhanAsrPref = fileName
                case "maghrib": self.adhanMaghribPref = fileName
                case "isha": self.adhanIshaPref = fileName
                default: break
                }
                self.scheduleNotifications()
            }
        } catch {
            print("Failed to import custom adhan: \(error)")
        }
    }
}
