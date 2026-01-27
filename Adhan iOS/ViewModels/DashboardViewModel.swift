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
    
    @Published var selectedDate: Date = Date()
    
    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    // Celestial Positions for Background
    @Published var sunPosition: AstroPosition?
    @Published var moonPosition: AstroPosition?
    @Published var midnightTime: String = "--:--"
    
    var lastCalculatedFloats: [Double] = []
    private var lastCalculationDate: Date?
    private var lastTriggeredPrayer: String? // Track to avoid double Adhan
    private var lastGeocodedLocation: CLLocation? // Optimization: Avoid re-geocoding on same loc
    

    
    @Published var isLocationAuthorized: Bool = false
    @Published var isNotificationsAuthorized: Bool = false
    @Published var isLoading: Bool = true
    @Published var isCalculating: Bool = false
    @Published var loadingStatus: String = "Starting..."
    
    // Time Anchoring
    enum TimeAnchor {
        case none
        case sunrise
        case solarNoon
        case sunset
    }
    @Published var timeAnchor: TimeAnchor = .none
    
    private var timer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    // User Settings
    @AppStorage("calcMethod") private var startCalcMethod: Int = PrayerTimes.CalculationMethod.ahmadiyya.rawValue
    @AppStorage("asrForHanafi") private var asrForHanafi: Bool = false
    @AppStorage("highLatMethod") private var highLatMethod: Int = PrayerTimes.HighLatMethod.angleBased.rawValue
    @AppStorage("timeFormat") private var timeFormat: Int = PrayerTimes.TimeFormat.time12.rawValue
    
    // Phase 2 Settings
    @AppStorage("tahajjudOffset") private var tahajjudOffset: Double = 60 // minutes before Fajr
    @AppStorage("combineThreshold") private var combineThreshold: Double = 70 // minutes gap
    @AppStorage("asrMaghribGapThreshold") private var asrMaghribGapThreshold: Double = 90
    @AppStorage("tahajjudEnabled") private var tahajjudEnabled: Bool = true
    
    // Offsets
    @AppStorage("fajrOffset") private var fajrOffset: Double = 0
    @AppStorage("maghribOffset") private var maghribOffset: Double = 0
    @AppStorage("ishaOffset") private var ishaOffset: Double = 0
    
    // Per-prayer Adhan Selection
    @AppStorage("adhan_fajr") private var adhanFajrPref: String = "adhan_fajr"
    @AppStorage("adhan_dhuhr") private var adhanDhuhrPref: String = "adhan_regular"
    @AppStorage("adhan_asr") private var adhanAsrPref: String = "adhan_regular"
    @AppStorage("combineShortNightEnabled") private var combineShortNightEnabled: Bool = true
    @AppStorage("shortNightDuration") private var shortNightDuration: Double = 9.0
    @AppStorage("adhan_maghrib") private var adhanMaghribPref: String = "adhan_regular"
    @AppStorage("adhan_isha") private var adhanIshaPref: String = "adhan_regular"
    @AppStorage("adhan_tahajjud") private var adhanTahajjudPref: String = "silent_vibrate"
    
    init() {
        startTimer()
        updateVerse()
        checkPermissions()
        startLocationTimeout()
    }
    
    // Cached Formatters to improve performance
    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full 
        f.timeStyle = .none
        return f
    }()
    
    static let hijriFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .islamicCivil)
        f.dateStyle = .long
        f.timeStyle = .none
        f.locale = Locale(identifier: "en_US")
        return f
    }()
    
    func checkPermissions() {
        // Location status
        let locStatus = CLLocationManager().authorizationStatus
        self.isLocationAuthorized = (locStatus == .authorizedAlways || locStatus == .authorizedWhenInUse)
        
        // Notification status
        // Initial check
        UNUserNotificationCenter.current().getNotificationSettings { settings in
             DispatchQueue.main.async {
                 self.isNotificationsAuthorized = (settings.authorizationStatus == .authorized)
                 LogManager.shared.log("Dashboard: CheckPermissions -> Auth Status: \(settings.authorizationStatus.rawValue)")
             }
        }
        
        // Subscribe to Manager updates
        NotificationManager.shared.$isAuthorized
            .receive(on: RunLoop.main)
            .sink { [weak self] authorized in
                self?.isNotificationsAuthorized = authorized
                if authorized {
                    LogManager.shared.log("Dashboard: Authorization confirmed. Re-attempting schedule.")
                    self?.scheduleNotifications()
                }
            }
            .store(in: &cancellables)
    }
    
    private func startLocationTimeout() {
        // Fallback if location takes too long (e.g. older devices)
        DispatchQueue.main.asyncAfter(deadline: .now() + 12.0) { [weak self] in
            guard let self = self else { return }
            if self.isLoading && (self.locationName == "Locating..." || self.lastCalculatedFloats.isEmpty) {
                print("DashboardViewModel: Location timed out. Using Default (Mecca).")
                self.loadingStatus = "Location Timeout. Using Default."
                
                // Construct a default location (Mecca)
                let defaultLoc = CLLocation(latitude: 21.4225, longitude: 39.8262)
                LocationManager.shared.setManualLocation(defaultLoc)
                
                // Force calculation immediately to bypass debounce and clear loading state
                self.calculatePrayerTimes(location: LocationManager.shared)
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
        
        // Listen for Location Changes (Significant)
        LocationManager.shared.$location
            .compactMap { $0 } // Filter nils
            .sink { [weak self] _ in
                print("DashboardViewModel: Location updated! Recalculating schedule...")
                self?.lastCalculationDate = nil // Force recalculation bypass logic
                // If we are viewing a different day, we still want to recalculate for that day based on new location
                self?.calculatePrayerTimes(location: LocationManager.shared)
                self?.scheduleNotifications()
            }
            .store(in: &cancellables)
    }
    
    private func handleTimerTick() {
        updateTime()
        updateVerse()
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
    
    func updateVerse(date: Date = Date()) {
        let calendar = Calendar.current
        let now = date
        let weekday = calendar.component(.weekday, from: now) // Sunday=1, Friday=6
        
        var showFridayVerse = false
        
        if weekday == 6 {
            // lastCalculatedFloats: [Fajr, Sunrise, SolarNoon, Dhuhr, Asr, Sunset, Maghrib, Isha, (Tahajjud)]
            // User Request: Display verse until Asr time
            if lastCalculatedFloats.count > 4 {
                let asrFloat = lastCalculatedFloats[4]
                
                let components = calendar.dateComponents([.hour, .minute, .second], from: now)
                let currentHour = Double(components.hour!) + Double(components.minute!) / 60.0 + Double(components.second!) / 3600.0
                
                // If current time is BEFORE Asr
                if currentHour < asrFloat {
                    showFridayVerse = true
                }
            } else {
                // Determine sensible default if no calc yet? 
                // Getting floats is fast, so this is likely a brief fringe case.
                // We'll show standard to be safe, or Friday if we trust we are early in day.
                // Let's assume standard until calc is ready to avoid flashing wrong state at Maghrib time.
                showFridayVerse = false 
            }
        }
        
        if showFridayVerse {
            currentVerseArabic = "يَٰٓأَيُّهَا ٱلَّذِينَ ءَامَنُوٓا۟ إِذَا نُودِىَ لِلصَّلَوٰةِ مِن يَوْمِ ٱلْجُمُعَةِ فَٱسْعَوْا۟ إِلَىٰ ذِكْرِ ٱللَّهِ وَذَرُوا۟ ٱلْبَيْعَ ۚ ذَٰلِكُمْ خَيْرٌ لَّكُمْ إِن كُنتُمْ تَعْلَمُونَ"
            currentVerseEnglish = "O ye who believe! when the call is made for Prayer on Friday, hasten to the remembrance of Allah, and leave off _all_business. That is better for you, if you only knew. 62:10"
        } else {
            currentVerseArabic = "...إِنَّ ٱلصَّلَوٰةَ كَانَتْ عَلَى ٱلْمُؤْمِنِينَ كِتَٰبًا مَّوْقُوتًا"
            currentVerseEnglish = "...verily Prayer is enjoined on the believers to be performed at fixed hours. 4:104"
        }
    }
    
    func refreshSettings() {
        print("DashboardViewModel: Settings changed. Forcing recalculation...")
        self.lastCalculationDate = nil // Bypass throttle
        updateTime()
    }
    
    func updateTime() {
        // This is called every minute by the timer
        let now = Date()
        
        // If we represent "Today", we want to update the countdowns dynamically
        if isToday {
            if !lastCalculatedFloats.isEmpty {
                determineNextPrayer(validFloatTimes: lastCalculatedFloats, date: now)
            }
        }
        
        // Periodic full refresh rule:
        // If it's been > 1 hour since last full calc, RE-RUN calc for the SELECTED DATE.
        // This ensures astronomical positions (sun/moon) update even if viewing another day, 
        // OR if viewing today, ensures times stay fresh.
        let oneHour: TimeInterval = 3600
        if lastCalculationDate == nil || now.timeIntervalSince(lastCalculationDate!) >= oneHour {
            print("Performing throttled 1-hour full calculation...")
            calculatePrayerTimes(location: LocationManager.shared)
            
            // Only schedule notifications based on REAL TIME (today/future), 
            // no matter what day we are viewing.
            scheduleNotifications()
        }
    }
    
    // MARK: - Date Navigation
    
    func goToNextDay() {
        if let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
            selectedDate = next
            updateForSelectedDate()
        }
    }
    
    func goToPreviousDay() {
        if let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
            selectedDate = prev
            updateForSelectedDate()
        }
    }
    
    func jumpToDate(_ date: Date) {
        selectedDate = date
        updateForSelectedDate()
    }
    
    private func updateForSelectedDate() {
        // Reset state that might look confusing during switch
        self.loadingStatus = "Loading..."
        self.isCalculating = true
        // Force calculation immediately
        calculatePrayerTimes(location: LocationManager.shared)
    }
    
    func setTimeAnchor(_ anchor: TimeAnchor) {
        self.timeAnchor = anchor
        if anchor != .none {
            // Trigger update to apply anchor immediately to current date
            updateForSelectedDate()
        }
    }
    
    func setTime(hour: Double) {
        // When user manually scrubs time, we disable the anchor
        if self.timeAnchor != .none {
            self.timeAnchor = .none
        }
        
        let intHour = Int(hour)
        let minute = Int((hour - Double(intHour)) * 60)
        
        if let newDate = Calendar.current.date(bySettingHour: intHour, minute: minute, second: 0, of: self.selectedDate) {
            self.selectedDate = newDate
            // Update positions immediately (no need for full recalc of prayer times if date didn't change day)
            // But checking if day changed is complex. Assuming slider is 0-24 for THIS day.
            if let loc = LocationManager.shared.location {
                self.sunPosition = Astrology.getSunPosition(date: newDate, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
                self.moonPosition = Astrology.getMoonPosition(date: newDate, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
            }
        }
    }
    
    func resetTime() {
        let now = Date()
        let calendar = Calendar.current
        
        if isToday {
            // simpler return to actual now
            self.selectedDate = now
        } else {
            // Keep the selected DAY, but apply current TIME (hr/min/sec)
            let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: now)
            // Use date method to preserve year/month/day of selectedDate
            if let newDate = calendar.date(bySettingHour: timeComponents.hour ?? 12,
                                           minute: timeComponents.minute ?? 0,
                                           second: timeComponents.second ?? 0,
                                           of: self.selectedDate) {
                self.selectedDate = newDate
            }
        }
        
        // Clear anchor
        if self.timeAnchor != .none {
            self.timeAnchor = .none
        }
        
        // Update Astro Positions Immediately
        if let loc = LocationManager.shared.location {
            self.sunPosition = Astrology.getSunPosition(date: self.selectedDate, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
            self.moonPosition = Astrology.getMoonPosition(date: self.selectedDate, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
        }
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    func scheduleNotifications() {
        LogManager.shared.log("Dashboard: scheduleNotifications() called. Auth=\(isNotificationsAuthorized)")
        
        guard isNotificationsAuthorized else {
            LogManager.shared.log("Dashboard: Aborting schedule. Auth missing.")
            return
        }
        
        // Clear all pending before rebuilding
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        LogManager.shared.log("Dashboard: Cleared pending notifications.")
        
        guard let loc = LocationManager.shared.location else {
            LogManager.shared.log("Dashboard: Location missing, cannot calculate times for scheduling.")
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Scheduling Metrics
        var scheduledCount = 0
        let MAX_NOTIFICATIONS = 60 // iOS Limit is 64. Keeping buffer.
        var dayOffset = 0
        
        LogManager.shared.log("Dashboard: Starting scheduling loop (Max: \(MAX_NOTIFICATIONS))...")
        
        // Loop until we hit the notification limit
        schedulingLoop: while scheduledCount < MAX_NOTIFICATIONS {
            // Safety: Stop if we look too far ahead (e.g. 1 month) to prevent infinite loops
            if dayOffset > 30 { break }
            
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else {
                dayOffset += 1
                continue
            }
            
            // --- Calculation Logic ---
            let pt = PrayerTimes()
            if let method = PrayerTimes.CalculationMethod(rawValue: startCalcMethod) { pt.setCalcMethod(method) }
            pt.setAsrMethod(asrForHanafi ? .hanafi : .shafii)
            if let highLat = PrayerTimes.HighLatMethod(rawValue: highLatMethod) { pt.setHighLatsMethod(highLat) }
            pt.setTimeFormat(.float) // Critical: Ensure we get Double-compatible strings or raw floats if method supports it
            
            pt.lat = loc.coordinate.latitude
            pt.lng = loc.coordinate.longitude
            pt.timeZone = pt.effectiveTimeZone(
                year: calendar.component(.year, from: targetDate),
                month: calendar.component(.month, from: targetDate),
                day: calendar.component(.day, from: targetDate),
                timeZone: nil
            )
            pt.jDate = pt.julianDate(
                year: calendar.component(.year, from: targetDate),
                month: calendar.component(.month, from: targetDate),
                day: calendar.component(.day, from: targetDate)
            ) - pt.lng / (15 * 24)
            
            pt.computeMidDay(t: 12.0/24.0)
            pt.setDhuhrMinutes(10.0)
            
            // Raw Floats: [Fajr, Sunrise, Dhuhr, Asr, Sunset, Maghrib, Isha]
            var validFloats = pt.getPrayerTimesDoubles(date: targetDate, latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
            
            // Safety Check: Ensure we have enough data (Expect: Fajr, Sunrise, Dhuhr, Asr, Sunset, Maghrib, Isha = 7)
            if validFloats.count < 7 {
                LogManager.shared.log("Dashboard: Warning! Insufficient prayer times calculated for dayOffset \(dayOffset). Count: \(validFloats.count). Skipping.")
                dayOffset += 1
                continue
            }
            
            // Apply Offsets
            // Indices: 0=Fajr, 5=Maghrib, 6=Isha
            validFloats[0] = (validFloats[0] + fajrOffset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
            validFloats[5] = (validFloats[5] + maghribOffset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
            validFloats[6] = (validFloats[6] + ishaOffset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
            
            let basicNames = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Sunset", "Maghrib", "Isha"]
            
            // Tahajjud
            var tahajjudTime: Double? = nil
            if tahajjudEnabled {
                tahajjudTime = (validFloats[0] - tahajjudOffset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
            }
            
            // Process Basic Prayers
            for (idx, name) in basicNames.enumerated() {
                if name == "Sunrise" || name == "Sunset" { continue }
                
                let floatTime = validFloats[idx]
                
                // Determine Cost & Check Limit
                let adhanFile = getAdhanFile(for: name)
                var cost = 1
                if adhanFile == "adhan_fajr" { cost = 10 }
                else if adhanFile == "adhan_regular" { cost = 6 }
                
                // Check if we have space
                if scheduledCount + cost > MAX_NOTIFICATIONS {
                    LogManager.shared.log("Dashboard: limit reached (\(scheduledCount)). Stopping.")
                    break schedulingLoop
                }
                
                // Try Schedule
                if scheduleSinglePrayer(name: name, floatTime: floatTime, baseDate: targetDate, calendar: calendar, checkDate: now) {
                     scheduledCount += cost
                }
            }
            
            // Process Tahajjud
            if let tTime = tahajjudTime {
                 let tName = "Tahajjud"
                 let adhanFile = getAdhanFile(for: tName)
                 var cost = 1
                 if adhanFile == "adhan_fajr" { cost = 10 } // Unlikely for Tahajjud but possible
                 else if adhanFile == "adhan_regular" { cost = 6 }
                 
                 if scheduledCount + cost <= MAX_NOTIFICATIONS {
                      if scheduleSinglePrayer(name: tName, floatTime: tTime, baseDate: targetDate, calendar: calendar, checkDate: now) {
                          scheduledCount += cost
                      }
                 } else {
                      LogManager.shared.log("Dashboard: limit reached at Tahajjud. Stopping.")
                      break schedulingLoop
                 }
            }
            
            // Move to next day
            dayOffset += 1
        }
        
        LogManager.shared.log("Dashboard: Scheduling complete. Total slots used: ~\(scheduledCount)")
    }
    
    // Returns true if actually scheduled
    private func scheduleSinglePrayer(name: String, floatTime: Double, baseDate: Date, calendar: Calendar, checkDate: Date) -> Bool {
        let hour = Int(floatTime)
        let minute = Int((floatTime - Double(hour)) * 60)
        let second = Int(((floatTime * 60) - floor(floatTime * 60)) * 60)
        
        var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = hour
        components.minute = minute
        components.second = second
        
        if let prayerDate = calendar.date(from: components) {
            if prayerDate > checkDate {
                LogManager.shared.log("Dashboard: Scheduling \(name) at \(prayerDate.formatted(date: .abbreviated, time: .standard))")
                
                let adhanFile = getAdhanFile(for: name)
                
                if adhanFile == "adhan_regular" || adhanFile == "adhan_fajr" {
                    let type = (adhanFile == "adhan_fajr") ? "fajr" : "regular"
                    PrayerNotificationManager.shared.scheduleAdhanChain(startTime: prayerDate, prayerName: name, adhanType: type)
                } else {
                    NotificationManager.shared.schedulePrayerNotification(
                        id: "prayer_\(name)_\(prayerDate.timeIntervalSince1970)",
                        title: "\(name) Prayer",
                        body: "It is time for \(name) prayer.",
                        date: prayerDate,
                        soundName: adhanFile
                    )
                }
                return true
            }
        }
        return false
    }
    

    func calculatePrayerTimes(location: LocationManager) {
        guard let loc = location.location else {
            // Still waiting for location
            self.loadingStatus = "Locating..."
            self.isCalculating = false
            return
        }
        
        self.loadingStatus = "Calculating Schedule..."
        // Don't set isCalculating = true here blindly if we are already in async, 
        // but it's safe to ensure it.
        // If called from updateForSelectedDate, it's already true.
        
        let date = selectedDate // Use selectedDate for calculation
        
        // Capture all necessary values for background thread
        let startCalcMethod = self.startCalcMethod
        let asrForHanafi = self.asrForHanafi
        let highLatMethod = self.highLatMethod
        let timeFormat = self.timeFormat
        let tahajjudOffset = self.tahajjudOffset
        let fajrOffset = self.fajrOffset
        let maghribOffset = self.maghribOffset
        let ishaOffset = self.ishaOffset
        let combineShortNightEnabled = self.combineShortNightEnabled
        let shortNightDuration = self.shortNightDuration
        let combineThreshold = self.combineThreshold
        let asrMaghribGapThreshold = self.asrMaghribGapThreshold
        let isCombinedDhuhrAsr = self.isCombinedDhuhrAsr
        let isCombinedMaghribIsha = self.isCombinedMaghribIsha
        let tahajjudEnabled = self.tahajjudEnabled
        let nextPrayerName = self.nextPrayerName // For sticky selection or re-calc
        let dashboardItems = self.dashboardItems
        let isToday = self.isToday
        
        // Move to Background
        DispatchQueue.global(qos: .userInitiated).async {
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
            let solarNoonStr = pt.floatToTimeFormat(zawalFloat, format: originalFormat)
            
            // 2. Dhuhr must be 10 mins after Solar Noon
            pt.setDhuhrMinutes(10.0) // This adds 10 mins to mid-day in adjustTimes
            
            // 3. Main Calculation
            let floatTimes = pt.getPrayerTimes(date: date, latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
            let validFloatTimes = floatTimes.compactMap { Double($0) }
            
            // 4. Tahajjud (minutes before Fajr)
            _ = (validFloatTimes[0] - tahajjudOffset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
            
            // 5. Combining Logic
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
            
            var isShortNight = false
            if combineShortNightEnabled {
                 let nightDuration = (24.0 - ishaFloat) + fajrFloat 
                 if nightDuration < shortNightDuration {
                     isShortNight = true
                 }
            }
            
            let asrMaghribGap = (maghribFloat - asrFloat) * 60.0
            let newIsCombinedDhuhrAsr = ((asrFloat - dhuhrFloat) * 60.0 <= combineThreshold) || (asrMaghribGap <= asrMaghribGapThreshold)
            let newIsCombinedMaghribIsha = isShortNight || ((ishaFloat - maghribFloat) * 60.0 <= combineThreshold)
            
            // 6. Format Strings for individual display
            pt.setTimeFormat(originalFormat)
            let finalPrayerTimes = pt.adjustTimesFormat(adjustedFloatTimes)
            
            // Expose astronomical times explicitly
            let sunRiseStr = finalPrayerTimes[1]
            let sunSetStr = finalPrayerTimes[4]
            // Solar Noon is already set via zawalFloat above
            
            // 7. Names and Tahajjud
            var names = ["Fajr", "Sunrise", "Solar Noon", "Dhuhr", "Asr", "Sunset", "Maghrib", "Isha"]
            let weekday = Calendar.current.component(.weekday, from: date)
            if weekday == 6 {
                names[3] = "Jummah (or Dhuhr)"
            }
            
            var finalTimesWithNoon = finalPrayerTimes
            finalTimesWithNoon.insert(solarNoonStr, at: 2)
            
            let actualTahajjudFloat = (fajrFloat - tahajjudOffset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
            
            // Calculate Midnight
            let fNext = adjustedFloatTimes[0] + 24.0
            let sSet = adjustedFloatTimes[4] // Maghrib/Sunset
            let midFloat = (sSet + fNext) / 2.0
            let midnightStr = pt.floatToTimeFormat(midFloat.truncatingRemainder(dividingBy: 24.0), format: originalFormat)

            if tahajjudEnabled {
                names.append("Tahajjud")
                finalTimesWithNoon.append(pt.floatToTimeFormat(actualTahajjudFloat, format: originalFormat))
            }
            
            // 8. Build Dashboard Items (Handling Combined & Events)
            var newItems: [DashboardItem] = []
            
            var i = 0
            while i < names.count {
                let name = names[i]
                let time = finalTimesWithNoon[i]
                let isEvent = (name == "Sunrise" || name == "Sunset" || name == "Solar Noon")
                
                let isNext = (name == nextPrayerName) // Simplified check
                
                if name == "Dhuhr" || name == "Jummah" {
                    if newIsCombinedDhuhrAsr {
                        let pairTitle = "\(name) & Asr"
                        let pairTime = time
                        let isPairNext = (name == nextPrayerName || "Asr" == nextPrayerName)
                        newItems.append(DashboardItem(title: pairTitle, time: pairTime, type: .combinedPrayer, isNext: isPairNext))
                        i += 2 
                        continue
                    }
                } else if name == "Maghrib" {
                    if newIsCombinedMaghribIsha {
                        let pairTitle = "Maghrib & Isha"
                        let pairTime = time
                        let isPairNext = (name == nextPrayerName || "Isha" == nextPrayerName)
                        newItems.append(DashboardItem(title: pairTitle, time: pairTime, type: .combinedPrayer, isNext: isPairNext))
                        i += 2 
                        continue
                    }
                }
                
                if !isEvent {
                    let itemType: DashboardItem.ItemType = (name == "Tahajjud") ? .sunnah : .prayer
                    newItems.append(DashboardItem(title: name, time: time, type: itemType, isNext: isNext))
                }
                i += 1
            }
            
            // 8. Astrology: Moon times
            // MOVED to secondary step to speed up primary UI render
            var moonRiseStr = "--:--"
            var moonSetStr = "--:--"
            // Placeholders for now

            
            // Celestial Positions for Background
            let sunPos = Astrology.getSunPosition(date: date, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
            let moonPos = Astrology.getMoonPosition(date: date, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
            
            // Update Date Strings
            // Use cached static formatters - thread safe since DateFormatter in Swift/Foundation on iOS 7+ is generally thread safe for reading, 
            // but `string(from:)` is mutating on older OS? Actually DateFormatter IS thread safe on modern iOS.
            // But to be absolutely safe across threads if we were sharing instances across parallel writes...
            // Actually, DateFormatter is NOT thread safe on Apple platforms if mutated. 
            // But `string(from:)` doesn't mutate.
            // However, modifying properties is unsafe.
            // Since we configured them once in init closure and they are let, we are safe READ-ONLY.
            
            let curDateStr = DashboardViewModel.dateFormatter.string(from: date)
            let hijriStr = DashboardViewModel.hijriFormatter.string(from: date)
            
            // Geocoding (needs to be sync or handled) - reverseGeocode is inherently async, 
            // but we can trigger it on main later or just let it update eventually.
            
            // Update Main Thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.solarNoon = solarNoonStr
                self.sunRise = sunRiseStr
                self.sunSet = sunSetStr
                self.midnightTime = midnightStr
                
                self.isCombinedDhuhrAsr = newIsCombinedDhuhrAsr
                self.isCombinedMaghribIsha = newIsCombinedMaghribIsha
                
                self.prayerNames = names
                self.prayerTimes = finalTimesWithNoon
                self.dashboardItems = newItems
                
                self.moonrise = moonRiseStr
                self.moonset = moonSetStr
                self.sunPosition = sunPos
                self.moonPosition = moonPos
                
                self.currentDateString = curDateStr
                self.hijriDateString = hijriStr
                
                // 9. Determine Next Prayer using floats
                var compareTimes = adjustedFloatTimes
                compareTimes.insert(zawalFloat, at: 2)
                if tahajjudEnabled {
                    let tahajjudF = (fajrFloat - tahajjudOffset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
                    compareTimes.append(tahajjudF)
                }
                self.lastCalculatedFloats = compareTimes
                self.lastCalculationDate = Date()
                
                // --- Time Anchoring Logic ---
                // If an anchor is set, adjust the selectedDate's time to match the anchor for THIS day
                if self.timeAnchor != .none {
                    var targetTime: Double? = nil
                    switch self.timeAnchor {
                    case .sunrise: targetTime = validFloatTimes[1] // Sunrise
                    case .solarNoon: targetTime = zawalFloat // Solar Noon
                    case .sunset: targetTime = validFloatTimes[4] // Sunset
                    default: break
                    }
                    
                    if let t = targetTime {
                        // Update selectedDate to this time
                        let hour = Int(t)
                        let minute = Int((t - Double(hour)) * 60)
                        let second = Int(((t * 60) - floor(t * 60)) * 60)
                        
                        // We use the Calendar to safeguard date components
                        if let newDate = Calendar.current.date(bySettingHour: hour, minute: minute, second: second, of: self.selectedDate) {
                            self.selectedDate = newDate
                            
                            // Since date changed (time-wise), we should technically re-calc positions
                            // because positions above were calculated with the 'start of day' or old time?
                            // 'calculatePrayerTimes' used 'selectedDate' at start. 
                            // If `selectedDate` had old time, Astro positions above are for OLD time.
                            // We need to update them for NEW time.
                            // Optimization: Just re-run lightweight astro calc here.
                            
                            self.sunPosition = Astrology.getSunPosition(date: newDate, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
                            self.moonPosition = Astrology.getMoonPosition(date: newDate, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
                        }
                    }
                }
                
                if isToday {
                    self.determineNextPrayer(validFloatTimes: compareTimes, date: Date())
                } else {
                    self.nextPrayerIndex = -1
                    self.nextPrayerName = ""
                    self.timeRemaining = ""
                    self.progressToNextPrayer = 0.0
                }
                
                self.reverseGeocode(loc)
                
                // Shared Data (Background)
                DispatchQueue.global(qos: .background).async {
                    SharedDataManager.shared.savePrayerData(
                        times: self.prayerTimes,
                        names: self.prayerNames,
                        nextIndex: self.nextPrayerIndex,
                        location: self.locationName,
                        hijri: self.hijriDateString
                    )
                }
                
                self.isCalculating = false
                
                if self.isLoading {
                    DispatchQueue.main.async {
                        if !self.isCalculating {
                            withAnimation { self.isLoading = false }
                        }
                    }
                }
                
                // 10. Secondary: Moon Times (Calculated afterwards to prioritize fast UI)
                DispatchQueue.global(qos: .userInitiated).async {
                    var mRise = "--:--"
                    var mSet = "--:--"
                    if let rise = Astrology.getMoonrise(date: date, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude) {
                        mRise = self.formatTime(rise)
                    }
                    if let set = Astrology.getMoonset(date: date, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude) {
                        mSet = self.formatTime(set)
                    }
                    
                    DispatchQueue.main.async {
                        self.moonrise = mRise
                        self.moonset = mSet
                    }
                }
            }
        }
    }

    
    private func reverseGeocode(_ location: CLLocation) {
        // Optimization: Don't re-geocode if close to last location (e.g. 1km)
        if let last = lastGeocodedLocation, last.distance(from: location) < 1000 {
            return
        }
        self.lastGeocodedLocation = location
        
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
        return DashboardViewModel.timeFormatter.string(from: date)
    }
    


    func determineNextPrayer(validFloatTimes: [Double], date: Date) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let currentHour = Double(components.hour!) + Double(components.minute!) / 60.0 + Double(components.second!) / 3600.0
        
        // ... (Find Next Logic) ...
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
            self.nextPrayerName = prayerNames[nextIdx]
            let diff = validFloatTimes[nextIdx] - currentHour
            self.timeRemaining = formatRemaining(diff)
            
            // --- CUSTOM FOCUS LOGIC (User Request) ---
            var focusName = self.nextPrayerName // Default to Next if no rule matches
            
            // Times
            // Times
            // let fajr = validFloatTimes[0] -> Unused
            // let sunrise = validFloatTimes[1] -> Unused
            // let dhuhr = validFloatTimes[2] -> Unused 
            // Indices: 0=Fajr, 1=Sunrise, 2=SolarNoon, 3=Dhuhr, 4=Asr, 5=Sunset, 6=Maghrib, 7=Isha, 8=Tahajjud?
            // "validFloatTimes" passed here is `compareTimes` which has:
            // [Fajr, Sunrise, SolarNoon, Dhuhr, Asr, Sunset, Maghrib, Isha, (Tahajjud)]
            // So:
            // 0: Fajr
            // 1: Sunrise
            // 2: SolarNoon
            // 3: Dhuhr
            // 4: Asr
            // 5: Sunset
            // 6: Maghrib
            // 7: Isha
            // 8: Tahajjud (if enabled)
            
            let t_fajr = validFloatTimes[0]
            let t_sunrise = validFloatTimes[1]
            let t_dhuhr = validFloatTimes[3]
            let t_asr = validFloatTimes[4]
            let t_sunset = validFloatTimes[5]
            let t_maghrib = validFloatTimes[6]
            let t_isha = validFloatTimes[7]
            
            // Calculate Midnight locally (Islamic)
            let midNight = (t_sunset + (t_fajr + 24.0)) / 2.0
            
            // 1. Fajr: Highlight until 30 mins to Sunrise
            if (currentHour >= t_fajr && currentHour < (t_sunrise - 30.0/60.0)) {
                focusName = "Fajr"
            }
            // 2. Dhuhr: Highlight until 10 mins to Asr
            else if (currentHour >= t_dhuhr && currentHour < (t_asr - 10.0/60.0)) {
                focusName = "Dhuhr"
            }
            // 3. Asr: Highlight until 30 mins to Sunset
            else if (currentHour >= t_asr && currentHour < (t_sunset - 30.0/60.0)) {
                focusName = "Asr"
            }
            // 4. Maghrib: Highlight only for 30 mins
            else if (currentHour >= t_maghrib && currentHour < (t_maghrib + 30.0/60.0)) {
                focusName = "Maghrib"
            }
            // 5. Isha: Highlight only until Midnight
            else if (currentHour >= t_isha && currentHour < midNight) {
                focusName = "Isha"
            }
            // 6. Tahajjud: Highlight until 5 mins to Fajr
            else if tahajjudEnabled {
                let t_tahajjud = validFloatTimes.last! // Index 8
                 // Case A: Tahajjud is before midnight (unlikely but possible if offset huge) -> Handle wrapped day? 
                 // Assuming standard Tahajjud (post-midnight, pre-Fajr)
                 // If t_tahajjud > t_isha (same day late night)
                 if t_tahajjud > t_isha {
                     if currentHour >= t_tahajjud && currentHour < (t_fajr + 24.0 - 5.0/60.0) {
                         focusName = "Tahajjud"
                     }
                 } else { 
                     // t_tahajjud < t_fajr (same day early morning)
                     if currentHour >= t_tahajjud && currentHour < (t_fajr - 5.0/60.0) {
                         focusName = "Tahajjud"
                     }
                 }
            }
            
            // Update Items (Logic copied from previous step but using new focusName)
            var newItems = self.dashboardItems
            for i in 0..<newItems.count {
                let title = newItems[i].title
                let exactMatch = (title == focusName)
                var shouldHighlight = exactMatch
                
                if newItems[i].type == .combinedPrayer {
                    if title.contains(focusName) { shouldHighlight = true }
                    if focusName.contains("Jummah") && title.contains("Dhuhr") { shouldHighlight = true }
                }
                
                if newItems[i].isNext != shouldHighlight {
                     newItems[i] = DashboardItem(
                        title: newItems[i].title, time: newItems[i].time, type: newItems[i].type, isNext: shouldHighlight
                    )
                }
            }
            if newItems != self.dashboardItems {
                self.dashboardItems = newItems
            }
            
            // Progress Calculation (Unchanged)
            // ... (rest of progress logic) ...
            var prevTime: Double = 0
            if let indexInPrayerIndices = prayerIndices.firstIndex(of: nextIdx) {
                if indexInPrayerIndices == 0 {
                    let lastIdx = prayerIndices.last!
                    prevTime = validFloatTimes[lastIdx] - 24.0
                } else {
                    let lastIdx = prayerIndices[indexInPrayerIndices - 1]
                    prevTime = validFloatTimes[lastIdx]
                }
            }
            // let totalInterval = validFloatTimes[nextIdx] - prevTime // Unused
            let elapsed = currentHour - prevTime
            // Use 1.0 (arbitrary) or just 0s normalization if interval invalid.
            // Actually progress depends on totalInterval. Used in line 630? 
            // "elapsed / totalInterval". So totalInterval IS used?
            // Ah line 755 is different variable? 
            // Warning says 755. This is 628. Let's check 755.
            
            let totalInterval = validFloatTimes[nextIdx] - prevTime
            self.progressToNextPrayer = min(max(elapsed / totalInterval, 0.0), 1.0)
            
            // Auto-Play Logic (Unchanged)
             if elapsed >= 0 && elapsed < (65.0 / 3600.0) {
                let prayerToTrigger = prayerNames[nextIdx]
                if lastTriggeredPrayer != prayerToTrigger {
                    let items = dashboardItems
                    if items.contains(where: { $0.title.contains(prayerToTrigger) }) {
                         let adhanFile = getAdhanFile(for: prayerToTrigger)
                         AudioManager.shared.playAdhan(fileName: adhanFile)
                         lastTriggeredPrayer = prayerToTrigger
                    }
                }
            } else if elapsed > (30.0 / 3600.0) {
                if lastTriggeredPrayer == prayerNames[nextIdx] {
                    lastTriggeredPrayer = nil
                }
            }
             
        } else {
            // Next is Fajr Tomorrow (Wrap-around case logic)
            self.nextPrayerName = "Fajr (Tomorrow)"
            let diff = (24 - currentHour) + validFloatTimes[0]
            self.timeRemaining = formatRemaining(diff)
            
            // Handle Isha Highlight if still before Midnight (post-24h wrap on visual clock?)
            // If currentHour > Isha and < 24. 
            // We need to re-check Isha rule here since nextIdx is -1 implies we are past all prayers (incl Isha/Tahajjud)
            // But strict Midnight might be > 24.0 (e.g. 00:30).
            // Actually nextIdx is -1 when currentHour > all_times.
            // If Last time is Tahajjud (e.g. 23:00) then nextIdx is -1 after 23:00.
            // But if Tahajjud is 04:00 (tomorrow), then it is validFloatTimes[8].
            // Usually Tahajjud is calculated strictly before Fajr (same day). 
            // If Tahajjud is 04:00 and Fajr is 05:00.
            // Then validFloatTimes sorted order: Fajr(05), ..., Isha(20), Tahajjud(04).
            // Wait, validFloatTimes is roughly sorted by day events? 
            // No, validFloatTimes comes from PrayerTimes.getPrayerTimes which returns [F, S, D, A, S, M, I].
            // If Tahajjud is added as last element, its value might be smaller than others if treated largely?
            // "actualTahajjudFloat" logic: (fajr - offset + 24) % 24. So it's small float (e.g. 4.0).
            // So validFloatTimes[8] is < validFloatTimes[7] (Isha 20.0).
            // So loop `for idx in prayerIndices` (where indices sorted?)
            // `var nextIdx = -1`: loop iterates unsorted indices?
            // The loop order matters. `prayerIndices = [0, 3, 4, 6, 7] + [8]`.
            // If time is 22:00. Isha (20:00). Tahajjud (04:00).
            // Fajr (05:00) > 22.0? No.
            // ...
            // Isha (20:00) > 22.0? No.
            // Tahajjud (04:00) > 22.0? No.
            // So nextIdx = -1. Correct (Next is F-Tom).
            
            // Should we highlight Isha?
            // Rule: "Isha only until midnight".
            // Midnight approx 00:30 (24.5).
            // If 22:00 < 24.5. Yes.
            // So we override focusName = "Isha".
            
            var focusName = "Fajr (Tomorrow)" 
            // But visual items don't have "Fajr (Tomorrow)". Just "Fajr".
            // If we want to highlight Isha card...
            
            // Re-calc midnight
            let t_fajr = validFloatTimes[0]
            let t_sunset = validFloatTimes[5]
            let t_isha = validFloatTimes[7]
            let midNight = (t_sunset + (t_fajr + 24.0)) / 2.0
            
            if currentHour >= t_isha && currentHour < midNight {
                 focusName = "Isha"
            }
            // What if Tahajjud is Enabled? 
            // Usually Tahajjud is "Next" if we are past midnight?
            // If currentHour is 01:00. 
            // Then it is < validFloatTimes[8] (04:00). Use standard logic?
            // Wait, in standard logic, `validFloatTimes[8]` (04.0) > `currentHour` (01.0).
            // So nextIdx WOULD be 8 (Tahajjud).
            // So we wouldn't be in this `else` block for 01:00.
            // We are only in this `else` block if `currentHour` > all times (e.g. 23:59).
            // So the Midnight check is relevant.
            
            // Update Focus
            var newItems = self.dashboardItems
            for i in 0..<newItems.count {
                let exactMatch = (newItems[i].title == focusName)
                var shouldHighlight = exactMatch
                if newItems[i].type == .combinedPrayer {
                   if newItems[i].title.contains(focusName) { shouldHighlight = true }
                }
                if newItems[i].isNext != shouldHighlight {
                     newItems[i] = DashboardItem(title: newItems[i].title, time: newItems[i].time, type: newItems[i].type, isNext: shouldHighlight)
                }
            }
            if newItems != self.dashboardItems { self.dashboardItems = newItems }
            
            // Progress to Fajr Tomorrow
            let ishaT = validFloatTimes[7] // Required for progress anchor
            let nextFajrTime = validFloatTimes[0] + 24.0
            let elapsed = currentHour - ishaT
            self.progressToNextPrayer = min(max(elapsed / (nextFajrTime - ishaT), 0.0), 1.0)
        }
    }
    
    func formatRemaining(_ diff: Double) -> String {
        let hours = Int(diff)
        let minutes = Int((diff - Double(hours)) * 60)
        
        if hours > 0 {
            return String(format: "%d hr %02d m", hours, minutes)
        } else {
            return String(format: "%d m", minutes)
        }
    }
    
    private func getAdhanFile(for prayerName: String) -> String {
        switch prayerName.lowercased() {
        case "fajr": return adhanFajrPref
        case "dhuhr", "jummah": return adhanDhuhrPref
        case "asr": return adhanAsrPref
        case "maghrib": return adhanMaghribPref
        case "isha": return adhanIshaPref
        case "tahajjud": return adhanTahajjudPref
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
                case "tahajjud": self.adhanTahajjudPref = fileName
                default: break
                }
                self.scheduleNotifications()
            }

        } catch {
            print("Failed to import custom adhan: \(error)")
        }
    }
}
