import Foundation

struct AdhanHistoryEntry: Identifiable, Codable {
    let id: UUID
    let prayerName: String
    let scheduledTime: Date?
    let eventType: AdhanEventType
    let device: String?
    let volume: Float?
    let details: String?
    let timestamp: Date
    
    enum AdhanEventType: String, Codable {
        case scheduled = "Scheduled"
        case triggered = "Triggered (Foreground)"
        case played = "Played Successfully"
        case actionTaken = "User Action"
        case failed = "Failed"
    }
    
    init(prayerName: String, scheduledTime: Date? = nil, eventType: AdhanEventType, device: String? = nil, volume: Float? = nil, details: String? = nil) {
        self.id = UUID()
        self.prayerName = prayerName
        self.scheduledTime = scheduledTime
        self.eventType = eventType
        self.device = device
        self.volume = volume
        self.details = details
        self.timestamp = Date()
    }
}

class AdhanHistoryManager: ObservableObject {
    static let shared = AdhanHistoryManager()
    
    @Published var history: [AdhanHistoryEntry] = []
    
    private let storageKey = "AdhanHistoryLogs"
    private let maxEntries = 200
    
    private init() {
        loadHistory()
    }
    
    func logEvent(prayerName: String, scheduledTime: Date? = nil, eventType: AdhanHistoryEntry.AdhanEventType, device: String? = nil, volume: Float? = nil, details: String? = nil) {
        let entry = AdhanHistoryEntry(
            prayerName: prayerName,
            scheduledTime: scheduledTime,
            eventType: eventType,
            device: device,
            volume: volume,
            details: details
        )
        
        DispatchQueue.main.async {
            self.history.insert(entry, at: 0)
            
            if self.history.count > self.maxEntries {
                self.history = Array(self.history.prefix(self.maxEntries))
            }
            
            self.saveHistory()
        }
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([AdhanHistoryEntry].self, from: data) {
            self.history = decoded
        }
    }
    
    func clearHistory() {
        DispatchQueue.main.async {
            self.history.removeAll()
            UserDefaults.standard.removeObject(forKey: self.storageKey)
        }
    }
}
