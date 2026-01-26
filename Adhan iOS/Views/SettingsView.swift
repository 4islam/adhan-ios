import SwiftUI

struct SettingsView: View {
    @AppStorage("timeFormat") private var timeFormat: Int = PrayerTimes.TimeFormat.time12.rawValue
    
    // Testing Links
    @State private var showingTestAlert = false
    @EnvironmentObject var viewModel: DashboardViewModel
    
    var body: some View {
        Form {
            // MARK: - Main Sections
            Section {
                NavigationLink(destination: AudioSettingsView()) {
                    Label("Sounds & Audio", systemImage: "speaker.wave.2.fill")
                }
                
                NavigationLink(destination: NotificationSettingsView()) {
                    Label("Notification Toggles", systemImage: "bell.badge.fill")
                }
                
                NavigationLink(destination: FeatureSettingsView()) {
                    Label("Tahajjud & Features", systemImage: "moon.stars.fill")
                }
                
                NavigationLink(destination: CalculationSettingsView()) {
                    Label("Calculation Methods", systemImage: "function")
                }
            } header: {
                Text("Configuration")
            }
            
            // MARK: - General
            Section(header: Text("General")) {
                Picker("Time Format", selection: $timeFormat) {
                    Text("24 Hour").tag(0)
                    Text("12 Hour").tag(1)
                    Text("12 Hour (No Suffix)").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: timeFormat) { _ in
                    viewModel.refreshSettings()
                }
                
                Button(action: {
                    let _ = URL(string: "shortcuts://create-shortcut?name=Play%20Adhan&action=PlayAdhanIntent")!
                     if let shortcutsURL = URL(string: "shortcuts://") {
                        UIApplication.shared.open(shortcutsURL)
                    }
                }) {
                    Label("Siri Shortcuts", systemImage: "mic.fill")
                }
            }
            
            // MARK: - Diagnostics
            Section(header: Text("Diagnostics")) {
                NavigationLink(destination: TestingView(showingTestAlert: $showingTestAlert)) {
                    Label("Testing Tools", systemImage: "wrench.and.screwdriver.fill")
                }
                
                NavigationLink(destination: LogsView()) {
                    Label("App Logs", systemImage: "list.bullet.rectangle.portrait.fill")
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Adhan Scheduled", isPresented: $showingTestAlert) {
            Button("OK", role:.cancel) { }
        } message: {
            Text("A test Adhan has been scheduled for 2 minutes from now. Please LOCK your screen immediately.")
        }
    }
}

// Extracted Testing View to keep main file clean
struct TestingView: View {
    @Binding var showingTestAlert: Bool
    @EnvironmentObject var viewModel: DashboardViewModel
    @State private var testStatus: String = ""
    
    var body: some View {
        Form {
            Section(header: Text("Audio Tests")) {
                Button("Play Adhan (3 min)") {
                    AudioManager.shared.playAdhan(fileName: "adhan_regular")
                }
                Button("Play Chunk 1 (Test Path)") {
                    let result = PrayerNotificationManager.shared.resolveSoundPath(for: "1r")
                    if let url = result.absoluteUrl {
                        AudioManager.shared.playAdhan(fileName: "1r.caf") 
                        // Note: AudioManager re-resolves, but at least we confirmed URL exists first.
                        // Ideally we pass URL directly to AudioManager, but its API expects String.
                    } else {
                        LogManager.shared.log("TEST FAILURE: Could not resolve 1r.caf path.")
                    }
                }
                Button("Stop Audio") {
                    AudioManager.shared.stop()
                }.foregroundColor(.red)
            }
            
            Section(header: Text("Notification Tests")) {
                Button("Test Background Adhan (2 min)") {
                    NotificationManager.shared.scheduleTestNotification(seconds: 120)
                    showingTestAlert = true
                }
                Button("Test Adhan Chain (10s)") {
                   PrayerNotificationManager.shared.testChainNow()
                }
                Button("Test Default Sound (10s)") {
                    NotificationManager.shared.scheduleDefaultSoundTest(seconds: 10)
                }
            }
            
            Section {
                Button("Reset & Reschedule All") {
                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        viewModel.updateTime()
                        LogManager.shared.log("Manual Reset: Notifications rescheduled.")
                    }
                }.foregroundColor(.red)
                
                Button("Run Unit Tests") {
                    testStatus = "Running..."
                    LogManager.shared.log("Running Manual Tests...")
                    ManualTests.shared.log = { message in 
                        LogManager.shared.log(message)
                        DispatchQueue.main.async {
                            // Keep status short - show last important line
                            if message.contains("✅") || message.contains("❌") || message.contains("COMPLETED") {
                                testStatus = message
                            }
                        }
                    }
                    // Run slightly async to allow UI update
                    DispatchQueue.global(qos: .userInitiated).async {
                        ManualTests.shared.runAllTests()
                    }
                }.foregroundColor(.blue)
                
                if !testStatus.isEmpty {
                    Text(testStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Testing Tools")
    }
}

struct LogsView: View {
    @ObservedObject var logManager = LogManager.shared
    
    var body: some View {
        List {
            if logManager.logs.isEmpty {
                Text("No logs recorded.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(logManager.logs) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(log.message)
                            .font(.body)
                            .foregroundColor(.primary)
                        Text(log.formattedTimestamp)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("App Logs")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: {
                        let text = logManager.logs.map { "\($0.formattedTimestamp): \($0.message)" }.joined(separator: "\n")
                        UIPasteboard.general.string = text
                        // Optional: Show a temporary confirmation or rely on standard UI feedback
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                    
                    Button("Audit") {
                        NotificationManager.shared.logPendingNotifications()
                    }
                    Button("Clear") {
                        logManager.clearLogs()
                    }
                }
            }
        }
    }
}
