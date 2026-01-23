import Foundation

/// Prayer Times Calculator (Ported from PrayTime.js)
/// Original Author: Hamid Zarrabi-Zadeh
/// License: Creative Commons 3.0 (BY-NC-SA)
public class PrayerTimes {
    
    // MARK: - Constants
    
    // Calculation Methods
    public enum CalculationMethod: Int {
        case jafari = 0    // Ithna Ashari
        case karachi = 1   // University of Islamic Sciences, Karachi
        case isna = 2      // Islamic Society of North America (ISNA)
        case mwl = 3       // Muslim World League (MWL)
        case makkah = 4    // Umm al-Qura, Makkah
        case egypt = 5     // Egyptian General Authority of Survey
        case custom = 6    // Custom Setting
        case tehran = 7    // Institute of Geophysics, University of Tehran
        case ahmadiyya = 8 // Tarbiyyat Website
        
        // Provide a default for initializing
        static let `default` = CalculationMethod.ahmadiyya
    }

    // Juristic Methods
    public enum JuristicMethod: Int {
        case shafii = 0    // Shafii (standard)
        case hanafi = 1    // Hanafi
    }

    // Adjusting Methods for Higher Latitudes
    public enum HighLatMethod: Int {
        case none = 0       // No adjustment
        case midNight = 1   // middle of night
        case oneSeventh = 2 // 1/7th of night
        case angleBased = 3 // angle/60th of night
    }

    // Time Formats
    public enum TimeFormat: Int {
        case time24 = 0     // 24-hour format
        case time12 = 1     // 12-hour format
        case time12NS = 2   // 12-hour format with no suffix
        case float = 3      // floating point number
    }
    
    // MARK: - Properties
    
    public var calcMethod: CalculationMethod = .ahmadiyya
    public var asrJuristic: JuristicMethod = .shafii
    public var dhuhrMinutes: Double = 0     // minutes after mid-day for Dhuhr
    public var adjustHighLats: HighLatMethod = .angleBased
    public var timeFormat: TimeFormat = .time12
    
    public var lat: Double = 0
    public var lng: Double = 0
    public var timeZone: Double = 0
    public var jDate: Double = 0
    
    // Technical Settings
    public var numIterations: Int = 1 // number of iterations needed to compute times
    
    // Method Params: [fajrAngle, maghribSelector, maghribParam, ishaSelector, ishaParam]
    // Selector: 0 = angle, 1 = minutes
    private var methodParams: [Int: [Double?]] = [:]

    // MARK: - Initialization
    
    public init() {
        // Initialize default params matching JS
        /*
         fa : fajr angle
         ms : maghrib selector (0 = angle; 1 = minutes after sunset)
         mv : maghrib parameter value (in angle or minutes)
         is : isha selector (0 = angle; 1 = minutes after maghrib)
         iv : isha parameter value (in angle or minutes)
         */
        methodParams[CalculationMethod.jafari.rawValue]    = [16, 0, 4, 0, 14]
        methodParams[CalculationMethod.karachi.rawValue]   = [18, 1, 0, 0, 18]
        methodParams[CalculationMethod.isna.rawValue]      = [15, 1, 1, 0, 15] // added 1 minutes not 5
        methodParams[CalculationMethod.mwl.rawValue]       = [18, 1, 0, 0, 17]
        methodParams[CalculationMethod.makkah.rawValue]    = [19, 1, 0, 1, 90]
        methodParams[CalculationMethod.egypt.rawValue]     = [19.5, 1, 0, 0, 17.5]
        methodParams[CalculationMethod.tehran.rawValue]    = [17.7, 0, 4.5, 0, 15]
        methodParams[CalculationMethod.custom.rawValue]    = [18, 1, 0, 0, 17]
        // this.methodParams[this.Ahmadiyya] = new Array(14.5, 1, 1, 0, 12.3); //added 1 minutes not 5
        methodParams[CalculationMethod.ahmadiyya.rawValue] = [14.5, 1, 1, 0, 12.3]
    }
    
    // MARK: - Interface Functions
    
    // return prayer times for a given date
    public func getDatePrayerTimes(year: Int, month: Int, day: Int, latitude: Double, longitude: Double, timeZone: Double? = nil) -> [String] {
        self.lat = latitude
        self.lng = longitude
        self.timeZone = effectiveTimeZone(year: year, month: month, day: day, timeZone: timeZone)
        self.jDate = julianDate(year: year, month: month, day: day) - longitude / (15 * 24)
        
        return computeDayTimes()
    }
    
    // return prayer times for a given Date object
    public func getPrayerTimes(date: Date, latitude: Double, longitude: Double, timeZone: Double? = nil) -> [String] {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        
        guard let year = components.year, let month = components.month, let day = components.day else {
            return []
        }
        
        return getDatePrayerTimes(year: year, month: month, day: day, latitude: latitude, longitude: longitude, timeZone: timeZone)
    }
    
