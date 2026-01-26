import SwiftUI

struct NotificationSettingsView: View {
    @AppStorage("notification_enabled_Fajr") private var enabledFajr = true
    @AppStorage("notification_enabled_Dhuhr") private var enabledDhuhr = true
    @AppStorage("notification_enabled_Asr") private var enabledAsr = true
    @AppStorage("notification_enabled_Maghrib") private var enabledMaghrib = true
    @AppStorage("notification_enabled_Isha") private var enabledIsha = true
    
    // Per-day settings (stored as "1,2,3,4,5,6,7")
    @AppStorage("notification_days_Fajr") private var daysFajr = "1,2,3,4,5,6,7"
    @AppStorage("notification_days_Dhuhr") private var daysDhuhr = "1,2,3,4,5,6,7"
    @AppStorage("notification_days_Asr") private var daysAsr = "1,2,3,4,5,6,7"
    @AppStorage("notification_days_Maghrib") private var daysMaghrib = "1,2,3,4,5,6,7"
    @AppStorage("notification_days_Isha") private var daysIsha = "1,2,3,4,5,6,7"

    // Time Sensitive Toggles
    @AppStorage("time_sensitive_Fajr") private var timeSensitiveFajr = false
    @AppStorage("time_sensitive_Dhuhr") private var timeSensitiveDhuhr = false
    @AppStorage("time_sensitive_Asr") private var timeSensitiveAsr = false
    @AppStorage("time_sensitive_Maghrib") private var timeSensitiveMaghrib = false
    @AppStorage("time_sensitive_Isha") private var timeSensitiveIsha = false
    
    @EnvironmentObject var viewModel: DashboardViewModel
    
    var body: some View {
        Form {
            Section(header: Text("Prayer Notifications")) {
                prayerRow(name: "Fajr", enabled: $enabledFajr, days: $daysFajr, timeSensitive: $timeSensitiveFajr)
                prayerRow(name: "Dhuhr", enabled: $enabledDhuhr, days: $daysDhuhr, timeSensitive: $timeSensitiveDhuhr)
                prayerRow(name: "Asr", enabled: $enabledAsr, days: $daysAsr, timeSensitive: $timeSensitiveAsr)
                prayerRow(name: "Maghrib", enabled: $enabledMaghrib, days: $daysMaghrib, timeSensitive: $timeSensitiveMaghrib)
                prayerRow(name: "Isha", enabled: $enabledIsha, days: $daysIsha, timeSensitive: $timeSensitiveIsha)
            }
            
            Section(footer: Text("Disabling a prayer will stop all adhan audio and notifications for that specific time.\n\nSelect days to enable/disable notifications for specific days of the week.\n\n'Time Sensitive' attempts to break through Focus modes.")) {
                // Info footer
            }
        }
        .navigationTitle("Notifications")
        .onChange(of: enabledFajr) { _ in viewModel.scheduleNotifications() }
        .onChange(of: enabledDhuhr) { _ in viewModel.scheduleNotifications() }
        .onChange(of: enabledAsr) { _ in viewModel.scheduleNotifications() }
        .onChange(of: enabledMaghrib) { _ in viewModel.scheduleNotifications() }
        .onChange(of: enabledIsha) { _ in viewModel.scheduleNotifications() }
        
        // Reschedule on Day changes
        .onChange(of: daysFajr) { _ in viewModel.scheduleNotifications() }
        .onChange(of: daysDhuhr) { _ in viewModel.scheduleNotifications() }
        .onChange(of: daysAsr) { _ in viewModel.scheduleNotifications() }
        .onChange(of: daysMaghrib) { _ in viewModel.scheduleNotifications() }
        .onChange(of: daysIsha) { _ in viewModel.scheduleNotifications() }
        
        .onChange(of: timeSensitiveFajr) { _ in viewModel.scheduleNotifications() }
        .onChange(of: timeSensitiveDhuhr) { _ in viewModel.scheduleNotifications() }
        .onChange(of: timeSensitiveAsr) { _ in viewModel.scheduleNotifications() }
        .onChange(of: timeSensitiveMaghrib) { _ in viewModel.scheduleNotifications() }
        .onChange(of: timeSensitiveIsha) { _ in viewModel.scheduleNotifications() }
    }
    
    private func prayerRow(name: String, enabled: Binding<Bool>, days: Binding<String>, timeSensitive: Binding<Bool>) -> some View {
        VStack(alignment: .leading) {
            Toggle(name, isOn: enabled)
            
            if enabled.wrappedValue {
                DaySelector(daysString: days)
                    .padding(.top, 4)
                
                Toggle("Time Sensitive", isOn: timeSensitive)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Helper Views

struct DaySelector: View {
    @Binding var daysString: String
    
    // S M T W T F S
    // 1 2 3 4 5 6 7 (Sunday = 1)
    let days = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        HStack {
            ForEach(0..<7) { index in
                DayButton(letter: days[index], isSelected: isDaySelected(index + 1)) {
                    toggleDay(index + 1)
                }
            }
        }
    }
    
    private func isDaySelected(_ weekday: Int) -> Bool {
        let set = Set(daysString.split(separator: ",").compactMap { Int($0) })
        return set.contains(weekday)
    }
    
    private func toggleDay(_ weekday: Int) {
        var set = Set(daysString.split(separator: ",").compactMap { Int($0) })
        if set.contains(weekday) {
            set.remove(weekday)
        } else {
            set.insert(weekday)
        }
        
        // Sort and store
        let sorted = set.sorted()
        daysString = sorted.map { String($0) }.joined(separator: ",")
    }
}

struct DayButton: View {
    let letter: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 30, height: 30)
                
                Text(letter)
                    .font(.caption)
                    .bold()
                    .foregroundColor(isSelected ? .white : .primary)
            }
        }
        .buttonStyle(BorderlessButtonStyle()) // Important for Forms
    }
}
