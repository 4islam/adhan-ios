import SwiftUI

struct SettingsView: View {
    @AppStorage("calcMethod") private var calcMethod: Int = PrayerTimes.CalculationMethod.ahmadiyya.rawValue
    @AppStorage("asrForHanafi") private var asrForHanafi: Bool = false
    @AppStorage("highLatMethod") private var highLatMethod: Int = PrayerTimes.HighLatMethod.angleBased.rawValue
    @AppStorage("timeFormat") private var timeFormat: Int = PrayerTimes.TimeFormat.time12.rawValue
    
    // User manual offsets
    @AppStorage("fajrOffset") private var fajrOffset: Double = 0
    @AppStorage("maghribOffset") private var maghribOffset: Double = 0
    @AppStorage("ishaOffset") private var ishaOffset: Double = 0
    
    // Phase 2 Settings
    @AppStorage("tahajjudEnabled") private var tahajjudEnabled: Bool = true
    @AppStorage("tahajjudOffset") private var tahajjudOffset: Double = 60
    @AppStorage("combineThreshold") private var combineThreshold: Double = 70
    @AppStorage("asrMaghribGapThreshold") private var asrMaghribGapThreshold: Double = 90
    @AppStorage("combineShortNightEnabled") private var combineShortNightEnabled: Bool = true
    @AppStorage("shortNightDuration") private var shortNightDuration: Double = 9.0
    @AppStorage("preferInternalSpeaker") private var preferInternalSpeaker: Bool = false
    @AppStorage("adhanVolume") private var adhanVolume: Double = 1.0
    
    @ObservedObject var audioManager = AudioManager.shared
    
    // Per-prayer Adhan Selection
    @AppStorage("adhan_fajr") private var adhanFajr: String = "adhan_fajr"
    @AppStorage("adhan_dhuhr") private var adhanDhuhr: String = "adhan_regular"
    @AppStorage("adhan_asr") private var adhanAsr: String = "adhan_regular"
    @AppStorage("adhan_maghrib") private var adhanMaghrib: String = "adhan_regular"
    @AppStorage("adhan_isha") private var adhanIsha: String = "adhan_regular"
    
    let adhanOptions = ["adhan_regular", "adhan_fajr"] // Dynamically could be improved but sufficient for now
    
    @State private var showingDocumentPicker = false
    @State private var showingTestAlert = false
    @State private var selectingForPrayer = ""
    @EnvironmentObject var viewModel: DashboardViewModel // Ensure access to import logic if needed
    
