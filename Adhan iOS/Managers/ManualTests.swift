import Foundation
import CoreLocation

class ManualTests {
    static let shared = ManualTests()
    
    var log: (String) -> Void = { print($0) }
    
    func runAllTests() {
        log("--- STARTING TESTS ---")
        testPrayerTimesFormat()
        testFridayVerseLogic()
        log("--- ALL TESTS COMPLETED ---")
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
        
        // Mock Maghrib at 18:00 (6:00 PM) = 18.0
        // We inject this by manipulating the lastCalculatedFloats
        // Indices: 0,1,2,3,4,5,6 (Maghrib)
        var mockFloats = Array(repeating: 0.0, count: 7)
        mockFloats[6] = 18.0 // Maghrib
        viewModel.setLastCalculatedFloats(mockFloats)
        
        // 2. Test Friday before limit (e.g. 17:00, 1 hour before Maghrib) -> Should be Friday Verse
        // Create known date: Friday, Jan 2, 2026 at 17:00
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 2 // This is a Friday
        components.hour = 17
        components.minute = 0
        let fridayEarly = Calendar.current.date(from: components)!
        
        viewModel.updateVerse(date: fridayEarly)
        
        if viewModel.currentVerseEnglish.contains("all_business") {
            log("✅ PASSED: Friday Verse shown early.")
        } else {
            log("❌ FAILED: Friday Verse NOT shown at 17:00 (Maghrib 18:00).")
        }
        
        // 3. Test Friday after limit (e.g. 17:40, 20 mins before Maghrib) -> Should be Standard Verse
        components.minute = 40
        let fridayLate = Calendar.current.date(from: components)!
        
        viewModel.updateVerse(date: fridayLate)
        
        if !viewModel.currentVerseEnglish.contains("all_business") {
             log("✅ PASSED: Standard Verse shown late (20 mins to Maghrib).")
        } else {
             log("❌ FAILED: Friday Verse shown too late (17:40, Maghrib 18:00).")
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
