import SwiftUI
import CoreLocation
import UserNotifications

struct PermissionView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        List {
            Section(header: Text("Required Permissions")) {
                PermissionRow(
                    title: "Location Services",
                    description: "Needed for accurate prayer times and Qibla direction.",
                    icon: "location.fill",
                    isAuthorized: viewModel.isLocationAuthorized,
                    action: { openSettings() }
                )
                
                PermissionRow(
                    title: "Notifications",
                    description: "Needed to alert you for prayer times and Adhan.",
                    icon: "bell.fill",
                    isAuthorized: viewModel.isNotificationsAuthorized,
                    action: { openSettings() }
                )
            }
            
            Section {
                Text("Background location access (Always) is recommended for reliable background adhan notifications.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Permissions")
        .onAppear {
            viewModel.checkPermissions()
        }
    }
    
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let icon: String
    let isAuthorized: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isAuthorized ? .green : .red)
                .frame(width: 40)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isAuthorized {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button(action: action) {
                    Text("Enable")
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
