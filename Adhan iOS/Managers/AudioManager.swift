import Foundation
import AVFoundation
import Combine

class AudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AudioManager()
    
    var player: AVAudioPlayer?
    @Published var isPlaying = false
    
    @Published var currentRoute: String = "Internal Speaker"
    
    override init() {
        super.init()
        setupRouteMonitoring()
    }
    
    private func setupRouteMonitoring() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
        updateCurrentRoute()
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        DispatchQueue.main.async {
            self.updateCurrentRoute()
        }
    }
    
    private func updateCurrentRoute() {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs
        if let output = outputs.first {
            currentRoute = output.portName
        }
    }
    
    func playAdhan(fileName: String? = nil, prayerName: String? = nil) {
        // Precedence: fileName > prayerName match > default
        var chosenFile = fileName ?? "adhan_regular"
        
        if fileName == nil, let prayer = prayerName {
            if prayer.lowercased() == "fajr" {
                chosenFile = "adhan_fajr"
            }
        }
        
        var fileURL: URL?
        
        // Try Bundle first for internal ones
        if let bundleURL = Bundle.main.url(forResource: chosenFile, withExtension: "mp3") {
            fileURL = bundleURL
        } else {
            // Try Documents directory for custom ones
            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let customURL = documentsURL.appendingPathComponent(chosenFile)
            if fileManager.fileExists(atPath: customURL.path) {
                fileURL = customURL
            }
        }
        
        guard let url = fileURL else { 
            let msg = "AudioManager: Failed to find audio file: \(chosenFile)"
            print(msg)
            LogManager.shared.log(msg)
            return 
        }
        
        do {
            let session = AVAudioSession.sharedInstance()
            
            // Apply Audio Output Setting
            let preferSpeaker = UserDefaults.standard.bool(forKey: "preferInternalSpeaker")
            
            if preferSpeaker {
                try session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker, .duckOthers])
            } else {
                // Allows Bluetooth/AirPlay to take lead if connected
                try session.setCategory(.playback, mode: .default, options: [.allowBluetoothA2DP, .allowAirPlay, .duckOthers])
            }
            
            try session.setActive(true)
            
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.play()
            isPlaying = true
            updateCurrentRoute()
            LogManager.shared.log("AudioManager: Playing \(chosenFile)")
        } catch {
            let msg = "AudioManager: Playback failed: \(error.localizedDescription)"
            print(msg)
            LogManager.shared.log(msg)
        }
    }
    
    func stop() {
        player?.stop()
        isPlaying = false
        deactivateSession()
    }
    
    private func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            let msg = "AudioManager: Failed to deactivate session: \(error.localizedDescription)"
            print(msg)
            LogManager.shared.log(msg)
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        deactivateSession()
    }
}