    var body: some View {
        Form {
            Section(header: Text("Calculation Method")) {
                Picker("Method", selection: $calcMethod) {
                    Text("Jafari").tag(0)
                    Text("Karachi").tag(1)
                    Text("ISNA").tag(2)
                    Text("MWL").tag(3)
                    Text("Makkah").tag(4)
                    Text("Egypt").tag(5)
                    Text("Tehran").tag(7)
                    Text("Ahmadiyya").tag(8)
                }
            }
            
            Section(header: Text("Asr Juristic Method")) {
                Toggle("Hanafi (Later Asr)", isOn: $asrForHanafi)
            }
            
            Section(header: Text("Tahajjud Alarm")) {
                Toggle("Enable Tahajjud", isOn: $tahajjudEnabled)
                if tahajjudEnabled {
                    Stepper("Offset: \(Int(tahajjudOffset))m before Fajr", value: $tahajjudOffset, in: 10...120, step: 5)
                }
            }
            
            Section(header: Text("Prayer Combining")) {
                Stepper("Standard Gap Threshold: \(Int(combineThreshold))m", value: $combineThreshold, in: 0...120, step: 5)
                Text("Dhuhr/Asr or Maghrib/Isha combine if their own gap is small.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Stepper("Asr-Maghrib Gap: \(Int(asrMaghribGapThreshold))m", value: $asrMaghribGapThreshold, in: 0...120, step: 5)
                Text("Combine Dhuhr/Asr if Asr is too close to Maghrib.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider().padding(.vertical, 4)
                
                Toggle("Combine if Short Night", isOn: $combineShortNightEnabled)
                if combineShortNightEnabled {
                    Stepper("Night Threshold: \(String(format: "%.1f", shortNightDuration))h", value: $shortNightDuration, in: 1...12, step: 0.5)
                    Text("If time between Isha and Fajr is less than this, Maghrib & Isha will combine.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Audio Device & Route")) {
                HStack {
                    Text("Current Output")
                    Spacer()
                    Text(audioManager.currentRoute)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                
                HStack {
                    Text("Select Output (AirPlay/BT)")
                    Spacer()
                    AudioPicker()
                        .frame(width: 44, height: 44)
                }
                
                Toggle("Always Play on Speaker", isOn: $preferInternalSpeaker)
                Text("If enabled, the Adhan will attempt to bypass Bluetooth and use the phone's built-in speakers.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("Adhan Volume")) {
                VStack {
                    HStack {
                        Image(systemName: "speaker.fill")
                        Slider(value: Binding(
                            get: { self.adhanVolume },
                            set: { newValue in
                                self.adhanVolume = newValue
                                // Real-time preview if audio is playing? Not critical, but user might want it.
                            }
                        ), in: 0.0...1.0)
                        Image(systemName: "speaker.wave.3.fill")
                    }
                    Text("Volume: \(Int(adhanVolume * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text("This sets the maximum volume for the Adhan within the app. It will play relative to your phone's system volume.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("Adhan Sounds")) {
                Picker("Fajr", selection: $adhanFajr) {
                    ForEach(adhanOptions, id: \.self) { opt in
                        Text(opt.replacingOccurrences(of: "adhan_", with: "").capitalized).tag(opt)
                    }
                    if !adhanOptions.contains(adhanFajr) {
                        Text("Custom (\(adhanFajr))").tag(adhanFajr)
                    }
                }
                Button("Select from Files...") {
                    selectingForPrayer = "Fajr"
                    showingDocumentPicker = true
                }.font(.caption).foregroundColor(.cyan)
                
                Picker("Dhuhr", selection: $adhanDhuhr) {
                    ForEach(adhanOptions, id: \.self) { opt in
                        Text(opt.replacingOccurrences(of: "adhan_", with: "").capitalized).tag(opt)
                    }
                    if !adhanOptions.contains(adhanDhuhr) {
                        Text("Custom (\(adhanDhuhr))").tag(adhanDhuhr)
                    }
                }
                Button("Select from Files...") {
                    selectingForPrayer = "Dhuhr"
                    showingDocumentPicker = true
                }.font(.caption).foregroundColor(.cyan)
                
                Picker("Asr", selection: $adhanAsr) {
                    ForEach(adhanOptions, id: \.self) { opt in
                        Text(opt.replacingOccurrences(of: "adhan_", with: "").capitalized).tag(opt)
                    }
                    if !adhanOptions.contains(adhanAsr) {
                        Text("Custom (\(adhanAsr))").tag(adhanAsr)
                    }
                }
                Button("Select from Files...") {
                    selectingForPrayer = "Asr"
                    showingDocumentPicker = true
                }.font(.caption).foregroundColor(.cyan)
                
                Picker("Maghrib", selection: $adhanMaghrib) {
                    ForEach(adhanOptions, id: \.self) { opt in
                        Text(opt.replacingOccurrences(of: "adhan_", with: "").capitalized).tag(opt)
                    }
                    if !adhanOptions.contains(adhanMaghrib) {
                        Text("Custom (\(adhanMaghrib))").tag(adhanMaghrib)
                    }
                }
                Button("Select from Files...") {
                    selectingForPrayer = "Maghrib"
                    showingDocumentPicker = true
                }.font(.caption).foregroundColor(.cyan)
                
                Picker("Isha", selection: $adhanIsha) {
                    ForEach(adhanOptions, id: \.self) { opt in
                        Text(opt.replacingOccurrences(of: "adhan_", with: "").capitalized).tag(opt)
                    }
                    if !adhanOptions.contains(adhanIsha) {
                        Text("Custom (\(adhanIsha))").tag(adhanIsha)
                    }
                }
                Button("Select from Files...") {
                    selectingForPrayer = "Isha"
                    showingDocumentPicker = true
                }.font(.caption).foregroundColor(.cyan)
                
                NavigationLink(destination: FadeSettingsView()) {
                     Text("Configure Fading & Volume")
                }
            }
            
            Section(header: Text("High Latitude Rule")) {
                Picker("Rule", selection: $highLatMethod) {
                    Text("None").tag(0)
                    Text("Mid Night").tag(1)
                    Text("One Seventh").tag(2)
                    Text("Angle Based").tag(3)
                }
            }
            
            Section(header: Text("Time Format")) {
                Picker("Time Format", selection: $timeFormat) {
                    Text("24 Hour").tag(0)
                    Text("12 Hour").tag(1)
                    Text("12 Hour (No Suffix)").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section(header: Text("Manual Offsets (Minutes)")) {
                Stepper("Fajr: \(Int(fajrOffset))", value: $fajrOffset, in: -60...60)
                Stepper("Maghrib: \(Int(maghribOffset))", value: $maghribOffset, in: -60...60)
                Stepper("Isha: \(Int(ishaOffset))", value: $ishaOffset, in: -60...60)
            }
            
            Section(header: Text("Testing")) {
                Button("Play Adhan (3 min)") {
                    AudioManager.shared.playAdhan(fileName: "adhan_regular")
                }
                .foregroundColor(.blue)
                
                Button("Play Chunk 1 (Verify Audio)") {
                    AudioManager.shared.playAdhan(fileName: "adhan_regular_01.caf")
                }
                .foregroundColor(.cyan)
                
                Button("Stop Audio") {
                    AudioManager.shared.stop()
                }
                .foregroundColor(.orange)
                
                Divider()
                
                Button("Test Background Adhan (2 min)") {
                    // Schedule a fake adhan 2 minutes from now using TimeInterval trigger
                    NotificationManager.shared.scheduleTestNotification(seconds: 120)
                    showingTestAlert = true
                }
                .foregroundColor(.red)
                
                Button("Test Adhan Chain (10s)") {
                   PrayerNotificationManager.shared.testChainNow()
                }
                .foregroundColor(.purple)
                
                Button("Test Default Sound (10s)") {
                    NotificationManager.shared.scheduleDefaultSoundTest(seconds: 10)
                }
                .foregroundColor(.gray)
                
                Button("Reset & Reschedule All") {
                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                    // Small delay to ensure clear completes efficiently before rewrite (though API is async, usually fine)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        viewModel.updateTime() // This triggers scheduleNotifications internally
                        LogManager.shared.log("Manual Reset: Notifications rescheduled.")
                    }
                }
                .foregroundColor(.red)
                
                NavigationLink(destination: LogsView()) {
                    Text("View Error Logs")
                }
            }
            
            Section(header: Text("Siri & Shortcuts")) {
                Button(action: {
                    let url = URL(string: "shortcuts://create-shortcut?name=Play%20Adhan&action=PlayAdhanIntent")!
                    // Note: Direct deep linking to create a shortcut is restricted, 
                    // usually we just guide them to the Shortcuts app or use `SiriTipView` (UIKit).
                    // For now, valid URL to open Shortcuts App:
                    if let shortcutsURL = URL(string: "shortcuts://") {
                        UIApplication.shared.open(shortcutsURL)
                    }
                }) {
                    Label("Open Shortcuts App", systemImage: "arrow.up.forward.app")
                }
                Text("In Shortcuts, search for 'Adhan iOS' to create automations like 'Play Adhan when charging'.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .alert("Adhan Scheduled", isPresented: $showingTestAlert) {
            Button("OK", role:.cancel) { }
        } message: {
            Text("A test Adhan has been scheduled for 2 minutes from now.\n\nPlease LOCK your screen immediately to test background playback.")
        }

        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(isPresented: $showingDocumentPicker) { url in
                viewModel.importCustomAdhan(url: url, for: selectingForPrayer)
            }
        }
        .navigationTitle("Settings")
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
        .navigationTitle("Error Logs")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
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
