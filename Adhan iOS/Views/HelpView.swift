import SwiftUI

struct HelpView: View {
    var body: some View {
        Form {
            // MARK: - Features
            Section(header: Text("Features Overview")) {
                DisclosureGroup("Home Screen") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("**Prayer Times**: Displays accurate prayer times for your location.")
                        Text("**Next Prayer**: The upcoming prayer is highlighted with a countdown.")
                        Text("**Date Navigation**: Swipe left/right or tap the arrow buttons to change dates. Use the calendar icon to jump to a specific date.")
                        Text("**Islamic Date**: Displays the current Hijri date.")
                    }
                    .font(.caption)
                    .padding(.vertical, 4)
                }
                
                DisclosureGroup("Sky View (Visualizer)") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("**Solar Path**: Visualizes the sun's position relative to the horizon.")
                        Text("**Time Travel**: Drag the slider to simulate the sun/moon position at different times of the day.")
                        Text("**Reset Time**: Tap the **Time** text (e.g., '12:45 PM') to instantly reset to the current real time.")
                        Text("**Anchors**: Tap 'Sunrise', 'Noon', or 'Sunset' to lock the view to that event while changing dates.")
                    }
                    .font(.caption)
                    .padding(.vertical, 4)
                }
                
                DisclosureGroup("Qibla & Map") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("**Qibla**: Points towards the Kaaba. Requires compass calibration.")
                        Text("**Map**: Shows your current location and the direction to Mecca on a map.")
                    }
                    .font(.caption)
                    .padding(.vertical, 4)
                }
            }
            
            // MARK: - Configuration
            Section(header: Text("Configuration")) {
                DisclosureGroup("Calculation Methods") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Different authorities use different angles for Fajr and Isha.")
                        Text("Go to **Settings > Calculation Methods** to choose the standard that matches your local mosque (e.g., ISNA, MWL, Umm al-Qura).")
                    }
                    .font(.caption)
                    .padding(.vertical, 4)
                }
                
                DisclosureGroup("Notifications") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("You can customize notifications for each prayer.")
                        Text("**Adhan**: Plays the full call to prayer.")
                        Text("**Beep**: Plays a short alert sound.")
                        Text("**Silent**: Only shows a banner.")
                        Text("**Pre-Notification**: Reminds you *before* the prayer time (e.g., 15 mins before Maghrib).")
                    }
                    .font(.caption)
                    .padding(.vertical, 4)
                }
            }
            
            // MARK: - Audio
            Section(header: Text("Audio & AirPlay")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Using AirPlay / HomePod")
                        .font(.headline)
                    
                    Text("Due to iOS privacy restrictions, apps cannot automatically switch audio output to external speakers (like HomePods) from the background.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Solution: Use Shortcuts")
                        .font(.headline)
                        .padding(.top, 4)
                    
                    Text("You can automate this using the **Shortcuts** app:")
                        .font(.caption)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        stepRow(num: 1, text: "Open Shortcuts app > Automation tab")
                        stepRow(num: 2, text: "Create Personal Automation > Time of Day (e.g. Fajr time)")
                        stepRow(num: 3, text: "Add Action: 'Set Playback Destination' -> Select your HomePod/Speaker")
                        stepRow(num: 4, text: "Add Action: 'Play Adhan' (from Adhan iOS app)")
                        stepRow(num: 5, text: "Turn OFF 'Ask Before Running'.")
                    }
                    .padding(.vertical, 4)
                    
                    Button(action: {
                        if let url = URL(string: "shortcuts://") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.up.forward.app")
                            Text("Open Shortcuts App")
                        }
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section(header: Text("Troubleshooting")) {
                 Text("If Adhan audio is silent, check:\n1. Silent Mode switch on device side\n2. 'Time Sensitive' enabled in Notifications\n3. Notification permissions in iOS Settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Help & Manual")
    }
    
    private func stepRow(num: Int, text: String) -> some View {
        HStack(alignment: .top) {
            Text("\(num).")
                .bold()
                .frame(width: 20, alignment: .leading)
            Text(text)
        }
        .font(.caption)
    }
}

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
             HelpView()
        }
    }
}
