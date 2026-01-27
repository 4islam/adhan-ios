import SwiftUI
import CoreLocation
import Combine

struct VisualizerView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @State private var showCalendar = false
    
    var body: some View {
        ZStack {
            BackgroundView(sunPos: viewModel.sunPosition, moonPos: viewModel.moonPosition)
            
            VStack {
                Text("Skylight")
                    .font(.system(.title, design: .serif))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                // Date Navigation
                DateControlView(
                    dateString: viewModel.currentDateString,
                    hijriString: viewModel.hijriDateString,
                    showCalendar: $showCalendar,
                    selectedDate: $viewModel.selectedDate,
                    onNext: { viewModel.goToNextDay() },
                    onPrev: { viewModel.goToPreviousDay() },
                    onJump: { date in viewModel.jumpToDate(date) },
                    isToday: viewModel.isToday,
                    onReturnToToday: { viewModel.jumpToDate(Date()) }
                )
                .padding(.bottom, 10)
                
                Spacer()
                
                // Celestial Arc Visualization
                ZStack {
                    // Horizon Line
                    Rectangle()
                        .fill(LinearGradient(colors: [.black.opacity(0.0), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                        .frame(height: 150)
                        .offset(y: 150)
                    
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 200))
                        path.addQuadCurve(to: CGPoint(x: 350, y: 200), control: CGPoint(x: 175, y: -50))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5]))
                    .foregroundColor(.white.opacity(0.2))
                    .frame(width: 350, height: 200)
                    
                    if let sun = viewModel.sunPosition {
                        CelestialBody(icon: "sun.max.fill", color: .orange, altitude: sun.altitude, label: "Sun")
                    }
                    
                    if let moon = viewModel.moonPosition {
                        CelestialBody(icon: "moon.fill", color: .gray, altitude: moon.altitude, label: "Moon")
                    }
                }
                .frame(height: 300)
                
                // Detailed Metrics
                VStack(spacing: 20) {
                    // Time Control Slider
                    VStack(spacing: 8) {
                        HStack {
                            Text("Time Travel")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text(timeString(from: viewModel.selectedDate))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.white)
                                .onTapGesture {
                                    viewModel.resetTime()
                                }
                        }
                        
                        Slider(value: Binding(get: {
                            let components = Calendar.current.dateComponents([.hour, .minute], from: viewModel.selectedDate)
                            return Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60.0
                        }, set: { newValue in
                            viewModel.setTime(hour: newValue)
                        }), in: 0...24)
                        .accentColor(.cyan)
                    }
                    .padding(.horizontal)
                    
                    // Anchor Controls
                    HStack(spacing: 12) {
                        AnchorButton(title: "None", isActive: viewModel.timeAnchor == .none) {
                            viewModel.setTimeAnchor(.none)
                        }
                        AnchorButton(title: "Sunrise", isActive: viewModel.timeAnchor == .sunrise) {
                            viewModel.setTimeAnchor(.sunrise)
                        }
                        AnchorButton(title: "Noon", isActive: viewModel.timeAnchor == .solarNoon) {
                            viewModel.setTimeAnchor(.solarNoon)
                        }
                        AnchorButton(title: "Sunset", isActive: viewModel.timeAnchor == .sunset) {
                            viewModel.setTimeAnchor(.sunset)
                        }
                    }
                    
                    // Sunrise/Sunset Times
                    HStack(spacing: 40) {
                        CelestialMetric(label: "Sunrise", value: viewModel.sunRise)
                        CelestialMetric(label: "Sunset", value: viewModel.sunSet)
                    }
                    
                    HStack(spacing: 40) {
                        if let sun = viewModel.sunPosition {
                            CelestialMetric(label: "Sun Altitude", value: String(format: "%.1f°", sun.altitude))
                        }
                        if let moon = viewModel.moonPosition {
                            CelestialMetric(label: "Moon Altitude", value: String(format: "%.1f°", moon.altitude))
                        }
                    }
                }
                .padding()
                
                Spacer()
            }
            
            if viewModel.isCalculating {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text("Calculating...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

struct CelestialBody: View {
    let icon: String
    let color: Color
    let altitude: Double
    let label: String
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
                .shadow(color: color.opacity(0.8), radius: 15)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
        }
        // Map altitude (-90 to 90) to visualization path
        // Simplified mapping for demo: 0 altitude = horizon (y=200), 90 altitude = zenith (y=0)
        // Adjust x loosely based on time/azimuth (not fully implemented in this simplified view)
        .offset(x: 0, y: CGFloat(-altitude * 2)) 
    }
}

struct CelestialMetric: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .foregroundColor(.white)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }
}

struct AnchorButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isActive ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isActive ? Color.white : Color.white.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }
}

extension VisualizerView {
    func timeString(from date: Date) -> String {
        return DashboardViewModel.timeFormatter.string(from: date)
    }
}

