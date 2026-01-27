import SwiftUI

struct AstroSummaryPanel: View {
    let sunRise: String
    let solarNoon: String
    let sunSet: String
    let moonRise: String
    let moonSet: String
    
    @AppStorage("isAstroExpanded") private var isExpanded: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (Always Visible)
            Button(action: {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow.opacity(0.8))
                    Text("Astronomy")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    
                    if !isExpanded {
                        Spacer()
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "sunrise.fill")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                                Text(sunRise)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "sunset.fill")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                Text(sunSet)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.01)) // Tappable area
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: 16) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    // Row 1: Sun
                    HStack(spacing: 0) {
                        Spacer()
                        AstroItem(icon: "sunrise.fill", label: "Sunrise", time: sunRise, color: .yellow)
                        Spacer()
                        AstroItem(icon: "sun.max.fill", label: "Noon", time: solarNoon, color: .orange)
                        Spacer()
                        AstroItem(icon: "sunset.fill", label: "Sunset", time: sunSet, color: .yellow)
                        Spacer()
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    // Row 2: Moon
                    HStack(spacing: 0) {
                        Spacer()
                        AstroItem(icon: "moon.fill", label: "Moonrise", time: moonRise, color: .cyan)
                        Spacer()
                        AstroItem(icon: "moon.zzz.fill", label: "Moonset", time: moonSet, color: .gray)
                        Spacer()
                    }
                }
                .padding(.bottom, 20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                // Add a subtle shadow for better separation
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 20)
    }
}

struct AstroItem: View {
    let icon: String
    let label: String
    let time: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .textCase(.uppercase)
                
                Text(time)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
            }
        }
        .frame(minWidth: 80)
    }
}

// Simple Blur helper if not already defined
struct Blur: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemMaterial
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        // Mock Background
        LinearGradient(colors: [.indigo, .black], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            AstroSummaryPanel(
                sunRise: "6:22 AM",
                solarNoon: "12:30 PM",
                sunSet: "6:45 PM",
                moonRise: "8:00 PM",
                moonSet: "5:00 AM"
            )
            Spacer()
        }
    }
}
