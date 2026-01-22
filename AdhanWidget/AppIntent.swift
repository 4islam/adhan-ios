import AppIntents
import WidgetKit
import Foundation

// 1. The Intent (Action)
struct PlayAdhanIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Adhan"
    static var description: IntentDescription = "Plays the Adhan audio immediately."
    static var openAppWhenRun: Bool = true // We need to open app to play audio reliably (for now)

    @Parameter(title: "Prayer Name", default: "Regular")
    var prayerName: String?

    @MainActor
    func perform() async throws -> some IntentResult {
        // AppIntents allow opening the app to perform an action
        // deeper logic would handle the audio playback in the app delegate / view model
        // but simple "Open App" is the most reliable start.
        return .result(opensIntent: OpenURLIntent(URL(string: "adhan://play")!))
    }
}

// 2. The Configuration Intent (for the Widget edit mode)
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Widget Configuration"
    static var description: IntentDescription = "Select a specific prayer to highlight."

    @Parameter(title: "Prayer Focus")
    var prayerFocus: String?
}

// 3. Helper for URL opening (Internal)
struct OpenURLIntent: AppIntent {
    static var title: LocalizedStringResource = "Open URL"
    @Parameter(title: "URL")
    var url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    init() {}
    
    @MainActor
    func perform() async throws -> some IntentResult {
        await UIApplication.shared.open(url)
        return .result()
    }
}
