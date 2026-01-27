import Foundation
import CoreLocation

struct SharedDataKeys {
    static let suiteName = "group.adhan.ntrust.ai"
    static let prayerTimes = "shared_prayer_times"
    static let prayerNames = "shared_prayer_names"
    static let nextPrayerIndex = "shared_next_prayer_index"
    static let locationName = "shared_location_name"
    static let hijriDate = "shared_hijri_date"
    static let nextPrayerTime = "shared_next_prayer_time"
}

class SharedDataManager {
    static let shared = SharedDataManager()
    
    private let defaults: UserDefaults?
    
    private init() {
        if let shared = UserDefaults(suiteName: SharedDataKeys.suiteName) {
            self.defaults = shared
        } else {
            print("⚠️ SharedDataManager: App Group '\(SharedDataKeys.suiteName)' not available. Falling back to standard UserDefaults. Widget sync will NOT work.")
            self.defaults = UserDefaults.standard
        }
    }
    
    func savePrayerData(times: [String], names: [String], nextIndex: Int, location: String, hijri: String) {
        // Optimization: Only write if data changed to avoid flooding OS preference logs
        if let existing = getPrayerData(),
           existing.times == times,
           existing.names == names,
           existing.nextIndex == nextIndex,
           existing.location == location,
           existing.hijri == hijri {
            return
        }
        
        defaults?.set(times, forKey: SharedDataKeys.prayerTimes)
        defaults?.set(names, forKey: SharedDataKeys.prayerNames)
        defaults?.set(nextIndex, forKey: SharedDataKeys.nextPrayerIndex)
        defaults?.set(location, forKey: SharedDataKeys.locationName)
        defaults?.set(hijri, forKey: SharedDataKeys.hijriDate)
        
        // Save timestamp of update to know if data is stale
        defaults?.set(Date(), forKey: "last_update_timestamp")
    }
    
    func getPrayerData() -> (times: [String], names: [String], nextIndex: Int, location: String, hijri: String)? {
        guard let times = defaults?.stringArray(forKey: SharedDataKeys.prayerTimes),
              let names = defaults?.stringArray(forKey: SharedDataKeys.prayerNames) else {
            return nil
        }
        
        let nextIndex = defaults?.integer(forKey: SharedDataKeys.nextPrayerIndex) ?? 0
        let location = defaults?.string(forKey: SharedDataKeys.locationName) ?? "--"
        let hijri = defaults?.string(forKey: SharedDataKeys.hijriDate) ?? ""
        
        return (times, names, nextIndex, location, hijri)
    }
    
    // Helper to get defaults for other direct usages
    func getDefaults() -> UserDefaults? {
        return defaults
    }
}
