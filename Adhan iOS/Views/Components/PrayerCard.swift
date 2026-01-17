import SwiftUI

struct PrayerCard: View {
    let name: String
    let time: String
    let isNext: Bool
    let type: DashboardItem.ItemType
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if type == .event {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundColor(.orange.opacity(0.8))
                    } else if type == .combinedPrayer {
                        Image(systemName: "link")
                            .font(.caption2)
                            .foregroundColor(.cyan)
                    } else if type == .sunnah {
                        Image(systemName: "moon.fill")
                            .font(.caption2)
                            .foregroundColor(.cyan.opacity(0.8))
                    }
                    
                    Text(name)
                        .font(.system(size: type == .event ? 16 : 18, 
                                      weight: isNext ? .bold : (type == .event ? .medium : .semibold), 
                                      design: type == .event ? .serif : .rounded))
                        .foregroundColor(isNext ? .black : (type == .event ? .white.opacity(0.7) : .white))
                }
                
                if type == .sunnah {
                    Text("Sunnah (Optional)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(isNext ? .black.opacity(0.7) : .cyan.opacity(0.7))
                }
            }
            
            Spacer()
            
            Text(time)
                .font(.system(size: type == .event ? 18 : 20, 
                              weight: isNext ? .heavy : .regular, 
                              design: .monospaced))
                .foregroundColor(isNext ? .black : (type == .event ? .white.opacity(0.7) : .white))
        }
        .padding(.horizontal, 20) // More inner padding
        .padding(.vertical, type == .event ? 12 : 16) // Smaller vertical for events
        .background {
            if isNext {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.white.opacity(0.5), radius: 10, x: 0, y: 0)
            } else if type == .event {
                RoundedRectangle(cornerRadius: 16)
                    // Event: Very subtle glass or even clearer
                    .fill(.ultraThinMaterial.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            } else if type == .sunnah {
                // Sunnah/Tahajjud
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.cyan.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
            } else {
                // Regular Prayer
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 5)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isNext)
    }
}