    // Return raw doubles avoiding string conversion issues
    public func getPrayerTimesDoubles(date: Date, latitude: Double, longitude: Double, timeZone: Double? = nil) -> [Double] {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        
        guard let year = components.year, let month = components.month, let day = components.day else {
            print("PrayerTimes Error: Components missing for date: \(date). Year: \(String(describing: components.year))")
            return []
        }
        
        // Setup internal state
        self.lat = latitude
        self.lng = longitude
        self.timeZone = effectiveTimeZone(year: year, month: month, day: day, timeZone: timeZone)
        self.jDate = julianDate(year: year, month: month, day: day) - longitude / (15 * 24)
        
        // Compute
        var times: [Double] = [5, 6, 12, 13, 18, 18, 18]
        for _ in 1...self.numIterations {
            times = computeTimes(times: times)
        }
        let result = adjustTimes(times)
        
        if result.isEmpty {
           print("PrayerTimes Error: adjustTimes returned empty!")
        }
        
        return result
    }
    
    public func setCalcMethod(_ method: CalculationMethod) {
        self.calcMethod = method
    }
    
    public func setAsrMethod(_ method: JuristicMethod) {
        self.asrJuristic = method
    }
    
    public func setFajrAngle(_ angle: Double) {
        setCustomParams([angle, nil, nil, nil, nil])
    }
    
    public func setMaghribAngle(_ angle: Double) {
        setCustomParams([nil, 0, angle, nil, nil])
    }
    
    public func setIshaAngle(_ angle: Double) {
        setCustomParams([nil, nil, nil, 0, angle])
    }
    
    public func setDhuhrMinutes(_ minutes: Double) {
        self.dhuhrMinutes = minutes
    }
    
    public func setMaghribMinutes(_ minutes: Double) {
        setCustomParams([nil, 1, minutes, nil, nil])
    }
    
    public func setIshaMinutes(_ minutes: Double) {
        setCustomParams([nil, nil, nil, 1, minutes])
    }
    
    public func setCustomParams(_ params: [Double?]) {
        for i in 0..<5 {
            if let param = params[i] {
                self.methodParams[CalculationMethod.custom.rawValue]?[i] = param
            } else {
                self.methodParams[CalculationMethod.custom.rawValue]?[i] = self.methodParams[self.calcMethod.rawValue]?[i]
            }
        }
        self.calcMethod = .custom
    }
    
    public func setHighLatsMethod(_ method: HighLatMethod) {
        self.adjustHighLats = method
    }
    
    public func setTimeFormat(_ format: TimeFormat) {
        self.timeFormat = format
    }
    
    // convert float hours to 24h format
    public func floatToTime24(_ time: Double) -> String {
        if time.isNaN { return "-----" }
        
        var t = time
        t = fixhour(t + 0.5 / 60) // add 0.5 minutes to round
        let hours = Int(floor(t))
        let minutes = Int(floor((t - Double(hours)) * 60))
        return twoDigitsFormat(hours) + ":" + twoDigitsFormat(minutes)
    }
    
    // convert float hours to any format
    public func floatToTimeFormat(_ time: Double, format: TimeFormat) -> String {
        switch format {
        case .time24:
            return floatToTime24(time)
        case .time12:
            return floatToTime12(time)
        case .time12NS:
            return floatToTime12(time, noSuffix: true)
        case .float:
            return String(time)
        }
    }
    
    // convert float hours to 12h format
    public func floatToTime12(_ time: Double, noSuffix: Bool = false) -> String {
        if time.isNaN { return "-----" }
        
        var t = time
        t = fixhour(t + 0.5 / 60) // add 0.5 minutes to round
        var hours = Int(floor(t))
        let minutes = Int(floor((t - Double(hours)) * 60))
        let suffix = hours >= 12 ? " pm" : " am"
        hours = (hours + 12 - 1) % 12 + 1
        return "\(hours):\(twoDigitsFormat(minutes))\(noSuffix ? "" : suffix)"
    }
    
    // MARK: - Calculation Functions
    
    public func sunPosition(jd: Double) -> (declination: Double, equationOfTime: Double) {
        let D = jd - 2451545.0
        let g = fixangle(357.529 + 0.98560028 * D)
        let q = fixangle(280.459 + 0.98564736 * D)
        let L = fixangle(q + 1.915 * dsin(g) + 0.020 * dsin(2 * g))
             
        _ = 1.00014 - 0.01671 * dcos(g) - 0.00014 * dcos(2 * g)
        let e = 23.439 - 0.00000036 * D
             
        let d = darcsin(dsin(e) * dsin(L))
        var RA = darctan2(y: dcos(e) * dsin(L), x: dcos(L)) / 15
        RA = fixhour(RA)
        let EqT = q / 15 - RA
        
        return (d, EqT)
    }
    
