import SwiftUI

struct FadeSettingsView: View {
    @AppStorage("fade_fajr_duration") private var fadeFajrDuration: Double = 5.0
    @AppStorage("fade_fajr_volume") private var fadeFajrVolume: Double = 0.0
    
    @AppStorage("fade_dhuhr_duration") private var fadeDhuhrDuration: Double = 5.0
    @AppStorage("fade_dhuhr_volume") private var fadeDhuhrVolume: Double = 0.0
    
    @AppStorage("fade_asr_duration") private var fadeAsrDuration: Double = 5.0
    @AppStorage("fade_asr_volume") private var fadeAsrVolume: Double = 0.0
    
    @AppStorage("fade_maghrib_duration") private var fadeMaghribDuration: Double = 5.0
    @AppStorage("fade_maghrib_volume") private var fadeMaghribVolume: Double = 0.0
    
    @AppStorage("fade_isha_duration") private var fadeIshaDuration: Double = 5.0
    @AppStorage("fade_isha_volume") private var fadeIshaVolume: Double = 0.0
    
    let prayers = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
    
    var body: some View {
        List {
            Section(header: Text("Configuration")) {
                Text("Customize how the Adhan starts for each prayer. You can start at a low volume and fade in over time.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(prayers, id: \.self) { prayer in
                NavigationLink(destination: FadeDetailView(prayer: prayer)) {
                    HStack {
                        Text(prayer)
                        Spacer()
                        Text(getDetailText(for: prayer))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Audio Fading")
    }
    
    func getDetailText(for prayer: String) -> String {
        // This is a bit verbose but safe for SwiftUI state
        let duration: Double
        let vol: Double
        
        switch prayer {
        case "Fajr": duration = fadeFajrDuration; vol = fadeFajrVolume
        case "Dhuhr": duration = fadeDhuhrDuration; vol = fadeDhuhrVolume
        case "Asr": duration = fadeAsrDuration; vol = fadeAsrVolume
        case "Maghrib": duration = fadeMaghribDuration; vol = fadeMaghribVolume
        case "Isha": duration = fadeIshaDuration; vol = fadeIshaVolume
        default: return ""
        }
        
        return String(format: "%.0fs Fade from %.0f%%", duration, vol * 100)
    }
}

struct FadeDetailView: View {
    let prayer: String
    
    // We bind dynamically to the underlying UserDefaults keys
    @AppStorage("fade_fajr_duration") private var fadeFajrDuration: Double = 5.0
    @AppStorage("fade_fajr_volume") private var fadeFajrVolume: Double = 0.0
    
    @AppStorage("fade_dhuhr_duration") private var fadeDhuhrDuration: Double = 5.0
    @AppStorage("fade_dhuhr_volume") private var fadeDhuhrVolume: Double = 0.0
    
    @AppStorage("fade_asr_duration") private var fadeAsrDuration: Double = 5.0
    @AppStorage("fade_asr_volume") private var fadeAsrVolume: Double = 0.0
    
    @AppStorage("fade_maghrib_duration") private var fadeMaghribDuration: Double = 5.0
    @AppStorage("fade_maghrib_volume") private var fadeMaghribVolume: Double = 0.0
    
    @AppStorage("fade_isha_duration") private var fadeIshaDuration: Double = 5.0
    @AppStorage("fade_isha_volume") private var fadeIshaVolume: Double = 0.0
    
    var body: some View {
        Form {
            Section(header: Text("Settings for \(prayer)")) {
                VStack(alignment: .leading) {
                    Text("Initial Volume: \(Int(volume * 100))%")
                    Slider(value: volumeBinding, in: 0.0...1.0, step: 0.1)
                }
                
                VStack(alignment: .leading) {
                    Text("Fade Duration: \(Int(duration)) seconds")
                    Stepper("Duration", value: durationBinding, in: 0...60, step: 1)
                }
            }
            
            Section {
                Button("Test Fading (\(prayer))") {
                    // Play test using these settings
                    // We must pass the PRAYER NAME to force the manager to look up these keys
                    AudioManager.shared.playAdhan(fileName: "adhan_regular", prayerName: prayer)
                }
                .foregroundColor(.blue)
                
                Button("Stop Audio") {
                    AudioManager.shared.stop()
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle(prayer)
    }
    
    // Dynamic bindings based on prayer string
    var durationBinding: Binding<Double> {
        switch prayer {
        case "Fajr": return $fadeFajrDuration
        case "Dhuhr": return $fadeDhuhrDuration
        case "Asr": return $fadeAsrDuration
        case "Maghrib": return $fadeMaghribDuration
        case "Isha": return $fadeIshaDuration
        default: return $fadeFajrDuration
        }
    }
    
    var volumeBinding: Binding<Double> {
        switch prayer {
        case "Fajr": return $fadeFajrVolume
        case "Dhuhr": return $fadeDhuhrVolume
        case "Asr": return $fadeAsrVolume
        case "Maghrib": return $fadeMaghribVolume
        case "Isha": return $fadeIshaVolume
        default: return $fadeFajrVolume
        }
    }
    
    var duration: Double { durationBinding.wrappedValue }
    var volume: Double { volumeBinding.wrappedValue }
}
