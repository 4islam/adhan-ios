import AppIntents
import WidgetKit
import Foundation



// 2. The Configuration Intent (for the Widget edit mode)
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Widget Configuration"
    static var description: IntentDescription = "Select a specific prayer to highlight."

    @Parameter(title: "Prayer Focus")
    var prayerFocus: String?
}


