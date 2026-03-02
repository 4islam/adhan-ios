import SwiftUI

struct AdhanHistoryView: View {
    @StateObject private var historyManager = AdhanHistoryManager.shared
    
    var body: some View {
        List {
            if historyManager.history.isEmpty {
                Section {
                    Text("No past events recorded yet.")
                        .foregroundColor(.secondary)
                        .italic()
                }
            } else {
                ForEach(historyManager.history) { entry in
                    historyRow(entry: entry)
                }
            }
        }
        .navigationTitle("Past Events")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    historyManager.clearHistory()
                } label: {
                    Text("Clear")
                }
            }
        }
    }
    
    private func historyRow(entry: AdhanHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.prayerName)
                    .font(.headline)
                
                Spacer()
                
                Text(entry.eventType.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(colorForType(entry.eventType).opacity(0.2))
                    .foregroundColor(colorForType(entry.eventType))
                    .cornerRadius(8)
            }
            
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                Text(formatTimestamp(entry.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let sched = entry.scheduledTime {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.secondary)
                    Text("Scheduled for: \(formatTimestamp(sched))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let device = entry.device {
                HStack {
                    Image(systemName: "speaker.wave.2")
                        .foregroundColor(.secondary)
                    Text("Output: \(device)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let vol = entry.volume {
                HStack {
                    Image(systemName: "speaker.wave.3")
                        .foregroundColor(.secondary)
                    Text("Volume: \(Int(vol * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let details = entry.details {
                Text(details)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func colorForType(_ type: AdhanHistoryEntry.AdhanEventType) -> Color {
        switch type {
        case .scheduled: return .blue
        case .triggered: return .orange
        case .played: return .green
        case .actionTaken: return .purple
        case .failed: return .red
        }
    }
}

struct AdhanHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AdhanHistoryView()
        }
    }
}
