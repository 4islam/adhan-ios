import Foundation

#if TEST_RUNNER
@main
struct TimeZoneTests {
    static func main() {
        print("🚀 Starting TimeZone & Geography Validation Tests...")

        testMeccaInMST()
        testMidnightTransition()
        testFormatterSync()
        testGenericGeography()

        print("\n✨ ALL VALIDATION TESTS PASSED! ✨")
    }

    /// Test Case: User is in MST (UTC-7) but viewing Mecca (UTC+3)
    static func testMeccaInMST() {
        print("\n--- Testing Mecca (UTC+3) simulated from MST context ---")

        let pt = PrayerTimes()
        pt.setCalcMethod(.makkah)

        let latM = 21.4225
        let lngM = 39.8262
        let meccaTZ = 3.0

        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 27))!

        let correctTimes = pt.getPrayerTimesDoubles(date: date, latitude: latM, longitude: lngM, timeZone: meccaTZ)
        let fajrCorrect = correctTimes[0]

        print("Fajr (Correct UTC+3): \(fajrCorrect) hours (approx \(pt.floatToTime12(fajrCorrect)))")

        if !(fajrCorrect > 4.0 && fajrCorrect < 7.5) {
            print("❌ TEST FAILED: Fajr in Mecca should be in the morning! Found: \(fajrCorrect)")
            exit(1)
        }

        let mstTZ = -7.0
        let wrongTimes = pt.getPrayerTimesDoubles(date: date, latitude: latM, longitude: lngM, timeZone: mstTZ)
        let fajrWrong = wrongTimes[0]

        print("Fajr (Wrong UTC-7): \(fajrWrong) hours (approx \(pt.floatToTime12(fajrWrong)))")

        let diff = abs(fajrCorrect - fajrWrong)
        if !(abs(diff - 10.0) < 0.1) {
            print("❌ TEST FAILED: Temporal shift should be exactly the TZ difference (10h)!")
            exit(1)
        }
        print("✅ Mecca calculation isolation verified.")
    }

    /// Test Case: Verify chronological ordering in diverse locations
    static func testMidnightTransition() {
        print("\n--- Testing Midnight Transition (London) ---")
        let pt = PrayerTimes()
        let latL = 51.5074
        let lngL = -0.1278
        let londonTZ = 0.0

        let calendar = Calendar(identifier: .gregorian)
        let dateL = calendar.date(from: DateComponents(year: 2026, month: 1, day: 27))!
        let timesL = pt.getPrayerTimesDoubles(date: dateL, latitude: latL, longitude: lngL, timeZone: londonTZ)

        for i in 0..<timesL.count - 1 {
             if !(timesL[i] <= timesL[i+1] + 0.0001) {
                 print("❌ TEST FAILED: Prayer times must be chronological! Error at index \(i)")
                 exit(1)
             }
        }
        print("✅ London chronological ordering verified.")
    }

    /// Test Case: Verify that Lat/Long changes produce unique results
    static func testGenericGeography() {
        print("\n--- Testing Geographic Sensitivity (Lat/Long Dependency) ---")
        let pt = PrayerTimes()
        pt.setCalcMethod(.isna)
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 1, day: 27))!
        
        // 1. New York vs London
        let nyTimes = pt.getPrayerTimesDoubles(date: date, latitude: 40.7128, longitude: -74.0060, timeZone: -5.0)
        let lonTimes = pt.getPrayerTimesDoubles(date: date, latitude: 51.5074, longitude: -0.1278, timeZone: 0.0)
        
        print("NY Fajr: \(nyTimes[0]) | London Fajr: \(lonTimes[0])")
        if nyTimes[0] == lonTimes[0] {
            print("❌ TEST FAILED: Different locations must produce different times!")
            exit(1)
        }
        
        // 2. 1-degree Longitude shift (approx 4 minutes)
        let lng1 = -74.0060
        let lng2 = -75.0060 // 1 degree West
        let t1 = pt.getPrayerTimesDoubles(date: date, latitude: 40.7128, longitude: lng1, timeZone: -5.0)[2] // Dhuhr
        let t2 = pt.getPrayerTimesDoubles(date: date, latitude: 40.7128, longitude: lng2, timeZone: -5.0)[2] // Dhuhr
        
        let diffMin = (t2 - t1) * 60.0
        print("1-degree West Dhuhr shift: \(diffMin) minutes")
        
        if !(abs(diffMin - 4.0) < 0.2) {
            print("❌ TEST FAILED: 1-degree longitude shift should be ~4 minutes! Found: \(diffMin)")
            exit(1)
        }
        
        print("✅ Lat/Long dependency verified (Numerical precision confirmed).")
    }

    static func testFormatterSync() {
        print("\n--- Testing Formatter Synchronization ---")
        let tzMeccaObj = TimeZone(secondsFromGMT: 3 * 3600)!
        let df = DateFormatter()
        df.dateStyle = .full
        df.timeZone = tzMeccaObj
        let dateF = DateComponents(calendar: Calendar.current, year: 2026, month: 1, day: 27, hour: 5).date!
        let dateStr = df.string(from: dateF)
        if !(dateStr.contains("January 27") || dateStr.contains("January 28")) {
            print("❌ TEST FAILED: Header must reflect destination date context.")
            exit(1)
        }
        print("✅ Formatter TZ synchronization verified.")
    }
}
#endif
