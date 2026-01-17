//
//  Adhan_iOSApp.swift
//  Adhan iOS
//
//  Created by Naveed ul Islam on 2026-01-17.
//

import SwiftUI
import AVFoundation

@main
struct Adhan_iOSApp: App {
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var audioManager = AudioManager.shared
    
    init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        // Configure AVAudioSession for background audio
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(notificationManager)
                .environmentObject(audioManager)
                .onAppear {
                    // Request permissions on launch or defer to onboarding
                    locationManager.requestPermission()
                    notificationManager.requestAuthorization()
                }
        }
    }
}
