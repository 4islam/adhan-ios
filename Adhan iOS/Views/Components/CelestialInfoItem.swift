import SwiftUI

struct CelestialInfoItem: View {
    let icon: String
    let label: String
    let time: String
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.cyan)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
            Text(time)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}
