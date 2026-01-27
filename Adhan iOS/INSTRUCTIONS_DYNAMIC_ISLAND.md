# Enable Dynamic Island & Lock Screen Widgets

To finalize the "Show Next Prayer" feature on the Notch/Dynamic Island, you must add a Widget Extension to your project. This step cannot be automated.

## Step 1: Add Widget Extension

1. Open **Xcode**.
2. Go to **File > New > Target...**
3. Select **Widget Extension** (iOS).
4. Click **Next**.
5. Name it: `AdhanWidget`.
6. **Uncheck** "Include Live Activity" (we will add the code manually) or Check it (doesn't matter, we will replace the code).
7. **Uncheck** "Include Configuration Intent" (we don't need user configuration).
8. Click **Finish**.
9. Whenever asked to "Activate" scheme, click **Activate**.

## Step 2: Share the Attributes Model

1. In Xcode Project Navigator, file the file `Models/AdhanAttributes.swift` (created by me).
2. Select it.
3. In the **File Inspector** (Right Panel) -> **Target Membership**:
   - Check `Adhan iOS` (should be checked).
   - **Check `AdhanWidgetExtension`** (This matches the name you gave in Step 1).

## Step 3: Add Widget Code

1. Open the file `AdhanWidget/AdhanWidget.swift` (created by Xcode in the new folder).
2. **Delete all contents** and paste the following code:

```swift
import WidgetKit
import SwiftUI
import ActivityKit

// Note: Ensure AdhanAttributes.swift is a member of this target!

struct AdhanWidget: Widget {
    let kind: String = "AdhanWidget"

    var body: some WidgetConfiguration {
        // LOCK SCREEN & HOME SCREEN WIDGETS
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            AdhanWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Adhan Schedule")
        .description("View current and upcoming prayers.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
        
        // DYNAMIC ISLAND (Live Activity)
        ActivityConfiguration(for: AdhanActivityAttributes.self) { context in
            // Lock Screen / Banner View
            HStack {
                VStack(alignment: .leading) {
                    Text("Next: \(context.state.nextPrayerName)")
                        .font(.headline)
                    Text(context.state.nextPrayerTime)
                        .font(.subheadline)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(context.state.timeRemaining)
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                }
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.8))
            .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    VStack {
                        Text("Next")
                            .font(.caption)
                            .opacity(0.7)
                        Text(context.state.nextPrayerName)
                            .font(.headline)
                    }
                    .padding(.leading)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack {
                        Text(context.state.nextPrayerTime)
                            .font(.headline)
                        Text(context.state.timeRemaining)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(.yellow)
                    }
                    .padding(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.progress)
                        .progressViewStyle(.linear)
                        .tint(.yellow)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            } compactLeading: {
                // Compact Left
                Image(systemName: "moon.stars.fill")
                    .foregroundColor(.yellow)
            } compactTrailing: {
                // Compact Right
                Text(context.state.timeRemaining)
                    .monospacedDigit()
                    .font(.caption)
                    .foregroundColor(.yellow)
            } minimal: {
                // Minimal (Multiple activities)
                Image(systemName: "moon.stars.fill")
                    .foregroundColor(.yellow)
            }
        }
    }
}

// MARK: - Standard Widget Provider (Placeholder logic for now)
struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let entries = [SimpleEntry(date: Date())]
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct AdhanWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            Text("Open App")
            Text("for Schedule")
        }
    }
}
```

## Step 4: Run

1. Select the main app scheme (`Adhan iOS`).
2. Build and Run.
3. Go to **Settings > Features** and enable "Show Next Prayer".
4. Background the app. You should see the Dynamic Island activate!
