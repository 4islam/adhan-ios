import WidgetKit
import SwiftUI

struct AdhanEntry: TimelineEntry {
    let date: Date
    let prayerNames: [String]
    let prayerTimes: [String]
    let nextIndex: Int
    let location: String
    let hijriDate: String
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> AdhanEntry {
        AdhanEntry(date: Date(), prayerNames: ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"], prayerTimes: ["05:00", "13:00", "16:30", "19:00", "21:00"], nextIndex: 0, location: "Loading...", hijriDate: "1445 AH")
    }

    func getSnapshot(in context: Context, completion: @escaping (AdhanEntry) -> ()) {
        completion(loadData())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AdhanEntry>) -> ()) {
        // Reload every 15 minutes to keep "Next" highlight accurate enough, 
        // or whenever the main app updates the shared defaults.
        let entry = loadData()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadData() -> AdhanEntry {
        if let data = SharedDataManager.shared.getPrayerData() {
            return AdhanEntry(
                date: Date(),
                prayerNames: data.names,
                prayerTimes: data.times,
                nextIndex: data.nextIndex,
                location: data.location,
                hijriDate: data.hijri
            )
        }
        return AdhanEntry(date: Date(), prayerNames: ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"], prayerTimes: ["05:00", "13:00", "16:30", "19:00", "21:00"], nextIndex: 0, location: "Loading...", hijriDate: "1445 AH")
    }
}

struct AdhanWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            // Background: Solid black for OLED StandBy power saving
            Color.black.edgesIgnoringSafeArea(.all)
            
            switch family {
            case .systemSmall:
                SmallView(entry: entry)
            case .systemMedium:
                MediumView(entry: entry)
            case .systemLarge:
                LargeView(entry: entry)
            case .accessoryRectangular:
                AccessoryRectangularView(entry: entry)
            case .accessoryCircular:
                AccessoryCircularView(entry: entry)
            case .accessoryInline:
                AccessoryInlineView(entry: entry)
            default:
                SmallView(entry: entry)
            }
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }
}

// MARK: - Subviews

struct AccessoryRectangularView: View {
    var entry: Provider.Entry
    var body: some View {
        let (name, time) = getNextPrayer(entry: entry)
        HStack {
            VStack(alignment: .leading) {
                Text(name)
                    .font(.headline)
                Text("Next Prayer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(time)
                .font(.system(size: 24, weight: .bold, design: .rounded))
        }
    }
}

struct AccessoryCircularView: View {
    var entry: Provider.Entry
    var body: some View {
        // Simple Countdown or Next time
        // Just showing time for now
        let (_, time) = getNextPrayer(entry: entry)
        ZStack {
            Circle().stroke(lineWidth: 2)
            VStack(spacing: 0) {
                Text(time)
                    .font(.system(size: 10, weight: .bold))
            }
        }
    }
}

struct AccessoryInlineView: View {
    var entry: Provider.Entry
    var body: some View {
        let (name, time) = getNextPrayer(entry: entry)
        Text("\(name) at \(time)")
    }
}

struct SmallView: View {
    var entry: Provider.Entry
    
    var body: some View {
        let (name, time) = getNextPrayer(entry: entry)
        
        VStack(alignment: .leading, spacing: 4) {
            // Header
            Text("NEXT PRAYER")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            // Name
            Text(name)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
            
            Spacer()
            
            // Time
            Text(time)
                .font(.system(size: 32, weight: .black, design: .monospaced))
                .foregroundStyle(.green) // Classic "Night Stand" Green
                .minimumScaleFactor(0.8)
                
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
 
// ... (Medium/Large views remain same) ...

struct AdhanWidget: Widget {
    let kind: String = "AdhanWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            AdhanWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Adhan Times")
        .description("See upcoming prayer times at a glance.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryRectangular, .accessoryCircular, .accessoryInline
        ])
        // .contentMarginsDisabled() // iOS 17 optimized for StandBy
    }
}
