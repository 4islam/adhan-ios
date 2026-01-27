import SwiftUI

// MARK: - Calculation Settings
struct CalculationSettingsView: View {
    @AppStorage("calcMethod") private var calcMethod: Int = PrayerTimes.CalculationMethod.ahmadiyya.rawValue
    @AppStorage("asrForHanafi") private var asrForHanafi: Bool = false
    @AppStorage("highLatMethod") private var highLatMethod: Int = PrayerTimes.HighLatMethod.angleBased.rawValue
    
    @AppStorage("fajrOffset") private var fajrOffset: Double = 0
    @AppStorage("maghribOffset") private var maghribOffset: Double = 0
    @AppStorage("ishaOffset") private var ishaOffset: Double = 0
    
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
            
            Section(header: Text("High Latitude Rule")) {
                Picker("Rule", selection: $highLatMethod) {
                    Text("None").tag(0)
                    Text("Mid Night").tag(1)
                    Text("One Seventh").tag(2)
                    Text("Angle Based").tag(3)
                }
            }
            
            Section(header: Text("Manual Offsets (Minutes)")) {
                Stepper("Fajr: \(Int(fajrOffset))", value: $fajrOffset, in: -60...60)
                Stepper("Maghrib: \(Int(maghribOffset))", value: $maghribOffset, in: -60...60)
                Stepper("Isha: \(Int(ishaOffset))", value: $ishaOffset, in: -60...60)
            }
        }
        .navigationTitle("Calculation")
    }
}

// MARK: - Audio Settings
struct AudioSettingsView: View {
    @ObservedObject var audioManager = AudioManager.shared
    @AppStorage("preferInternalSpeaker") private var preferInternalSpeaker: Bool = false
    @AppStorage("adhanVolume") private var adhanVolume: Double = 1.0
    
    // Per-prayer Adhan Selection
    @AppStorage("adhan_fajr") private var adhanFajr: String = "adhan_fajr"
    @AppStorage("adhan_dhuhr") private var adhanDhuhr: String = "adhan_regular"
    @AppStorage("adhan_asr") private var adhanAsr: String = "adhan_regular"
    @AppStorage("adhan_maghrib") private var adhanMaghrib: String = "adhan_regular"
    @AppStorage("adhan_isha") private var adhanIsha: String = "adhan_regular"
    
    let adhanOptions = ["adhan_regular", "adhan_fajr"]
    
    @State private var showingDocumentPicker = false
    @State private var selectingForPrayer = ""
    @EnvironmentObject var viewModel: DashboardViewModel
    
    var body: some View {
        Form {
            Section(header: Text("Master Volume")) {
                VStack {
                    HStack {
                        Image(systemName: "speaker.fill")
                        Slider(value: Binding(
                            get: { self.adhanVolume },
                            set: { newValue in self.adhanVolume = newValue }
                        ), in: 0.0...1.0)
                        Image(systemName: "speaker.wave.3.fill")
                    }
                    Text("Max App Volume: \(Int(adhanVolume * 100))%")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Output Device")) {
                HStack {
                    Text("Current Output")
                    Spacer()
                    Text(audioManager.currentRoute).foregroundColor(.secondary).font(.caption)
                }
                HStack {
                    Text("Select AirPlay/BT")
                    Spacer()
                    AudioPicker().frame(width: 44, height: 44)
                }
                Toggle("Always Play on Phone Speaker", isOn: $preferInternalSpeaker)
            }
            
            Section(header: Text("Adhan Sounds")) {
                soundPicker(prayer: "Fajr", selection: $adhanFajr)
                soundPicker(prayer: "Dhuhr", selection: $adhanDhuhr)
                soundPicker(prayer: "Asr", selection: $adhanAsr)
                soundPicker(prayer: "Maghrib", selection: $adhanMaghrib)
                soundPicker(prayer: "Isha", selection: $adhanIsha)
                
                NavigationLink(destination: FadeSettingsView()) {
                     Text("Advanced Fading & Per-Prayer Volume")
                }
            }
        }
        .navigationTitle("Audio & Sounds")
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(isPresented: $showingDocumentPicker) { url in
                viewModel.importCustomAdhan(url: url, for: selectingForPrayer)
            }
        }
    }
    
