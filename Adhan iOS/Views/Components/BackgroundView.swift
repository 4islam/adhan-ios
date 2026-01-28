import SwiftUI

struct BackgroundView: View {
    var sunPos: AstroPosition?
    var moonPos: AstroPosition?
    var showSharpOrbs: Bool = false
    var horizonHeight: Double = 0.65 // Default 65% down. SkyView uses 0.5
    
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
                CelestialOrb(color: getSunColor(alt: sun.altitude), size: 150, blur: showSharpOrbs ? 0 : 50)
                    .position(mapCoordinates(alt: sun.altitude, az: sun.azimuth))
            }


            
            // Dynamic Moon
            if let moon = moonPos, moon.altitude > -10 {
                // If we have phase info (0.0 - 1.0), pick SF Symbol
                let phaseName = getMoonPhaseSymbol(phase: moon.phase ?? 0.5)
                
                // Equal size: 100pt (same as Sun)
                if showSharpOrbs {
                    // Sharp Visualization Mode
                    
                    // Calculate rotation to face Sun
                    var rotationAngle: Angle = .zero
                    if let sun = sunPos, let sunPt = getScreenPoint(alt: sun.altitude, az: sun.azimuth),
                       let moonPt = getScreenPoint(alt: moon.altitude, az: moon.azimuth) {
                        
                        let deltaY = sunPt.y - moonPt.y
                        let deltaX = sunPt.x - moonPt.x
                        // Standard angle
                        var angle = atan2(deltaY, deltaX) * 180 / .pi
                        
                        // SFSymbol "waxing" crescent default: Lit side is RIGHT.
                        // We want RIGHT side to point to Sun.
                        // atan2 gives angle to Sun. 0 deg is Right.
                        // So rotation = angle.
                        
                        // However, Waning crescent default: Lit side is LEFT.
                        // We need to know if it is waxing or waning to offset.
                    }
                }
                
                if showSharpOrbs {
                    Image(systemName: phaseName)
                        .resizable()
                        .symbolRenderingMode(.palette) 
                        .foregroundStyle(.white.opacity(0.9), .white.opacity(0.1)) 
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 150, height: 150)
                        .shadow(color: .white.opacity(0.6), radius: 15, x: 0, y: 0)
                        .position(mapCoordinates(alt: moon.altitude, az: moon.azimuth))
                } else {
                    CelestialOrb(color: .white.opacity(0.8), size: 150, blur: 30)
                        .position(mapCoordinates(alt: moon.altitude, az: moon.azimuth))
                }
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
                    .frame(height: UIScreen.main.bounds.height * (1.0 - horizonHeight + 0.05)) // Dynamic based on horizon
                
                Rectangle()

                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                    .shadow(color: .white.opacity(0.2), radius: 5)
                
                Spacer()
                    .frame(height: UIScreen.main.bounds.height * (1.0 - horizonHeight))
            }
            .ignoresSafeArea()

        }
        .onAppear {
            animateGradient = true
        }
    }
    
    // Map Altitude/Azimuth to Screen Coordinates
    func mapCoordinates(alt: Double, az: Double) -> CGPoint {
        return getScreenPoint(alt: alt, az: az) ?? CGPoint.zero
    }

    func getScreenPoint(alt: Double, az: Double) -> CGPoint? {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        // Horizon (0 deg)
        let horizonY = self.horizonHeight
        
        // Altitude range: we map sunset altitude (-0.833) to EXACTLY horizonY
        // And zenith (90) to 0.1
        // Below (-20) to 0.8
        
        let sunriseAlt = -0.833
        let effectiveAlt = alt - sunriseAlt // 0 at sunrise/sunset
        
        var yRatio: Double
        if effectiveAlt >= 0 {
            // Above horizon: map 0 to 90.833 -> horizonY to 0.1
            yRatio = horizonY - (effectiveAlt / (90.0 - sunriseAlt)) * (horizonY - 0.1)
        } else {
            // Below horizon: map 0 to -19.167 -> horizonY to 0.8
            yRatio = horizonY + (abs(effectiveAlt) / (20.0 + sunriseAlt)) * (0.8 - horizonY)
        }
        
        let y = CGFloat(yRatio) * screenHeight
        
        // Azimuth mapping (Spatial Feel)
        // We face SOUTH (180).
        // Show a 240-degree panorama: from 180-120=60 (East-ish) to 180+120=300 (West-ish)
        // This ensures the sun/moon travel from Left to Right across most of the screen.
        let fov: Double = 240.0
        let centerAz: Double = 180.0
        let leftAz = centerAz - (fov / 2.0)
        
        // Normalize azimuth to be relative to leftAz
        var relativeAz = (az - leftAz).truncatingRemainder(dividingBy: 360)
        if relativeAz < 0 { relativeAz += 360 }
        
        let xRatio = relativeAz / fov
        
        // Only return if within FOV (or close to it for smooth entry/exit)
        // We allow slightly off-screen to avoid artifacts
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
    
    // SF Symbol Mapping for Moon Phase
    func getMoonPhaseSymbol(phase: Double) -> String {
        // phase is 0.0 (New) -> 1.0 (New)
        // SF Symbols: moonphase.new.moon, .waxing.crescent, .first.quarter, .waxing.gibbous, .full.moon, ...
        
        switch phase {
        case 0.0..<0.06: return "moonphase.new.moon"
        case 0.06..<0.24: return "moonphase.waxing.crescent"
        case 0.24..<0.26: return "moonphase.first.quarter"
        case 0.26..<0.44: return "moonphase.waxing.gibbous"
        case 0.44..<0.56: return "moonphase.full.moon"
        case 0.56..<0.74: return "moonphase.waning.gibbous"
        case 0.74..<0.76: return "moonphase.last.quarter"
        case 0.76..<0.94: return "moonphase.waning.crescent"
        default: return "moonphase.new.moon"
        }
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
