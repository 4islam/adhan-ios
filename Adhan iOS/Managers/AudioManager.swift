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
    
    private var fadeTimer: Timer?
    
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
        // Logic: If fileName contains extension, use it. Else default to mp3.
        var ext = "mp3"
        var name = chosenFile
        
        if chosenFile.contains(".") {
             let parts = chosenFile.components(separatedBy: ".")
             if parts.count > 1 {
                 name = parts[0]
                 ext = parts[1] // e.g. "caf"
             }
        }
        
        if let bundleURL = Bundle.main.url(forResource: name, withExtension: ext) {
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
                 // Determine initial settings based on prayer
                 var initialVol: Float = 0.0
                 var fadeDuration: Double = 5.0
                 
                 if let prayer = prayerName {
                     // Keys match FadeSettingsView: "fade_{prayer}_volume", "fade_{prayer}_duration"
                     // Default to 0.0 volume and 5.0 duration if not set
                     let volKey = "fade_\(prayer.lowercased())_volume"
                     let durKey = "fade_\(prayer.lowercased())_duration"
                     
                     if UserDefaults.standard.object(forKey: volKey) != nil {
                         initialVol = Float(UserDefaults.standard.double(forKey: volKey))
                     }
                     if UserDefaults.standard.object(forKey: durKey) != nil {
                         fadeDuration = UserDefaults.standard.double(forKey: durKey)
                     }
                 }
                 
                 // Apply valid volume
                 player?.volume = initialVol
                 player?.play()
                 
                 // specific handling for "no fade" (duration 0)
                 if fadeDuration > 0 {
                     startFadeIn(duration: fadeDuration, startVolume: initialVol)
                 } else {
                     player?.volume = 1.0 // Instant full volume
                 }
                 
                 isPlaying = true
                 updateCurrentRoute()
                 LogManager.shared.log("AudioManager: Playing \(chosenFile) (Vol: \(initialVol) -> 1.0 over \(fadeDuration)s)")
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
    
    private func startFadeIn(duration: TimeInterval, startVolume: Float) {
        // Cancel any existing timer
        fadeTimer?.invalidate()
        
        guard duration > 0 else {
            player?.volume = 1.0
            return
        }
        
        let steps: Double = duration * 10 // Update every 0.1s
        let stepInterval = 0.1
        let volumeRange = 1.0 - startVolume
        let volumeIncrement = volumeRange / Float(steps)
        
        LogManager.shared.log("AudioManager: Starting fade-in from \(startVolume) over \(duration)s")
        
        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            guard let self = self, let player = self.player else {
                timer.invalidate()
                return
            }
            
            if player.volume < 1.0 {
                // Ensure we don't float-overflow past 1.0
                player.volume = min(1.0, player.volume + volumeIncrement)
            } else {
                // Done
                timer.invalidate()
                LogManager.shared.log("AudioManager: Fade-in complete.")
            }
        }
    }
    
    func stop() {
        LogManager.shared.log("AudioManager: Stop requested.")
        fadeTimer?.invalidate() // Stop fading if interrupted
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
        fadeTimer?.invalidate()
        isPlaying = false
        deactivateSession()
    }
}
