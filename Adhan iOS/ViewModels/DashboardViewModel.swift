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
    
    // Performance Cache for different dates
    private var calculationCache: [String: CalculationResults] = [:]
    private let cacheLock = NSLock()
    private var navigationWorkItem: DispatchWorkItem?

    
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
    
    // Debugging
    @Published var performanceLog: String = ""
    private var debugLogs: [String] = []
    
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
        f.calendar = Calendar(identifier: .islamicUmmAlQura)
        f.dateFormat = "d MMMM yyyy"
        return f
    }()
    
    static let cacheKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
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
            .compactMap { $0 }
            .sink { [weak self] newLocation in
                guard let self = self else { return }
                
                // Debounce Logic: 500m distance or significant time has passed
                let now = Date()
                let timeSinceLast = self.lastCalculationDate != nil ? now.timeIntervalSince(self.lastCalculationDate!) : 9999
                
                if let last = self.lastGeocodedLocation {
                    let distance = newLocation.distance(from: last)
                    if distance < 500 && timeSinceLast < 600 { // 500m or 10 mins
                        return
                    }
                }
                
                print("DashboardViewModel: Location updated! Recalculating schedule...")
                self.lastCalculationDate = nil // Force recalculation bypass logic
                self.calculatePrayerTimes(location: LocationManager.shared)
                
                // Throttled notification scheduling
                self.queueThrottledNotificationSchedule()
            }
            .store(in: &cancellables)
    }
    
    private var scheduleWorkItem: DispatchWorkItem?
    
    private func queueThrottledNotificationSchedule() {
        scheduleWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.scheduleNotifications()
        }
        scheduleWorkItem = item
        // Wait 2 seconds of stillness before rebuilding the entire 60-slot queue
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: item)
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
        cacheLock.lock()
        calculationCache.removeAll()
        cacheLock.unlock()
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
        // Reset state
        self.loadingStatus = "Loading..."
        self.isCalculating = true
        
        // Cancel any pending calculation from rapid clicking
        navigationWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.calculatePrayerTimes(location: LocationManager.shared)
        }
        
        self.navigationWorkItem = workItem
        // 150ms delay: filters fast spamming but feels nearly instant for single clicks
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
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
        
        // Move to background thread to avoid UI lag
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            self.performNotificationScheduling()
        }
    }
    
    private func performNotificationScheduling() {
        // Clear all pending before rebuilding (This is fast)
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
        let MAX_NOTIFICATIONS = 60
        var dayOffset = 0
        
        LogManager.shared.log("Dashboard: Starting scheduling loop (Max: \(MAX_NOTIFICATIONS))...")
        
        // Reuse PrayerTimes instance to avoid redundant initialization overhead
        let pt = PrayerTimes()
        
        schedulingLoop: while scheduledCount < MAX_NOTIFICATIONS {

            if dayOffset > 30 { break }
            
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else {
                dayOffset += 1
                continue
            }
            
            // --- Optimized Calculation Logic ---
            if let method = PrayerTimes.CalculationMethod(rawValue: startCalcMethod) { pt.setCalcMethod(method) }
            pt.setAsrMethod(asrForHanafi ? .hanafi : .shafii)
            if let highLat = PrayerTimes.HighLatMethod(rawValue: highLatMethod) { pt.setHighLatsMethod(highLat) }
            pt.setTimeFormat(.float)
            
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
            
            var validFloats = pt.getPrayerTimesDoubles(date: targetDate, latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
            
            if validFloats.count < 7 {
                dayOffset += 1
                continue
            }
            
            validFloats[0] = (validFloats[0] + fajrOffset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
            validFloats[5] = (validFloats[5] + maghribOffset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
            validFloats[6] = (validFloats[6] + ishaOffset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
            
            let basicNames = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Sunset", "Maghrib", "Isha"]
            var tahajjudTime: Double? = nil
            if tahajjudEnabled {
                tahajjudTime = (validFloats[0] - tahajjudOffset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
            }
            
            for (idx, name) in basicNames.enumerated() {
                if name == "Sunrise" || name == "Sunset" { continue }
                let floatTime = validFloats[idx]
                let adhanFile = getAdhanFile(for: name)
                var cost = 1
                if adhanFile == "adhan_fajr" { cost = 10 }
                else if adhanFile == "adhan_regular" { cost = 6 }
                
                if scheduledCount + cost > MAX_NOTIFICATIONS {
                    break schedulingLoop
                }
                
                if scheduleSinglePrayer(name: name, floatTime: floatTime, baseDate: targetDate, calendar: calendar, checkDate: now) {
                     scheduledCount += cost
                }
            }
            
            if let tTime = tahajjudTime {
                 let tName = "Tahajjud"
                 let adhanFile = getAdhanFile(for: tName)
                 var cost = 1
                 if adhanFile == "adhan_fajr" { cost = 10 }
                 else if adhanFile == "adhan_regular" { cost = 6 }
                 
                 if scheduledCount + cost <= MAX_NOTIFICATIONS {
                      if scheduleSinglePrayer(name: tName, floatTime: tTime, baseDate: targetDate, calendar: calendar, checkDate: now) {
                          scheduledCount += cost
                      }
                 } else {
                      break schedulingLoop
                 }
            }
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
        
        // Safety Debounce: Don't recalculate if location changed very little (e.g. GPS jitter)
        // unless it's been a long time (1 hour from updateTime() or 10 mins here)
        if let lastLoc = self.lastGeocodedLocation {
            let distance = loc.distance(from: lastLoc)
            let timeSinceLast = Date().timeIntervalSince(self.lastCalculationDate ?? Date.distantPast)
            
            // If we are viewing 'today' and moved < 500m and calculated < 10 mins ago, skip
            if self.isToday && distance < 500 && timeSinceLast < 600 {
                self.isCalculating = false
                return
            }
        }
        
        let date = selectedDate
        let dateKey = DashboardViewModel.cacheKeyFormatter.string(from: date)
        
        // Check cache first
        cacheLock.lock()
        let cached = calculationCache[dateKey]
        cacheLock.unlock()
        
        if let results = cached {
            LogManager.shared.log("[Perf] Cache hit for \(dateKey)")
            // Simulate inputs for applyResults
            let inputs = CalculationInputs(
                startCalcMethod: self.startCalcMethod,
                asrForHanafi: self.asrForHanafi,
                highLatMethod: self.highLatMethod,
                timeFormat: self.timeFormat,
                tahajjudOffset: self.tahajjudOffset,
                fajrOffset: self.fajrOffset,
                maghribOffset: self.maghribOffset,
                ishaOffset: self.ishaOffset,
                combineShortNightEnabled: self.combineShortNightEnabled,
                shortNightDuration: self.shortNightDuration,
                combineThreshold: self.combineThreshold,
                asrMaghribGapThreshold: self.asrMaghribGapThreshold,
                isCombinedDhuhrAsr: self.isCombinedDhuhrAsr,
                isCombinedMaghribIsha: self.isCombinedMaghribIsha,
                tahajjudEnabled: self.tahajjudEnabled,
                nextPrayerName: self.nextPrayerName,
                isToday: self.isToday,
                dashboardItems: self.dashboardItems
            )
            self.applyResults(results, inputs: inputs, startTime: CFAbsoluteTimeGetCurrent(), loc: loc)
            return
        }
        
        self.isCalculating = true
        self.loadingStatus = "Calculating Schedule..."
        // Use local constant for thread safety below
        
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
        
        // Bundle inputs to simplify closure for compiler
        let inputs = CalculationInputs(
            startCalcMethod: startCalcMethod,
            asrForHanafi: asrForHanafi,
            highLatMethod: highLatMethod,
            timeFormat: timeFormat,
            tahajjudOffset: tahajjudOffset,
            fajrOffset: fajrOffset,
            maghribOffset: maghribOffset,
            ishaOffset: ishaOffset,
            combineShortNightEnabled: combineShortNightEnabled,
            shortNightDuration: shortNightDuration,
            combineThreshold: combineThreshold,
            asrMaghribGapThreshold: asrMaghribGapThreshold,
            isCombinedDhuhrAsr: isCombinedDhuhrAsr,
            isCombinedMaghribIsha: isCombinedMaghribIsha,
            tahajjudEnabled: tahajjudEnabled,
            nextPrayerName: nextPrayerName,
            isToday: isToday,
            dashboardItems: dashboardItems
        )
        
        // Move to Background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performCalculation(inputs: inputs, date: date, loc: loc)
        }
    }

    // struct to hold calculation inputs
    struct CalculationInputs {
        let startCalcMethod: Int
        let asrForHanafi: Bool
        let highLatMethod: Int
        let timeFormat: Int
        let tahajjudOffset: Double
        let fajrOffset: Double
        let maghribOffset: Double
        let ishaOffset: Double
        let combineShortNightEnabled: Bool
        let shortNightDuration: Double
        let combineThreshold: Double
        let asrMaghribGapThreshold: Double
        let isCombinedDhuhrAsr: Bool
        let isCombinedMaghribIsha: Bool
        let tahajjudEnabled: Bool
        let nextPrayerName: String
        let isToday: Bool
        let dashboardItems: [DashboardItem]
    }

    struct CalculationResults {
        let solarNoon: String
        let sunRise: String
        let sunSet: String
        let midnightTime: String
        let isCombinedDhuhrAsr: Bool
        let isCombinedMaghribIsha: Bool
        let prayerNames: [String]
        let prayerTimes: [String] 
        let prayerDates: [Date]   
        let compareTimes: [Double] // NEW: Pass the pre-computed floats for determineNextPrayer
        let dashboardItems: [DashboardItem]
        let moonrise: String 
        let moonset: String
        let sunPosition: AstroPosition?
        let currentDateString: String
        let hijriDateString: String
        let date: Date
    }

    private func performCalculation(inputs: CalculationInputs, date: Date, loc: CLLocation) {
        // Unpack inputs to restore local scope
        let startCalcMethod = inputs.startCalcMethod
        let asrForHanafi = inputs.asrForHanafi
        let highLatMethod = inputs.highLatMethod
        let timeFormat = inputs.timeFormat
        let tahajjudOffset = inputs.tahajjudOffset
        let fajrOffset = inputs.fajrOffset
        let maghribOffset = inputs.maghribOffset
        let ishaOffset = inputs.ishaOffset
        let combineShortNightEnabled = inputs.combineShortNightEnabled
        let shortNightDuration = inputs.shortNightDuration
        let combineThreshold = inputs.combineThreshold
        let asrMaghribGapThreshold = inputs.asrMaghribGapThreshold
        let isCombinedDhuhrAsr = inputs.isCombinedDhuhrAsr
        let isCombinedMaghribIsha = inputs.isCombinedMaghribIsha
        let tahajjudEnabled = inputs.tahajjudEnabled
        let nextPrayerName = inputs.nextPrayerName
        let isToday = inputs.isToday
        let dashboardItems = inputs.dashboardItems

        let startTime = CFAbsoluteTimeGetCurrent()
        let pt = PrayerTimes()

        // Extract components once
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 2000
        let month = components.month ?? 1
        let day = components.day ?? 1
            
        // Apply Settings
        if let method = PrayerTimes.CalculationMethod(rawValue: inputs.startCalcMethod) {
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
        pt.timeZone = pt.effectiveTimeZone(year: year, month: month, day: day, timeZone: nil)
        pt.jDate = pt.julianDate(year: year, month: month, day: day) - pt.lng / (15 * 24)
        
        let zawalFloat = pt.computeMidDay(t: 12.0/24.0) + (pt.timeZone - pt.lng / 15.0)
        let solarNoonStr = pt.floatToTimeFormat(zawalFloat, format: originalFormat)
        
        // 2. Main Calculation (Optimized: Get Doubles directly)
        pt.setDhuhrMinutes(10.0) 
        let adjustedFloatTimes = pt.getPrayerTimesDoubles(date: date, latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
        
        if adjustedFloatTimes.count < 7 { return }
            
        // 4. Tahajjud (minutes before Fajr)
        let actualTahajjudFloat = (adjustedFloatTimes[0] - tahajjudOffset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
        
        // 5. Combining Logic
        var fajrFloatVal = adjustedFloatTimes[0]
        let dhuhrFloat = adjustedFloatTimes[2]
        let asrFloat = adjustedFloatTimes[3]
        var maghribFloatVal = adjustedFloatTimes[5]
        var ishaFloatVal = adjustedFloatTimes[6]
        
        // Apply Manual Offsets (minutes to hours)
        fajrFloatVal = (fajrFloatVal + fajrOffset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
        maghribFloatVal = (maghribFloatVal + maghribOffset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
        ishaFloatVal = (ishaFloatVal + ishaOffset / 60.0 + 24.0).truncatingRemainder(dividingBy: 24.0)
        
        // Update with adjusted offsets
        var offsetAdjusted = adjustedFloatTimes
        offsetAdjusted[0] = fajrFloatVal
        offsetAdjusted[5] = maghribFloatVal
        offsetAdjusted[6] = ishaFloatVal
        
        var isShortNight = false
        if combineShortNightEnabled {
             let nightDuration = (24.0 - ishaFloatVal) + fajrFloatVal 
             if nightDuration < shortNightDuration {
                 isShortNight = true
             }
        }
        
        let asrMaghribGap = (maghribFloatVal - asrFloat) * 60.0
        let newIsCombinedDhuhrAsr = ((asrFloat - dhuhrFloat) * 60.0 <= combineThreshold) || (asrMaghribGap <= asrMaghribGapThreshold)
        let newIsCombinedMaghribIsha = isShortNight || ((ishaFloatVal - maghribFloatVal) * 60.0 <= combineThreshold)

            
            // 6. Format Strings for individual display
            pt.setTimeFormat(originalFormat)
            let finalPrayerTimes = pt.adjustTimesFormat(offsetAdjusted)
            
            let sunRiseStr = finalPrayerTimes[1]
            let sunSetStr = finalPrayerTimes[4]
            
            // 7. Names and Tahajjud
            var names = ["Fajr", "Sunrise", "Solar Noon", "Dhuhr", "Asr", "Sunset", "Maghrib", "Isha"]
            let wDayResult = calendar.component(.weekday, from: date)
            if wDayResult == 6 {
                names[3] = "Jummah (or Dhuhr)"
            }
            
            var finalTimesWithNoon = finalPrayerTimes
            finalTimesWithNoon.insert(solarNoonStr, at: 2)
            
            // Midnight calculation
            let fNext = offsetAdjusted[0] + 24.0
            let sSet = offsetAdjusted[4] // Sunset
            let midFloat = (sSet + fNext) / 2.0
            let midnightStr = pt.floatToTimeFormat(midFloat.truncatingRemainder(dividingBy: 24.0), format: originalFormat)

             if tahajjudEnabled {
                 names.append("Tahajjud")
                 finalTimesWithNoon.append(pt.floatToTimeFormat(actualTahajjudFloat, format: originalFormat))
             }
             
            // Build consistent compareTimes and prayerDates
            var compareTimes: [Double] = offsetAdjusted
            compareTimes.insert(zawalFloat, at: 2)
            if tahajjudEnabled {
                compareTimes.append(actualTahajjudFloat)
            }

            
            var prayerByteDates: [Date] = []
            for f in compareTimes {
                let h = Int(f)
                let m = Int((f - Double(h)) * 60)
                let s = Int(((f * 60) - floor(f * 60)) * 60)
                if let d = Calendar.current.date(bySettingHour: h, minute: m, second: s, of: date) {
                    prayerByteDates.append(d)
                } else {
                    prayerByteDates.append(date) // Fallback
                }
            }

            // 8. Build Dashboard Items
            var newItems: [DashboardItem] = []
            var i = 0
            while i < names.count {
                let name = names[i]
                let time = finalTimesWithNoon[i]
                let isEvent = (name == "Sunrise" || name == "Sunset" || name == "Solar Noon")
                
                // Temporary next check for rendering
                let isNext = false 
                
                if name == "Dhuhr" || name == "Jummah" {
                    if newIsCombinedDhuhrAsr {
                        newItems.append(DashboardItem(title: "\(name) & Asr", time: time, type: .combinedPrayer, isNext: isNext))
                        i += 2; continue
                    }
                } else if name == "Maghrib" {
                    if newIsCombinedMaghribIsha {
                        newItems.append(DashboardItem(title: "Maghrib & Isha", time: time, type: .combinedPrayer, isNext: isNext))
                        i += 2; continue
                    }
                }
                
                if !isEvent {
                    let itemType: DashboardItem.ItemType = (name == "Tahajjud") ? .sunnah : .prayer
                    newItems.append(DashboardItem(title: name, time: time, type: itemType, isNext: isNext))
                }
                i += 1
            }

            let mRise = Astrology.getMoonrise(date: date, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
            let mSet = Astrology.getMoonset(date: date, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
            
            let moonRiseStr = mRise != nil ? pt.floatToTimeFormat(Double(calendar.component(.hour, from: mRise!)) + Double(calendar.component(.minute, from: mRise!)) / 60.0, format: originalFormat) : "--:--"
            let moonSetStr = mSet != nil ? pt.floatToTimeFormat(Double(calendar.component(.hour, from: mSet!)) + Double(calendar.component(.minute, from: mSet!)) / 60.0, format: originalFormat) : "--:--"
            let sunPos = Astrology.getSunPosition(date: date, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
            let curDateStr = DashboardViewModel.dateFormatter.string(from: date)
            let hijriStr = DashboardViewModel.hijriFormatter.string(from: date)

            // Package results
            let results = CalculationResults(
                solarNoon: solarNoonStr,
                sunRise: sunRiseStr,
                sunSet: sunSetStr,
                midnightTime: midnightStr,
                isCombinedDhuhrAsr: newIsCombinedDhuhrAsr,
                isCombinedMaghribIsha: newIsCombinedMaghribIsha,
                prayerNames: names,
                prayerTimes: finalTimesWithNoon, 
                prayerDates: prayerByteDates,    
                compareTimes: compareTimes,
                dashboardItems: newItems,
                moonrise: moonRiseStr,
                moonset: moonSetStr,
                sunPosition: sunPos,
                currentDateString: curDateStr,
                hijriDateString: hijriStr,
                date: date
            )
            
            DispatchQueue.main.async { [weak self] in
                self?.applyResults(results, inputs: inputs, startTime: startTime, loc: loc)
            }
        } // Close performCalculation
    
    private func applyResults(_ results: CalculationResults, inputs: CalculationInputs, startTime: Double, loc: CLLocation) {
         let mainStart = CFAbsoluteTimeGetCurrent()
         let now = Date()
         
         // Store in cache if not already there (only if it matches the requested date)
         let dateKey = DashboardViewModel.cacheKeyFormatter.string(from: results.date)
         
         cacheLock.lock()
         calculationCache[dateKey] = results
         cacheLock.unlock()

         if self.selectedDate != results.date {
             LogManager.shared.log("[Perf] Handled update for \(results.currentDateString). UI is viewing different date: \(self.currentDateString)")
             self.isCalculating = false
             return
         }

         
         self.solarNoon = results.solarNoon
         self.sunRise = results.sunRise
         self.sunSet = results.sunSet
         self.midnightTime = results.midnightTime
         
         self.isCombinedDhuhrAsr = results.isCombinedDhuhrAsr
         self.isCombinedMaghribIsha = results.isCombinedMaghribIsha
         
         self.prayerNames = results.prayerNames
         self.prayerTimes = results.prayerTimes
         self.dashboardItems = results.dashboardItems
         
         self.moonrise = results.moonrise
         self.moonset = results.moonset
         self.sunPosition = results.sunPosition
         
         self.currentDateString = results.currentDateString
         self.hijriDateString = results.hijriDateString
         self.lastCalculatedFloats = results.compareTimes
         self.lastCalculationDate = results.date // Keep track for 1-hour periodic refresh
          if results.date.timeIntervalSince(Date()) < 86400 && results.date.timeIntervalSince(Date()) > -86400 {
              // It's effectively today, use this as our anchor for location debouncing
              self.lastCalculationDate = Date() 
          }
         
         if inputs.isToday {
             self.determineNextPrayer(validFloatTimes: results.compareTimes, date: now)
         } else {
             self.nextPrayerIndex = -1
             self.nextPrayerName = ""
             self.timeRemaining = ""
             self.progressToNextPrayer = 0.0
         }
         
         self.reverseGeocode(loc)
         self.lastGeocodedLocation = loc

         
         // Shared Data - ONLY update for Today's date to avoid widget stale data & preference spam
         if inputs.isToday {
             DispatchQueue.global(qos: .background).async {
                 SharedDataManager.shared.savePrayerData(
                     times: self.prayerTimes,
                     names: self.prayerNames,
                     nextIndex: self.nextPrayerIndex,
                     location: self.locationName,
                     hijri: self.hijriDateString
                 )
             }
         }
         
         self.isCalculating = false
         if self.isLoading {
             // Dismiss loading
              if !self.isCalculating {
                  withAnimation { self.isLoading = false }
              }
         }
         
         let uiUpdateTime = CFAbsoluteTimeGetCurrent()
         let logTotal = "Total: \(String(format: "%.1f", (uiUpdateTime - startTime) * 1000))ms"
         LogManager.shared.log("[Perf] Date Change: UI: \(String(format: "%.1f", (uiUpdateTime - mainStart) * 1000))ms | \(logTotal)")
         self.performanceLog = logTotal
         
         if inputs.isToday && self.nextPrayerIndex != -1 {
             LiveActivityManager.shared.start(
                 nextPrayer: self.nextPrayerName,
                 time: self.formatTime(results.prayerDates[self.nextPrayerIndex]),
                 remaining: self.timeRemaining,
                 progress: self.progressToNextPrayer,
                 location: self.locationName
             )
         }
         
          // Phase 2 Moon
         DispatchQueue.global(qos: .userInitiated).async {
            let phase2Start = CFAbsoluteTimeGetCurrent()
            var mRise = "--:--"
            var mSet = "--:--"
            if let rise = Astrology.getMoonrise(date: results.date, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude) {
                mRise = self.formatTime(rise)
            }
            if let set = Astrology.getMoonset(date: results.date, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude) {
                mSet = self.formatTime(set)
            }
            let mPos = Astrology.getMoonPosition(date: results.date, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
            
            DispatchQueue.main.async {
                self.moonrise = mRise
                self.moonset = mSet
                self.moonPosition = mPos
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
