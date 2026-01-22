//
//  Adhan_iOSApp.swift
//  Adhan iOS
//
//  Created by Naveed ul Islam on 2026-01-17.
//

import SwiftUI
import AVFoundation
import BackgroundTasks

@main
struct Adhan_iOSApp: App {
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var audioManager = AudioManager.shared
    
    // Background Task Identifier
    let backgroundTaskID = "ai.ntrust.adhan.refresh"
    
    init() {
        setupAudioSession()
        registerBackgroundTask()
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
    
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskID, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            handleAppRefresh(task: task)
        }
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh
        scheduleAppRefresh()
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        task.expirationHandler = {
            queue.cancelAllOperations()
        }
        
        let operation = BlockOperation {
            LogManager.shared.log("BGTask: Performing background refresh...")
            
            if let loc = LocationManager.shared.location {
                PrayerNotificationManager.shared.refillQueue(location: loc)
                LogManager.shared.log("BGTask: Queue Refill Initiated.")
                task.setTaskCompleted(success: true)
            } else {
                 LogManager.shared.log("BGTask: Failed - No cached location.")
                 task.setTaskCompleted(success: false)
            }
        }
        
        queue.addOperation(operation)
    }
    
    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskID)
        // Refresh 4 times a day (every 6 hours) roughly, or just daily.
        // User asked for "if user does not move for a few days". Daily is fine.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 60 * 60) // 12 hours
        
        do {
            try BGTaskScheduler.shared.submit(request)
            LogManager.shared.log("BGTask: Scheduled next refresh for 12h from now.")
        } catch {
            LogManager.shared.log("BGTask: Could not schedule app refresh: \(error)")
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
                        scheduleAppRefresh() // Schedule on exit
                    case .active:
                        LogManager.shared.log("Adhan_iOSApp: App became active")
                        notificationManager.checkAuthorizationStatus()
                    case .inactive:
                        LogManager.shared.log("Adhan_iOSApp: App became inactive")
                    @unknown default:
                        LogManager.shared.log("Adhan_iOSApp: Unknown scene phase: \(newPhase)")
                    }
                }
                .onOpenURL { url in
                    LogManager.shared.log("Adhan_iOSApp: Open URL: \(url)")
                    if url.scheme == "adhan" && url.host == "play" {
                        AudioManager.shared.playAdhan(fileName: "adhan_regular")
                    } else if url.absoluteString.contains("stop") {
                         AudioManager.shared.stop()
                    }
                }
        }
    }
}
