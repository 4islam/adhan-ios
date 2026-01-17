import SwiftUI

struct BackgroundView: View {
    var sunPos: AstroPosition?
    var moonPos: AstroPosition?
    
    @State private var animateGradient = false
    
    var body: some View {
        ZStack {
            // Deep Space Gradient
            LinearGradient(colors: [
                Color(red: 0.05, green: 0.05, blue: 0.2), // Midnight Blue
                Color(red: 0.1, green: 0.05, blue: 0.25), // Deep Purple
                Color.black
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
            
            // Ambient Nebula
            Circle()
                .fill(Color.purple.opacity(0.1))
                .blur(radius: 80)
                .frame(width: 400, height: 400)
                .offset(x: animateGradient ? -120 : 120, y: animateGradient ? -60 : 60)
                .animation(.easeInOut(duration: 15).repeatForever(autoreverses: true), value: animateGradient)
            
            // Atmospheric Glow near Horizon
            if let sun = sunPos {
                let glowColor = getGlowColor(alt: sun.altitude)
                let glowOpacity = getGlowOpacity(alt: sun.altitude)
                
                Rectangle()
                    .fill(
                        LinearGradient(colors: [glowColor.opacity(glowOpacity), .clear], 
                                       startPoint: .bottom, 
                                       endPoint: .top)
                    )
                    .frame(height: 300)
                    .offset(y: UIScreen.main.bounds.height * 0.2) // Positioned around horizon
            }
            
            // Dynamic Sun
            if let sun = sunPos, sun.altitude > -18 { // Down to astronomical twilight
                CelestialOrb(color: getSunColor(alt: sun.altitude), size: 100, blur: 50)
                    .position(mapCoordinates(alt: sun.altitude, az: sun.azimuth))
            }
            
            // Dynamic Moon
            if let moon = moonPos, moon.altitude > -10 {
                CelestialOrb(color: .white.opacity(0.8), size: 60, blur: 30)
                    .position(mapCoordinates(alt: moon.altitude, az: moon.azimuth))
            }
            
            // Horizon Line
            VStack {
                Spacer()
                Rectangle()
                    .fill(
                        LinearGradient(colors: [.black.opacity(0.5), .clear], 
                                       startPoint: .bottom, 
                                       endPoint: .top)
                    )
                    .frame(height: UIScreen.main.bounds.height * 0.4)
                
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                    .shadow(color: .white.opacity(0.2), radius: 5)
                
                Spacer()
                    .frame(height: UIScreen.main.bounds.height * 0.35)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            animateGradient = true
        }
    }
    
    // Map Altitude/Azimuth to Screen Coordinates
    func mapCoordinates(alt: Double, az: Double) -> CGPoint {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        // Horizon (0 deg) is at 65% height
        let horizonY = 0.65
        
        // Altitude range: we map -20 (below horizon) to 90 (zenith)
        // Zenith (90) -> Y = 0.1
        // Horizon (0) -> Y = horizonY (0.65)
        // Below (-20) -> Y = 0.8
        
        var yRatio: Double
        if alt >= 0 {
            // Above horizon: map 0...90 to horizonY...0.1
            yRatio = horizonY - (alt / 90.0) * (horizonY - 0.1)
        } else {
            // Below horizon: map 0...-20 to horizonY...0.8
            yRatio = horizonY + (abs(alt) / 20.0) * (0.8 - horizonY)
        }
        
        let y = CGFloat(yRatio) * screenHeight
        
        // Azimuth: Loop around 0-360
        let xRatio = (az.truncatingRemainder(dividingBy: 360)) / 360.0
        let x = CGFloat(xRatio) * screenWidth
        
        return CGPoint(x: x, y: y)
    }
    
    // Helpers for dynamic styling
    func getGlowColor(alt: Double) -> Color {
        if alt > 5 { return .blue }
        if alt > -2 { return .orange } // sunset glow
        if alt > -6 { return .purple } // twilight
        return .indigo
    }
    
    func getGlowOpacity(alt: Double) -> Double {
        if alt > 20 { return 0.2 }
        if alt > -12 { return 0.4 }
        return 0.1
    }
    
    func getSunColor(alt: Double) -> Color {
        if alt > 10 { return .yellow }
        if alt > 0 { return .orange }
        return .red
    }
}

struct CelestialOrb: View {
    let color: Color
    let size: CGFloat
    let blur: CGFloat
    
    var body: some View {
        Circle()
            .fill(color.opacity(0.6))
            .blur(radius: blur)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .fill(color)
                    .frame(width: size * 0.3, height: size * 0.3)
                    .blur(radius: 10)
            )
    }
}

#Preview {
    BackgroundView()
}
