import Foundation

public struct AstroPosition {
    public let altitude: Double // in degrees
    public let azimuth: Double  // in degrees
}

/// Simplified astronomical calculations for Sun/Moon position.
/// Base logic for a beautiful horizon visualizer.
public class Astrology {
    
    /// Accurate Sun altitude calculation.
    /// Based on NOAA's Solar Calculation equations.
    public static func getSunPosition(date: Date, lat: Double, lng: Double) -> AstroPosition {
        let rad = Double.pi / 180.0
        let deg = 180.0 / Double.pi
        
        // 1. Julian Date
        // JS: (date.getTime() / 86400000) + 2440587.5
        // Swift: date.timeIntervalSince1970 / 86400.0 + 2440587.5
        // Note: JS getTime() is ms since 1970. 86400000 ms per day.
        // Swift timeIntervalSince1970 is seconds. 86400 sec per day.
        let julianDate = (date.timeIntervalSince1970 / 86400.0) + 2440587.5
        let d = julianDate - 2451545.0
        
        // 2. Solar coordinates
        // d is used as scalar
        
        // JS: const L = (280.460 + 0.9856474 * d) % 360;
        let L = fmod(280.460 + 0.9856474 * d, 360.0)
        
        // JS: const g = (357.528 + 0.9856003 * d) % 360;
        let g = fmod(357.528 + 0.9856003 * d, 360.0)
        
        // JS: const lambda = (L + 1.915 * Math.sin(g * rad) + 0.020 * Math.sin(2 * g * rad)) % 360;
        let lambda = fmod(L + 1.915 * sin(g * rad) + 0.020 * sin(2 * g * rad), 360.0)
        
        // JS: const epsilon = (23.439 - 0.0000004 * d) % 360;
        let epsilon = fmod(23.439 - 0.0000004 * d, 360.0)
        
        // 3. Right Ascension / Declination
        // JS: const alpha = Math.atan2(Math.cos(epsilon * rad) * Math.sin(lambda * rad), Math.cos(lambda * rad)) * deg;
        let alpha = atan2(cos(epsilon * rad) * sin(lambda * rad), cos(lambda * rad)) * deg
        
        // JS: const delta = Math.asin(Math.sin(epsilon * rad) * Math.sin(lambda * rad)) * deg;
        let delta = asin(sin(epsilon * rad) * sin(lambda * rad)) * deg
        
        // 4. Local Sidereal Time
        // JS: const gmst = (18.697374558 + 24.06570982441908 * d) % 24;
        let gmst = fmod(18.697374558 + 24.06570982441908 * d, 24.0)
        
        // JS: const lst = (gmst + lng / 15 + 24) % 24;
        let lst = fmod(gmst + lng / 15 + 24, 24.0)
        
        // 5. Hour Angle
        // JS: let ha = (lst * 15 - alpha); // in degrees
        var ha = (lst * 15 - alpha)
        
        // JS: while (ha < -180) ha += 360; while (ha > 180) ha -= 360;
        while ha < -180 { ha += 360 }
        while ha > 180 { ha -= 360 }
        
        // 6. Altitude
        let phi = lat * rad
        let deltaRad = delta * rad
        let haRad = ha * rad
        
        let sinAlt = sin(phi) * sin(deltaRad) + cos(phi) * cos(deltaRad) * cos(haRad)
        let altitude = asin(sinAlt) * deg
        
        // 7. Azimuth
        // JS: const denom = Math.cos(phi) * Math.cos(Math.asin(Math.max(-1, Math.min(1, sinAlt))));
        let val = max(-1, min(1, sinAlt))
        let denom = cos(phi) * cos(asin(val))
        
        var azimuth: Double = 0
        if abs(denom) > 0.0001 {
            let cosAz = (sin(deltaRad) - sin(phi) * sinAlt) / denom
            azimuth = acos(max(-1, min(1, cosAz))) * deg
        }
        
        if sin(haRad) > 0 {
            azimuth = 360 - azimuth
        }
        
        return AstroPosition(altitude: altitude, azimuth: azimuth)
    }
    
