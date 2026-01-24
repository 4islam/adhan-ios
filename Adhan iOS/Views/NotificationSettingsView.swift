import SwiftUI

struct NotificationSettingsView: View {
    @AppStorage("notification_enabled_Fajr") private var enabledFajr = true
    @AppStorage("notification_enabled_Dhuhr") private var enabledDhuhr = true
    @AppStorage("notification_enabled_Asr") private var enabledAsr = true
    @AppStorage("notification_enabled_Maghrib") private var enabledMaghrib = true
    @AppStorage("notification_enabled_Isha") private var enabledIsha = true
    
    @EnvironmentObject var viewModel: DashboardViewModel
    
    var body: some View {
        Form {
            Section(header: Text("Prayer Notifications")) {
                Toggle("Fajr", isOn: $enabledFajr)
                Toggle("Dhuhr", isOn: $enabledDhuhr)
                Toggle("Asr", isOn: $enabledAsr)
                Toggle("Maghrib", isOn: $enabledMaghrib)
                Toggle("Isha", isOn: $enabledIsha)
            }
            
            Section(footer: Text("Disabling a prayer will stop all adhan audio and notifications for that specific time.")) {
                // Info footer
            }
        }
        .navigationTitle("Notifications")
        .onChange(of: enabledFajr) { _ in viewModel.scheduleNotifications() }
        .onChange(of: enabledDhuhr) { _ in viewModel.scheduleNotifications() }
        .onChange(of: enabledAsr) { _ in viewModel.scheduleNotifications() }
        .onChange(of: enabledMaghrib) { _ in viewModel.scheduleNotifications() }
        .onChange(of: enabledIsha) { _ in viewModel.scheduleNotifications() }
    }
}