    @ViewBuilder
    func soundPicker(prayer: String, selection: Binding<String>) -> some View {
        HStack {
            Picker(prayer, selection: selection) {
                ForEach(adhanOptions, id: \.self) { opt in
                    Text(opt.replacingOccurrences(of: "adhan_", with: "").capitalized).tag(opt)
                }
                if !adhanOptions.contains(selection.wrappedValue) {
                    Text("Custom (\(selection.wrappedValue))").tag(selection.wrappedValue)
                }
            }
            Button(action: {
                selectingForPrayer = prayer
                showingDocumentPicker = true
            }) {
                Image(systemName: "folder").foregroundColor(.cyan)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
    }
}

// MARK: - Advanced Feature Settings
struct FeatureSettingsView: View {
    @AppStorage("tahajjudEnabled") private var tahajjudEnabled: Bool = true
    @AppStorage("tahajjudOffset") private var tahajjudOffset: Double = 60
    @AppStorage("adhan_tahajjud") private var adhanTahajjud: String = "silent_vibrate"
    
    @AppStorage("combineThreshold") private var combineThreshold: Double = 70
    @AppStorage("asrMaghribGapThreshold") private var asrMaghribGapThreshold: Double = 90
    @AppStorage("combineShortNightEnabled") private var combineShortNightEnabled: Bool = true
    @AppStorage("shortNightDuration") private var shortNightDuration: Double = 9.0
    
    let alertOptions = ["system_default", "silent_vibrate", "adhan_fajr", "adhan_regular"]
    @State private var showingDocumentPicker = false
    @State private var selectingForPrayer = ""
    @EnvironmentObject var viewModel: DashboardViewModel
    
    func formatOption(_ opt: String) -> String {
        switch opt {
        case "system_default": return "System Sound (Beep)"
        case "silent_vibrate": return "Vibrate Only (Silent)"
        default: return opt.replacingOccurrences(of: "adhan_", with: "").capitalized
        }
    }
    
    var body: some View {
        Form {
            Section(header: Text("Tahajjud Alarm")) {
                Toggle("Enable Tahajjud", isOn: $tahajjudEnabled)
                if tahajjudEnabled {
                    Stepper("Offset: \(Int(tahajjudOffset))m before Fajr", value: $tahajjudOffset, in: 10...120, step: 5)
                    
                    Divider()
                    
                    Picker("Alarm Sound", selection: $adhanTahajjud) {
                        ForEach(alertOptions, id: \.self) { opt in
                             Text(formatOption(opt)).tag(opt)
                        }
                        if !alertOptions.contains(adhanTahajjud) {
                            Text("Custom (\(adhanTahajjud))").tag(adhanTahajjud)
                        }
                    }
                    Button("Select custom file for Tahajjud...") {
                        selectingForPrayer = "Tahajjud"
                        showingDocumentPicker = true
                    }.font(.caption).foregroundColor(.cyan)
                }
            }
            
            Section(header: Text("Prayer Combining (Smart)")) {
                Stepper("Standard Gap Threshold: \(Int(combineThreshold))m", value: $combineThreshold, in: 0...120, step: 5)
                Text("Dhuhr/Asr or Maghrib/Isha combine if their own gap is small.")
                    .font(.caption).foregroundColor(.secondary)
                
                Stepper("Asr-Maghrib Gap: \(Int(asrMaghribGapThreshold))m", value: $asrMaghribGapThreshold, in: 0...120, step: 5)
                
                Toggle("Combine if Short Night", isOn: $combineShortNightEnabled)
                if combineShortNightEnabled {
                    Stepper("Night Threshold: \(String(format: "%.1f", shortNightDuration))h", value: $shortNightDuration, in: 1...12, step: 0.5)
                }
                if combineShortNightEnabled {
                    Stepper("Night Threshold: \(String(format: "%.1f", shortNightDuration))h", value: $shortNightDuration, in: 1...12, step: 0.5)
                }
            }
            
            Section(header: Text("Dynamic Island")) {
                Toggle("Show Next Prayer", isOn: Binding(
                    get: { LiveActivityManager.shared.isEnabled },
                    set: { LiveActivityManager.shared.isEnabled = $0 }
                ))
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(isPresented: $showingDocumentPicker) { url in
                viewModel.importCustomAdhan(url: url, for: selectingForPrayer)
            }
        }
    }
}