    public static func getMoonPosition(date: Date, lat: Double, lng: Double) -> AstroPosition {
        let rad = Double.pi / 180.0
        let deg = 180.0 / Double.pi
        
        let julianDate = (date.timeIntervalSince1970 / 86400.0) + 2440587.5
        let d = julianDate - 2451545.0
        
        // Simplified orbital elements for the Moon
        let L = fmod(218.316 + 13.176396 * d, 360.0) // Mean longitude
        let M = fmod(134.963 + 13.064993 * d, 360.0) // Mean anomaly
        let F = fmod(93.272 + 13.229350 * d, 360.0)  // Mean distance from node
        
        let lambda = fmod(L + 6.289 * sin(M * rad), 360.0) // Ecliptic longitude
        let beta = 5.128 * sin(F * rad)               // Ecliptic latitude
        let epsilon = 23.439 * rad                    // Obliquity
        
        // Right Ascension / Declination
        let alpha = atan2(sin(lambda * rad) * cos(epsilon) - tan(beta * rad) * sin(epsilon), cos(lambda * rad)) * deg
        let delta = asin(sin(beta * rad) * cos(epsilon) + cos(beta * rad) * sin(epsilon) * sin(lambda * rad)) * deg
        
        // Local Sidereal Time
        let gmst = fmod(18.697374558 + 24.06570982441908 * d, 24.0)
        let lst = fmod(gmst + lng / 15 + 24, 24.0)
        
        // Hour Angle
        var ha = (lst * 15 - alpha)
        while ha < -180 { ha += 360 }
        while ha > 180 { ha -= 360 }
        
        // Altitude
        let phi = lat * rad
        let deltaRad = delta * rad
        let haRad = ha * rad
        
        let sinAlt = sin(phi) * sin(deltaRad) + cos(phi) * cos(deltaRad) * cos(haRad)
        let altitude = asin(max(-1, min(1, sinAlt))) * deg
        
        // Azimuth
        // JS: const denom = Math.cos(phi) * Math.cos(Math.asin(Math.max(-1, Math.min(1, sinAlt))));
        let val = max(-1, min(1, sinAlt))
        let denom = cos(phi) * cos(asin(val))
        
        var azimuth: Double = 0
        if abs(denom) > 0.0001 {
            let cosAz = (sin(deltaRad) - sin(phi) * sinAlt) / denom
            azimuth = acos(max(-1, min(1, cosAz))) * deg
        }
        
        if sin(haRad) > 0 {
            azimuth = 360 - azimuth
        }
        
        return AstroPosition(altitude: altitude, azimuth: azimuth)
    }
    
    /// Calculates Moonset time for a given day.
    /// Uses sampling to find when altitude crosses 0.
    public static func getMoonset(date: Date, lat: Double, lng: Double) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        let startOfDay = calendar.startOfDay(for: date)
        
        // Sample every hour to find transition
        for i in 0..<24 {
            let d1 = startOfDay.addingTimeInterval(Double(i) * 3600.0)
            let d2 = startOfDay.addingTimeInterval(Double(i + 1) * 3600.0)
            
            let pos1 = getMoonPosition(date: d1, lat: lat, lng: lng)
            let pos2 = getMoonPosition(date: d2, lat: lat, lng: lng)
            
            // Moonset: going from positive altitude to negative
            if pos1.altitude > 0 && pos2.altitude <= 0 {
                let fraction = pos1.altitude / (pos1.altitude - pos2.altitude)
                return d1.addingTimeInterval(fraction * 3600.0)
            }
        }
        return nil
    }
    
    /// Calculates Moonrise time for a given day.
    public static func getMoonrise(date: Date, lat: Double, lng: Double) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        let startOfDay = calendar.startOfDay(for: date)
        
        for i in 0..<24 {
            let d1 = startOfDay.addingTimeInterval(Double(i) * 3600.0)
            let d2 = startOfDay.addingTimeInterval(Double(i + 1) * 3600.0)
            
            let pos1 = getMoonPosition(date: d1, lat: lat, lng: lng)
            let pos2 = getMoonPosition(date: d2, lat: lat, lng: lng)
            
            // Moonrise: going from negative altitude to positive
            if pos1.altitude <= 0 && pos2.altitude > 0 {
                let fraction = -pos1.altitude / (pos2.altitude - pos1.altitude)
                return d1.addingTimeInterval(fraction * 3600.0)
            }
        }
        return nil
    }
}
