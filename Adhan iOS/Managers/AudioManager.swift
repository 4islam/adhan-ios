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
        let routeDesc = AVAudioSession.sharedInstance().currentRoute
        LogManager.shared.log("AudioManager: Route change detected. Route: \(routeDesc). Reason: \(String(describing: notification.userInfo?[AVAudioSessionRouteChangeReasonKey]))")
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
        LogManager.shared.log("AudioManager: Current Route: \(currentRoute)")
    }
    
    func playAdhan(fileName: String? = nil, prayerName: String? = nil) {
        LogManager.shared.log("AudioManager: playAdhan called. File: \(String(describing: fileName)), Prayer: \(String(describing: prayerName))")
        
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
        
        // 1. Session Category
        do {
            let session = AVAudioSession.sharedInstance()
            LogManager.shared.log("AudioManager: Activating session...")
            
            // Simplify category setting to fix Error -50 (Invalid Param)
            // Just use .playback which is the critical part for background audio
            try session.setCategory(.playback, mode: .default)
            LogManager.shared.log("AudioManager: Category set to .playback (Default options)")
            
            // Note: .duckOthers and .defaultToSpeaker might be causing conflicts on some devices
            // if the session is already active or if the validation checks fail.
            // We start simple to ensure background audio works.
            
        } catch {
            let msg = "AudioManager: Session Category Failed: \(error.localizedDescription) (\(error))"
            print(msg)
            LogManager.shared.log(msg)
            // If this fails, background audio WILL fail.
        }

        // 2. Session Active
        do {
             try AVAudioSession.sharedInstance().setActive(true)
             LogManager.shared.log("AudioManager: Session active.")
        } catch {
             let msg = "AudioManager: Session Active Failed: \(error.localizedDescription) (\(error))"
             print(msg)
             LogManager.shared.log(msg)
        }
            
        // 3. Player Init
        do {
            LogManager.shared.log("AudioManager: Initializing player with URL: \(url)")
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            
            if player?.prepareToPlay() == true {
                 player?.play()
                 isPlaying = true
                 updateCurrentRoute()
                 LogManager.shared.log("AudioManager: Playing \(chosenFile) (Duration: \(player?.duration ?? 0))")
            } else {
                 let msg = "AudioManager: prepareToPlay() failed."
                 print(msg)
                 LogManager.shared.log(msg)
            }
        } catch {
            let msg = "AudioManager: Player Init Failed: \(error.localizedDescription) (\(error))"
            print(msg)
            LogManager.shared.log(msg)
        }
    }
    
    func stop() {
        LogManager.shared.log("AudioManager: Stop requested.")
        player?.stop()
        isPlaying = false
        deactivateSession()
    }
    
    private func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            LogManager.shared.log("AudioManager: Session deactivated.")
        } catch {
            let msg = "AudioManager: Failed to deactivate session: \(error.localizedDescription)"
            print(msg)
            LogManager.shared.log(msg)
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        LogManager.shared.log("AudioManager: Finished playing. Success: \(flag)")
        isPlaying = false
        deactivateSession()
    }
}
