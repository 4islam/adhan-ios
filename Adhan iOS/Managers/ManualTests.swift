import Foundation
import CoreLocation

class ManualTests {
    static let shared = ManualTests()
    
    var log: (String) -> Void = { print($0) }
    
    func runAllTests() {
        log("--- STARTING TESTS ---")
        testPrayerTimesFormat()
        testFridayVerseLogic()
        testNotificationIdsUnique()
        testAppGroupAccess()
        testResolveSoundPath()
        log("--- ALL TESTS COMPLETED ---")
    }
    
    private func testNotificationIdsUnique() {
        log("Test: Notification ID Uniqueness")
        let manager = PrayerNotificationManager.shared
        let now = Date()
        let tomorrow = now.addingTimeInterval(86400)
        
        // Same prayer, same chunk, different day
        let id1 = manager.makeNotificationId(prayer: "Fajr", chunk: 1, date: now)
        let id2 = manager.makeNotificationId(prayer: "Fajr", chunk: 1, date: tomorrow)
        
        if id1 != id2 {
            log("✅ PASSED: IDs are unique across dates.")
        } else {
            log("❌ FAILED: IDs are identical for different dates! (\(id1))")
        }
        
        // Sanity check format
        if id1.contains("chain") && id1.contains("_") {
             log("✅ PASSED: ID format contains expected keywords.")
        } else {
             log("❌ FAILED: ID format unexpected: \(id1)")
        }
    }
    
    private func testAppGroupAccess() {
        log("Test: App Group Access")
        let suite = "group.adhan.ntrust.ai"
        if let ud = UserDefaults(suiteName: suite) {
            ud.set("test_value", forKey: "test_key")
            if ud.string(forKey: "test_key") == "test_value" {
                log("✅ PASSED: App Group UserDefaults is active.")
            } else {
                log("❌ FAILED: App Group initialized but failed to save/read.")
            }
        } else {
            log("❌ FAILED: Could not initialize UserDefaults with suite '\(suite)'. Check Entitlements/Provisioning.")
        }
    }
    
    private func testResolveSoundPath() {
        log("Test: Sound Path Resolution")
        let manager = PrayerNotificationManager.shared
        
        // 1. Test Known File (1r is known to be in AudioSegments)
        let result = manager.resolveSoundPath(for: "1r")
        
        if let _ = result.absoluteUrl {
            if result.relativePath == "AudioSegments/1r.caf" {
                log("✅ PASSED: Correctly resolved '1r' to 'AudioSegments/1r.caf'")
            } else {
                log("❌ FAILED: Resolved path was '\(result.relativePath)', expected 'AudioSegments/1r.caf'")
            }
        } else {
            log("❌ FAILED: Could not find '1r.caf' in bundle.")
        }
        
        // 2. Test Missing File
        let missing = manager.resolveSoundPath(for: "non_existent_file")
        if missing.absoluteUrl == nil {
            log("✅ PASSED: Correctly returned nil for missing file.")
        } else {
            log("❌ FAILED: Found non-existent file?")
        }
    }
    
    private func testPrayerTimesFormat() {
        log("Test: PrayerTimes Float Format")
        let pt = PrayerTimes()
        pt.setTimeFormat(.float)
        // Set arbitrary params
        pt.lat = 25.0
        pt.lng = 55.0
        pt.timeZone = 4.0
        pt.jDate = pt.julianDate(year: 2024, month: 1, day: 1)
        
        // Dry run
        let times = pt.getPrayerTimes(date: Date(), latitude: 25.0, longitude: 55.0)
        
        let validFloats = times.compactMap { Double($0) }
        
        if validFloats.count >= 7 {
            // Further check: verify they are not NaN
            if !validFloats.allSatisfy({ !$0.isNaN }) {
                log("❌ FAILED: Found NaN values in calculation.")
            } else {
                log("✅ PASSED: Calculation returned \(validFloats.count) valid floats.")
            }
        } else {
             // If format was accidentally time12, Double conversion would fail for strings like "5:00 am" -> nil
            log("❌ FAILED: Expected at least 7 floats, got \(validFloats.count). (Check setTimeFormat)")
        }
    }
    
    private func testFridayVerseLogic() {
        log("Test: Friday Verse Logic")
        
        // 1. Mock Data Setup
        let viewModel = DashboardViewModel()
        
        // Mock Asr at 15:00 (3:00 PM) = 15.0
        // We inject this by manipulating the lastCalculatedFloats
        // Indices: 0-Fajr, 1-Sunr, 2-Noon, 3-Dhuhr, 4-Asr, 5-Sset, 6-Maghrib
        var mockFloats = Array(repeating: 0.0, count: 9)
        mockFloats[4] = 15.0 // Asr
        viewModel.setLastCalculatedFloats(mockFloats)
        
        // 2. Test Friday before limit (e.g. 14:00, 1 hour before Asr) -> Should be Friday Verse
        // Create known date: Friday, Jan 2, 2026 at 14:00
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 2 // This is a Friday
        components.hour = 14
        components.minute = 0
        let fridayEarly = Calendar.current.date(from: components)!
        
        viewModel.updateVerse(date: fridayEarly)
        
        if viewModel.currentVerseEnglish.contains("all_business") {
            log("✅ PASSED: Friday Verse shown early (before Asr).")
        } else {
            log("❌ FAILED: Friday Verse NOT shown at 14:00 (Asr 15:00).")
        }
        
        // 3. Test Friday after limit (e.g. 15:10, after Asr) -> Should be Standard Verse
        components.hour = 15
        components.minute = 10
        let fridayLate = Calendar.current.date(from: components)!
        
        viewModel.updateVerse(date: fridayLate)
        
        if !viewModel.currentVerseEnglish.contains("all_business") {
             log("✅ PASSED: Standard Verse shown late (after Asr).")
        } else {
             log("❌ FAILED: Friday Verse shown too late (15:10, Asr 15:00).")
        }
        
        // 4. Test Non-Friday (e.g. Saturday Jan 3)
        components.day = 3
        components.hour = 12
        let saturday = Calendar.current.date(from: components)!
        
        viewModel.updateVerse(date: saturday)
        if !viewModel.currentVerseEnglish.contains("all_business") {
             log("✅ PASSED: Standard Verse shown on Saturday.")
        } else {
             log("❌ FAILED: Friday Verse shown on Saturday.")
        }
    }
}

// Extension to DashboardViewModel to allow injecting mock data for testing
extension DashboardViewModel {
    func setLastCalculatedFloats(_ floats: [Double]) {
        // Since lastCalculatedFloats is private effectively (not really, let's check access control)
        // Looking at file, `private var lastCalculatedFloats`. 
        // I need to change access level or use a workaround. 
        // I'll assume I can edit DashboardViewModel to make it internal for testing.
        self.lastCalculatedFloats = floats
    }
}
