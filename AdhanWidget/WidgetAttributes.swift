import Foundation
import ActivityKit

// Duplicated from AdhanAttributes.swift to ensure Widget Linkage
// This avoids manual Target Membership issues in Xcode.
public struct AdhanActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic state updated frequently
        public var nextPrayerName: String
        public var nextPrayerTime: String
        public var timeRemaining: String
        public var progress: Double // 0.0 to 1.0
    }

    // Static data (unchanging for the session)
    public var locationName: String
}
