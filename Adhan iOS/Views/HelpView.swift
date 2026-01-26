import SwiftUI

struct HelpView: View {
    var body: some View {
        Form {
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
                        stepRow(num: 5, text: "Turn OFF 'Ask Before Running' so it runs automatically.")
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
                 Text("If Adhan audio is silent, check:\n1. Silent Mode switch on valid devices settings\n2. 'Time Sensitive' toggle in Notifications\n3. Notification permissions in iOS Settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Help & FAQ")
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
