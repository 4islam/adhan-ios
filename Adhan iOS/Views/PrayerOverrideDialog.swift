import SwiftUI
import AVKit

struct PrayerOverrideDialog: View {
    let prayer: String
    let weekday: Int
    let onSave: (PrayerTimes.PrayerOverride) -> Void
    let onCancel: () -> Void
    let onApplyToAllDays: (PrayerTimes.PrayerOverride) -> Void
    let onApplyToAllPrayersToday: (PrayerTimes.PrayerOverride) -> Void
    
    @State private var override: PrayerTimes.PrayerOverride
    @ObservedObject var audioManager = AudioManager.shared
    
    init(prayer: String, weekday: Int, currentOverride: PrayerTimes.PrayerOverride?, onSave: @escaping (PrayerTimes.PrayerOverride) -> Void, onCancel: @escaping () -> Void, onApplyToAllDays: @escaping (PrayerTimes.PrayerOverride) -> Void, onApplyToAllPrayersToday: @escaping (PrayerTimes.PrayerOverride) -> Void) {
        self.prayer = prayer
        self.weekday = weekday
        self.onSave = onSave
        self.onCancel = onCancel
        self.onApplyToAllDays = onApplyToAllDays
        self.onApplyToAllPrayersToday = onApplyToAllPrayersToday
        _override = State(initialValue: currentOverride ?? .default())
    }
    
    private var weekdayName: String {
        let formatter = DateFormatter()
        return formatter.weekdaySymbols[weekday - 1]
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
                .onTapGesture { onCancel() }
            
            VStack(spacing: 20) {
                Text("\(prayer) on \(weekdayName)")
                    .font(.title2)
                    .bold()
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 15) {
                    Toggle("Enable Notification", isOn: $override.isEnabled)
                        .padding(.horizontal)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Audio Output")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(audioManager.currentRoute)
                                .foregroundColor(.primary)
                            Spacer()
                            AudioPicker()
                                .frame(width: 30, height: 30)
                        }
                        .padding(10)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(20)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Override Volume", isOn: $override.volumeOverrideEnabled)
                        
                        if override.volumeOverrideEnabled {
                            Text("Volume: \(Int(override.volume * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Slider(value: $override.volume, in: 0...1.0)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Override Fade", isOn: $override.fadeOverrideEnabled)
                        
                        if override.fadeOverrideEnabled {
                            Text("Fade Duration: \(Int(override.fadeDuration))s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Slider(value: $override.fadeDuration, in: 0...60, step: 1)
                        }
                    }
                    .padding(.horizontal)
                }
                
                VStack(spacing: 10) {
                    Button(action: { onApplyToAllDays(override) }) {
                        Text("Apply to All Days")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(25)
                            .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.blue, lineWidth: 1))
                    }
                    
                    Button(action: { onApplyToAllPrayersToday(override) }) {
                        Text("Apply to All Prayers today")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(25)
                            .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.blue, lineWidth: 1))
                    }
                }
                .padding(.horizontal)
                
                HStack(spacing: 40) {
                    Button("Cancel") { onCancel() }
                        .foregroundColor(.secondary)
                    
                    Button("Save") { onSave(override) }
                        .bold()
                }
                .padding(.bottom)
            }
            .frame(maxWidth: 350)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(30)
            .shadow(radius: 20)
        }
    }
}
