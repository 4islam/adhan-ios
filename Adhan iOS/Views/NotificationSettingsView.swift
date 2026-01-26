import SwiftUI

struct NotificationSettingsView: View {
    @AppStorage("notification_enabled_Fajr") private var enabledFajr = true
    @AppStorage("notification_enabled_Dhuhr") private var enabledDhuhr = true
    @AppStorage("notification_enabled_Asr") private var enabledAsr = true
    @AppStorage("notification_enabled_Maghrib") private var enabledMaghrib = true
    @AppStorage("notification_enabled_Isha") private var enabledIsha = true
    
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
                prayerRow(name: "Fajr", enabled: $enabledFajr, timeSensitive: $timeSensitiveFajr)
                prayerRow(name: "Dhuhr", enabled: $enabledDhuhr, timeSensitive: $timeSensitiveDhuhr)
                prayerRow(name: "Asr", enabled: $enabledAsr, timeSensitive: $timeSensitiveAsr)
                prayerRow(name: "Maghrib", enabled: $enabledMaghrib, timeSensitive: $timeSensitiveMaghrib)
                prayerRow(name: "Isha", enabled: $enabledIsha, timeSensitive: $timeSensitiveIsha)
            }
            
            Section(footer: Text("Disabling a prayer will stop all adhan audio and notifications for that specific time.\n\n'Time Sensitive' attempts to break through Focus modes. Requires a paid Apple Developer account to work reliably; on free accounts, this may have no effect or standard behavior.")) {
                // Info footer
            }
        }
        .navigationTitle("Notifications")
        .onChange(of: enabledFajr) { _ in viewModel.scheduleNotifications() }
        .onChange(of: enabledDhuhr) { _ in viewModel.scheduleNotifications() }
        .onChange(of: enabledAsr) { _ in viewModel.scheduleNotifications() }
        .onChange(of: enabledMaghrib) { _ in viewModel.scheduleNotifications() }
        .onChange(of: enabledIsha) { _ in viewModel.scheduleNotifications() }
        // Schedule on Time Sensitive change too, just in case
        .onChange(of: timeSensitiveFajr) { _ in viewModel.scheduleNotifications() }
        .onChange(of: timeSensitiveDhuhr) { _ in viewModel.scheduleNotifications() }
        .onChange(of: timeSensitiveAsr) { _ in viewModel.scheduleNotifications() }
        .onChange(of: timeSensitiveMaghrib) { _ in viewModel.scheduleNotifications() }
        .onChange(of: timeSensitiveIsha) { _ in viewModel.scheduleNotifications() }
    }
    
    private func prayerRow(name: String, enabled: Binding<Bool>, timeSensitive: Binding<Bool>) -> some View {
        VStack(alignment: .leading) {
            Toggle(name, isOn: enabled)
            
            if enabled.wrappedValue {
                Toggle("Time Sensitive", isOn: timeSensitive)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }
        }
        .padding(.vertical, 4)
    }
}
