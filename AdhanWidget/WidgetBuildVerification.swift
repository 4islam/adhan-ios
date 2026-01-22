import SwiftUI
import WidgetKit

// This file exists solely to ensure that the required Views for the Widget remain in the codebase.
// If MediumView, LargeView, or Helper functions are deleted, this file will fail to compile.

#if DEBUG
struct WidgetBuildVerification {
    func verifyViewsExist() {
        let entry = AdhanEntry(
            date: Date(),
            prayerNames: [],
            prayerTimes: [],
            nextIndex: 0,
            location: "Test",
            hijriDate: "Test"
        )
        
        // Verify Views are instantiable
        _ = SmallView(entry: entry)
        _ = MediumView(entry: entry)
        _ = LargeView(entry: entry)
        
        // Verify Accessory Views
        _ = AccessoryRectangularView(entry: entry)
        _ = AccessoryCircularView(entry: entry)
        _ = AccessoryInlineView(entry: entry)
        
        // Verify Helper
        _ = getNextPrayer(entry: entry)
    }
}
#endif
