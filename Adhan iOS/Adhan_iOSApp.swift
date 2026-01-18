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
    
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(notificationManager)
                .environmentObject(audioManager)
                .onAppear {
                    LogManager.shared.log("Adhan_iOSApp: App launched (onAppear)")
                    // Request permissions on launch or defer to onboarding
                    locationManager.requestPermission()
                    notificationManager.requestAuthorization()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .background:
                        LogManager.shared.log("Adhan_iOSApp: App entered background")
                    case .active:
                        LogManager.shared.log("Adhan_iOSApp: App became active")
                        notificationManager.checkAuthorizationStatus()
                    case .inactive:
                        LogManager.shared.log("Adhan_iOSApp: App became inactive")
                    @unknown default:
                        LogManager.shared.log("Adhan_iOSApp: Unknown scene phase: \(newPhase)")
                    }
                }
        }
    }
}