    public func equationOfTime(jd: Double) -> Double {
        return sunPosition(jd: jd).equationOfTime
    }
    
    public func sunDeclination(jd: Double) -> Double {
        return sunPosition(jd: jd).declination
    }
    
    public func computeMidDay(t: Double) -> Double {
        let T = equationOfTime(jd: self.jDate + t)
        let Z = fixhour(12 - T)
        return Z
    }
    
    public func computeTime(G: Double, t: Double) -> Double {
        let D = sunDeclination(jd: self.jDate + t)
        let Z = computeMidDay(t: t)
        let V = 1 / 15 * darccos((-dsin(G) - dsin(D) * dsin(self.lat)) / (dcos(D) * dcos(self.lat)))
        return Z + (G > 90 ? -V : V)
    }
    
    public func computeAsr(step: Double, t: Double) -> Double {
        let D = sunDeclination(jd: self.jDate + t)
        let G = -darccot(step + dtan(abs(self.lat - D)))
        return computeTime(G: G, t: t)
    }
    
    public func computeTimes(times: [Double]) -> [Double] {
        let t = dayPortion(times)
        
        // Params for current method: [fa, ms, mv, is, iv]
        guard let params = methodParams[self.calcMethod.rawValue] else { return times }
        
        let fa = params[0] ?? 18
        // let ms = params[1] ?? 1 // unused here        // Wait, ms/is_val are selectors. JS ComputeTimes:
        // var Maghrib = this.computeTime(this.methodParams[this.calcMethod][2], t[5]);
        // It uses index 2 (mv) directly. 
        // So ms index 1 is not used in computeTimes.
        let mv = params[2] ?? 0
        let iv = params[4] ?? 18
        
        let Fajr = computeTime(G: 180 - fa, t: t[0])
        let Sunrise = computeTime(G: 180 - 0.833, t: t[1])
        let Dhuhr = computeMidDay(t: t[2])
        let Asr = computeAsr(step: 1 + Double(self.asrJuristic.rawValue), t: t[3])
        let Sunset = computeTime(G: 0.833, t: t[4])
        let Maghrib = computeTime(G: mv, t: t[5])
        let Isha = computeTime(G: iv, t: t[6])
        
        // Note: JS logic for Maghrib/Isha angle vs minutes happens in adjustTimes, 
        // but here computeTime is called with G=mv/iv. 
        // wait, let's verify JS. 
        // JS: var Maghrib = this.computeTime(this.methodParams[this.calcMethod][2], t[5]);
        // JS: var Isha = this.computeTime(this.methodParams[this.calcMethod][4], t[6]);
        // Yes, it passes the parameter directly. If it's 0/1 selector, the param might be angle or minutes. 
        // If minutes, computeTime likely produces nonsense or is overridden later. 
        // See adjustTimes: checks selector (ms/is) and overwrites if necessary.
        
        return [Fajr, Sunrise, Dhuhr, Asr, Sunset, Maghrib, Isha]
    }
    
    public func computeDayTimes() -> [String] {
        var times: [Double] = [5, 6, 12, 13, 18, 18, 18] // default times
        
        for _ in 1...self.numIterations {
            times = computeTimes(times: times)
        }
        
        times = adjustTimes(times)
        return adjustTimesFormat(times)
    }
    
    public func adjustTimes(_ timesInput: [Double]) -> [Double] {
        var times = timesInput
        for i in 0..<7 {
            times[i] += self.timeZone - self.lng / 15
        }
        
        times[2] += self.dhuhrMinutes / 60 // Dhuhr
        
        guard let params = methodParams[self.calcMethod.rawValue] else { return times }
        
        // Maghrib
        if params[1] == 1 {
            times[5] = times[4] + (params[2] ?? 0) / 60
        }
        
        // Isha
        if params[3] == 1 {
            times[6] = times[5] + (params[4] ?? 0) / 60
        }
        
        if self.adjustHighLats != .none {
            times = adjustHighLatTimes(times)
        }
        
        return times
    }
    
    public func adjustTimesFormat(_ timesInput: [Double]) -> [String] {
        if self.timeFormat == .float {
            return timesInput.map { String($0) }
        }
        
        var result: [String] = []
        for time in timesInput {
            if self.timeFormat == .time12 {
                result.append(floatToTime12(time))
            } else if self.timeFormat == .time12NS {
                result.append(floatToTime12(time, noSuffix: true))
            } else {
                result.append(floatToTime24(time))
            }
        }
        return result
    }
    
