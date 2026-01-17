import SwiftUI

struct AstroSummaryPanel: View {
    let sunRise: String
    let solarNoon: String
    let sunSet: String
    let moonRise: String
    let moonSet: String
    
    var body: some View {
        HStack(spacing: 12) {
            AstroPill(icon: "sun.max.fill", time: sunRise, color: .yellow)
            AstroPill(icon: "sun.min.fill", time: solarNoon, color: .orange)
            AstroPill(icon: "sun.max.fill", time: sunSet, color: .yellow)
            AstroPill(icon: "moon.fill", time: moonRise, color: .cyan)
            AstroPill(icon: "moon.fill", time: moonSet, color: .cyan)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .padding(.horizontal)
    }
}

struct AstroPill: View {
    let icon: String
    let time: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
            
            Text(time)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
        }
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
        Color.indigo.ignoresSafeArea()
        AstroSummaryPanel(
            sunRise: "12:59 am",
            solarNoon: "5:10 am",
            sunSet: "9:22 am",
            moonRise: "11:59 pm",
            moonSet: "6:28 am"
        )
    }
}
