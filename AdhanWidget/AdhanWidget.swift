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
            // Filter out Sunrise, Sunset, and Solar Noon
            let excluded = ["Sunrise", "Sunset", "Solar Noon"]
            var filteredNames: [String] = []
            var filteredTimes: [String] = []
            
            // Logic to preserve correct "Next Prayer" index across filtering
            var originalNextName = ""
            if data.nextIndex < data.names.count {
                originalNextName = data.names[data.nextIndex]
            }
            
            // If the *actual* next event is Sunrise/Sunset, skip forward to the next Adhan
            var checkIndex = data.nextIndex
            while checkIndex < data.names.count && excluded.contains(data.names[checkIndex]) {
                checkIndex += 1
            }
            // Wrap or clamp? Usually list is circular daily. If we run off end (after Isha), it wraps to Fajr (index 0).
            if checkIndex < data.names.count {
                originalNextName = data.names[checkIndex]
            } else {
                // If we went past end, it means next is Fajr (which is never excluded)
                originalNextName = "Fajr"
            }
            
            // Build Filtered Lists
            for (index, name) in data.names.enumerated() {
                if !excluded.contains(name) {
                    filteredNames.append(name)
                    // Safe index check
                    if index < data.times.count {
                        filteredTimes.append(data.times[index])
                    }
                }
            }
            
            // Find new index of the target "Next Prayer"
            let newNextIndex = filteredNames.firstIndex(of: originalNextName) ?? 0
            
            return AdhanEntry(
                date: Date(),
                prayerNames: filteredNames,
                prayerTimes: filteredTimes,
                nextIndex: newNextIndex,
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
 
struct MediumView: View {
    var entry: Provider.Entry
    
    var body: some View {
        HStack {
            // Left: Next Prayer Big
            SmallView(entry: entry)
                .frame(maxWidth: 120)
            
            Divider().background(Color.gray)
            
            // Right: List
            VStack(alignment: .leading, spacing: 2) {
                 ForEach(Array(entry.prayerNames.enumerated()), id: \.offset) { index, name in
                     // Only show main prayers to save space if needed
                     // But we have enough space in medium for ~4-5 lines.
                     // Let's verify bounds.
                     if index < entry.prayerTimes.count {
                         HStack {
                             Text(name)
                                 .font(.system(size: 12, weight: index == entry.nextIndex ? .bold : .regular))
                                 .foregroundStyle(index == entry.nextIndex ? .green : .gray)
                             Spacer()
                             Text(entry.prayerTimes[index])
                                 .font(.system(size: 12, design: .monospaced))
                                 .foregroundStyle(index == entry.nextIndex ? .green : .white)
                         }
                     }
                 }
            }
        }
    }
}

struct LargeView: View {
    var entry: Provider.Entry
    var body: some View {
        VStack(spacing: 20) {
            Text(entry.location)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            MediumView(entry: entry)
            
            Text(entry.hijriDate)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Helpers

func getNextPrayer(entry: AdhanEntry) -> (String, String) {
    if entry.prayerNames.indices.contains(entry.nextIndex) {
        return (entry.prayerNames[entry.nextIndex], entry.prayerTimes[entry.nextIndex])
    }
    return ("--", "--:--")
}

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
