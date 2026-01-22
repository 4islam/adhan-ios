import SwiftUI

struct FadeSettingsView: View {
    @AppStorage("fade_fajr_duration") private var fadeFajrDuration: Double = 5.0
    @AppStorage("fade_fajr_volume") private var fadeFajrVolume: Double = 0.0
    
    @AppStorage("fade_dhuhr_duration") private var fadeDhuhrDuration: Double = 0.0
    @AppStorage("fade_dhuhr_volume") private var fadeDhuhrVolume: Double = 0.0
    
    @AppStorage("fade_asr_duration") private var fadeAsrDuration: Double = 0.0
    @AppStorage("fade_asr_volume") private var fadeAsrVolume: Double = 0.0
    
    @AppStorage("fade_maghrib_duration") private var fadeMaghribDuration: Double = 0.0
    @AppStorage("fade_maghrib_volume") private var fadeMaghribVolume: Double = 0.0
    
    @AppStorage("fade_isha_duration") private var fadeIshaDuration: Double = 0.0
    @AppStorage("fade_isha_volume") private var fadeIshaVolume: Double = 0.0
    
    @AppStorage("fade_tahajjud_duration") private var fadeTahajjudDuration: Double = 5.0
    @AppStorage("fade_tahajjud_volume") private var fadeTahajjudVolume: Double = 0.0
    
    @AppStorage("max_volume_fajr") private var maxVolFajr: Double = 1.0
    @AppStorage("max_volume_dhuhr") private var maxVolDhuhr: Double = 1.0
    @AppStorage("max_volume_asr") private var maxVolAsr: Double = 1.0
    @AppStorage("max_volume_maghrib") private var maxVolMaghrib: Double = 1.0
    @AppStorage("max_volume_isha") private var maxVolIsha: Double = 1.0
    
    let prayers = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha", "Tahajjud"]
    
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
        case "Tahajjud": duration = fadeTahajjudDuration; vol = fadeTahajjudVolume
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
    
    @AppStorage("fade_dhuhr_duration") private var fadeDhuhrDuration: Double = 0.0
    @AppStorage("fade_dhuhr_volume") private var fadeDhuhrVolume: Double = 0.0
    
    @AppStorage("fade_asr_duration") private var fadeAsrDuration: Double = 0.0
    @AppStorage("fade_asr_volume") private var fadeAsrVolume: Double = 0.0
    
    @AppStorage("fade_maghrib_duration") private var fadeMaghribDuration: Double = 0.0
    @AppStorage("fade_maghrib_volume") private var fadeMaghribVolume: Double = 0.0
    
    @AppStorage("fade_isha_duration") private var fadeIshaDuration: Double = 0.0
    @AppStorage("fade_isha_volume") private var fadeIshaVolume: Double = 0.0
    
    @AppStorage("max_volume_fajr") private var maxVolFajr: Double = 1.0
    @AppStorage("max_volume_dhuhr") private var maxVolDhuhr: Double = 1.0
    @AppStorage("max_volume_asr") private var maxVolAsr: Double = 1.0
    @AppStorage("max_volume_maghrib") private var maxVolMaghrib: Double = 1.0
    @AppStorage("max_volume_isha") private var maxVolIsha: Double = 1.0
    
    @AppStorage("fade_tahajjud_duration") private var fadeTahajjudDuration: Double = 5.0
    @AppStorage("fade_tahajjud_volume") private var fadeTahajjudVolume: Double = 0.0
    @AppStorage("max_volume_tahajjud") private var maxVolTahajjud: Double = 1.0
    
    var body: some View {
        Form {
            Section(header: Text("Volume Settings for \(prayer)")) {
                VStack(alignment: .leading) {
                    Text("Max Volume (System): \(Int(maxVolume * 100))%")
                    Slider(value: maxVolumeBinding, in: 0.0...1.0, step: 0.05)
                }
                Text("This overrides the phone's volume when \(prayer) Adhan starts.")
                    .font(.caption).foregroundColor(.secondary)
            }
            
            Section(header: Text("Fading Settings")) {
                VStack(alignment: .leading) {
                    Text("Start Volume (Fade-In): \(Int(volume * 100))%")
                    Slider(value: volumeBinding, in: 0.0...1.0, step: 0.05)
                }
                
                VStack(alignment: .leading) {
                    Text("Fade Duration: \(Int(duration)) seconds")
                    Stepper("Duration", value: durationBinding, in: 0...60, step: 1)
                }
            }
            
            Section {
                Button("Test Fading (\(prayer))") {
                    // Play test using these settings
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
    var maxVolumeBinding: Binding<Double> {
        switch prayer {
        case "Fajr": return $maxVolFajr
        case "Dhuhr": return $maxVolDhuhr
        case "Asr": return $maxVolAsr
        case "Maghrib": return $maxVolMaghrib
        case "Isha": return $maxVolIsha
        case "Tahajjud": return $maxVolTahajjud
        default: return $maxVolFajr
        }
    }
    
    var durationBinding: Binding<Double> {
        switch prayer {
        case "Fajr": return $fadeFajrDuration
        case "Dhuhr": return $fadeDhuhrDuration
        case "Asr": return $fadeAsrDuration
        case "Maghrib": return $fadeMaghribDuration
        case "Isha": return $fadeIshaDuration
        case "Tahajjud": return $fadeTahajjudDuration
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
        case "Tahajjud": return $fadeTahajjudVolume
        default: return $fadeFajrVolume
        }
    }
    
    var duration: Double { durationBinding.wrappedValue }
    var volume: Double { volumeBinding.wrappedValue }
    var maxVolume: Double { maxVolumeBinding.wrappedValue }
}
