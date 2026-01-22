import AppIntents
import SwiftUI

// 1. AppShortcutsProvider (The Key to Discovery)
struct AdhanShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayAdhanIntent(),
            phrases: [
                "Play \(.applicationName)",
                "Start Adhan in \(.applicationName)",
                "Play Adhan"
            ],
            shortTitle: "Play Adhan",
            systemImageName: "speaker.wave.3.fill"
        )
    }
}

// 2. The Intent (Moved here for Main App visibility)
struct PlayAdhanIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Adhan"
    static var description: IntentDescription = "Plays the Adhan audio immediately."
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Prayer Name", default: "Regular")
    var prayerName: String?

    @MainActor
    func perform() async throws -> some IntentResult {
        let url = URL(string: "adhan://play")!
        if #available(iOS 18.0, *) {
            return .result(opensIntent: OpenURLIntent(url))
        } else {
            // Fallback for iOS 16/17
            await UIApplication.shared.open(url)
            return .result()
        }
    }
}
