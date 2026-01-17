import SwiftUI

struct VisualizerView: View {
    @EnvironmentObject var locationManager: LocationManager
    @State private var sunPos: AstroPosition?
    @State private var moonPos: AstroPosition?
    
    // Timer to update position every minute
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            BackgroundView(sunPos: sunPos, moonPos: moonPos)
            
            VStack {
                Text("Skylight")
                    .font(.system(.title, design: .serif))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
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
                    
                    if let sun = sunPos {
                        CelestialBody(icon: "sun.max.fill", color: .orange, altitude: sun.altitude, label: "Sun")
                    }
                    
                    if let moon = moonPos {
                        CelestialBody(icon: "moon.fill", color: .gray, altitude: moon.altitude, label: "Moon")
                    }
                }
                .frame(height: 300)
                
                // Detailed Metrics
                HStack(spacing: 40) {
                    if let sun = sunPos {
                        CelestialMetric(label: "Sun Altitude", value: String(format: "%.1f°", sun.altitude))
                        CelestialMetric(label: "Sun Azimuth", value: String(format: "%.1f°", sun.azimuth))
                    }
                }
                .padding()
                
                HStack(spacing: 40) {
                    if let moon = moonPos {
                        CelestialMetric(label: "Moon Altitude", value: String(format: "%.1f°", moon.altitude))
                        CelestialMetric(label: "Moon Azimuth", value: String(format: "%.1f°", moon.azimuth))
                    }
                }
                .padding()
                
                Spacer()
            }
        }
        .onAppear {
            updatePositions()
        }
        .onReceive(timer) { _ in
            updatePositions()
        }
        .onChange(of: locationManager.location) {
            updatePositions()
        }
    }
    
    func updatePositions() {
        guard let loc = locationManager.location else { return }
        let date = Date()
        sunPos = Astrology.getSunPosition(date: date, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
        moonPos = Astrology.getMoonPosition(date: date, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
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
