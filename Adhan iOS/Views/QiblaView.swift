import SwiftUI
import CoreLocation

struct QiblaView: View {
    @EnvironmentObject var locationManager: LocationManager
    
    // Makkah coordinates
    let makkahLat = 21.4225
    let makkahLng = 39.8262
    
    var body: some View {
        VStack {
            Text("Qibla Compass")
                .font(.title)
                .padding()
            
            if let heading = locationManager.heading {
                ZStack {
                    // Compass Background
                    Circle()
                        .stroke(Color.gray, lineWidth: 2)
                        .frame(width: 300, height: 300)
                    
                    Text("N")
                        .position(x: 150, y: 10)
                    
                    // Qibla Indicator
                    if let location = locationManager.location {
                        let bearing = calculateQiblaDirection(currentLoc: location.coordinate)
                        // The compass rotates so North matches true north.
                        // We want to show Qibla relative to North.
                        // Heading: 0 = North.
                        // If Play heading is 0, arrow points up.
                        // If heading is 90 (East), arrow rotates -90.
                        // We rotate the whole compass card by -heading?
                        
                        // Strategy: 
                        // ZStack rotates by -heading.trueHeading
                        // Arrow inside ZStack is fixed at Qibla Bearing angle.
                        
                        ZStack {
                            // Dial
                            ForEach(0..<12) { i in
                                Rectangle()
                                    .frame(width: 2, height: 10)
                                    .offset(y: -140)
                                    .rotationEffect(.degrees(Double(i) * 30))
                            }
                            
                            // Qibla Arrow
                            Image(systemName: "location.north.fill")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.green)
                                .rotationEffect(.degrees(bearing))
                            
                            // System Heading Arrow (North)
                            // Image(systemName: "arrow.up")
                            //    .foregroundColor(.red)
                        }
                        .rotationEffect(.degrees(-heading.trueHeading))
                        .animation(.easeInOut, value: heading.trueHeading)
                        
                        Text("Qibla: \(Int(bearing))°")
                            .padding(.top, 180)
                    } else {
                        Text("Waiting for location...")
                    }
                }
                .frame(width: 300, height: 300)
            } else {
                Text("Calibrating or Missing Permissions...")
            }
        }
        .onAppear {
            locationManager.startUpdating()
            locationManager.startHeadingUpdates()
        }
        .onDisappear {
            // We don't stop location (might be needed by dashboard) but definitely stop heading
            locationManager.stopHeadingUpdates()
        }
    }
    
    func calculateQiblaDirection(currentLoc: CLLocationCoordinate2D) -> Double {
        let phiK = makkahLat * .pi / 180.0
        let lambdaK = makkahLng * .pi / 180.0
        let phi = currentLoc.latitude * .pi / 180.0
        let lambda = currentLoc.longitude * .pi / 180.0
        
        // Formula for Great Circle Bearing
        let y = sin(lambdaK - lambda) * cos(phiK)
        let x = cos(phi) * sin(phiK) - sin(phi) * cos(phiK) * cos(lambdaK - lambda)
        let bearingRad = atan2(y, x)
        
        let bearingDeg = bearingRad * 180.0 / .pi
        return (bearingDeg + 360.0).truncatingRemainder(dividingBy: 360.0)
    }
}