    public func adjustHighLatTimes(_ timesInput: [Double]) -> [Double] {
        var times = timesInput
        let nightTime = timeDiff(times[4], times[1]) // sunset to sunrise
        
        guard let params = methodParams[self.calcMethod.rawValue] else { return times }
        
        // Adjust Fajr
        let fajrDiff = nightPortion(params[0] ?? 0) * nightTime
        if times[0].isNaN || timeDiff(times[0], times[1]) > fajrDiff {
            times[0] = times[1] - fajrDiff
        }
        
        // Adjust Isha
        let ishaAngle = (params[3] == 0) ? (params[4] ?? 18) : 18
        let ishaDiff = nightPortion(ishaAngle) * nightTime
        if times[6].isNaN || timeDiff(times[4], times[6]) > ishaDiff {
            times[6] = times[4] + ishaDiff
        }
        
        // Adjust Maghrib
        let maghribAngle = (params[1] == 0) ? (params[2] ?? 4) : 4
        let maghribDiff = nightPortion(maghribAngle) * nightTime
        if times[5].isNaN || timeDiff(times[4], times[5]) > maghribDiff {
            times[5] = times[4] + maghribDiff
        }
        
        return times
    }
    
    public func nightPortion(_ angle: Double) -> Double {
        switch self.adjustHighLats {
        case .angleBased:
            return 1.0 / 60.0 * angle
        case .midNight:
            return 1.0 / 2.0
        case .oneSeventh:
            return 1.0 / 7.0
        case .none:
            return 0
        }
    }
    
    public func dayPortion(_ times: [Double]) -> [Double] {
        return times.map { $0 / 24 }
    }
    
    // MARK: - Misc Functions
    
    public func timeDiff(_ time1: Double, _ time2: Double) -> Double {
        return fixhour(time2 - time1)
    }
    
    public func twoDigitsFormat(_ num: Int) -> String {
        return (num < 10) ? "0\(num)" : "\(num)"
    }
    
    // MARK: - Julian Date Functions
    
    public func julianDate(year: Int, month: Int, day: Int) -> Double {
        var y = year
        var m = month
        if m <= 2 {
            y -= 1
            m += 12
        }
        let A = Double(Int(floor(Double(y) / 100.0)))
        let B = 2 - A + floor(A / 4.0)
        
        let term1 = floor(365.25 * Double(y + 4716))
        let term2 = floor(30.6001 * Double(m + 1))
        
        let JD = term1 + term2 + Double(day) + B - 1524.5
        return JD
    }
    
    // MARK: - Time-Zone Functions
    
    public func getTimeZone(date: Date) -> Double {
        // Swift TimeZone
        // JS: var hoursDiff = (localDate - GMTDate) / (1000 * 60 * 60);
        // Swift: TimeZone.current.secondsFromGMT() / 3600
        let seconds = TimeZone.current.secondsFromGMT(for: date)
        return Double(seconds) / 3600.0
    }
    
    public func effectiveTimeZone(year: Int, month: Int, day: Int, timeZone: Double?) -> Double {
        if let timeZone = timeZone {
            return timeZone
        }
        // Construct date
        let components = DateComponents(year: year, month: month, day: day)
        if let date = Calendar.current.date(from: components) {
            return getTimeZone(date: date)
        }
        return 0
    }
    
    // MARK: - Trigonometric Functions
    
    public func dsin(_ d: Double) -> Double {
        return sin(dtr(d))
    }
    
    public func dcos(_ d: Double) -> Double {
        return cos(dtr(d))
    }
    
    public func dtan(_ d: Double) -> Double {
        return tan(dtr(d))
    }
    
    public func darcsin(_ x: Double) -> Double {
        return rtd(asin(x))
    }
    
    public func darccos(_ x: Double) -> Double {
        return rtd(acos(x))
    }
    
    public func darctan(_ x: Double) -> Double {
        return rtd(atan(x))
    }
    
    public func darctan2(y: Double, x: Double) -> Double {
        return rtd(atan2(y, x))
    }
    
    public func darccot(_ x: Double) -> Double {
        return rtd(atan(1.0 / x))
    }
    
    public func dtr(_ d: Double) -> Double {
        return (d * Double.pi) / 180.0
    }
    
    public func rtd(_ r: Double) -> Double {
        return (r * 180.0) / Double.pi
    }
    
    public func fixangle(_ a: Double) -> Double {
        var a = a - 360.0 * floor(a / 360.0)
        a = a < 0 ? a + 360.0 : a
        return a
    }
    
    public func fixhour(_ a: Double) -> Double {
        var a = a - 24.0 * floor(a / 24.0)
        a = a < 0 ? a + 24.0 : a
        return a
    }
}
