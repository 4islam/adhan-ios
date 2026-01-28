import Foundation
import Combine

struct LogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let message: String
    
    init(message: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.message = message
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}

class LogManager: ObservableObject {
    static let shared = LogManager()
    
    @Published var logs: [LogEntry] = []
    
    private let storageKey = "ApplicationLogs"
    
    private init() {
        loadLogs()
    }
    
    private var defaults: UserDefaults {
        return .standard
    }
    
    private var saveWorkItem: DispatchWorkItem?
    
    /// Flag to control performance-heavy logging. Defaulted to false.
    @Published var isPerfLoggingEnabled: Bool = UserDefaults.standard.bool(forKey: "isPerfLoggingEnabled") {
        didSet {
            UserDefaults.standard.set(isPerfLoggingEnabled, forKey: "isPerfLoggingEnabled")
        }
    }
    
    func log(_ message: String) {
        let entry = LogEntry(message: message)
        DispatchQueue.main.async {
            self.logs.insert(entry, at: 0) // Newest first
            
            // Cap to 500 logs to avoid bloating Preferences
            if self.logs.count > 500 {
                self.logs = Array(self.logs.prefix(500))
            }
            
            self.queueSave()
        }
        print("LOG: \(message)") // Also print to console
    }
    
    func perfLog(_ message: String) {
        if isPerfLoggingEnabled {
            log("[Perf] \(message)")
        } else {
            // Optional: Still print to console but don't persist to UI/Prefs if disabled?
            // User asked for controllable, usually means "I don't want to see them".
            // Let's only print to console for developers but skip the persistence overhead.
            print("PERF_LOG (Suppressed): \(message)")
        }
    }
    
    func clearLogs() {
        logs.removeAll()
        queueSave()
    }
    
    private func queueSave() {
        saveWorkItem?.cancel()
        
        let item = DispatchWorkItem { [weak self] in
            self?.saveLogs()
        }
        
        saveWorkItem = item
        // Wait 1 second of stillness before writing logs to disk
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
    }
    
    private func saveLogs() {
        if let encoded = try? JSONEncoder().encode(logs) {
            defaults.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadLogs() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([LogEntry].self, from: data) {
            self.logs = decoded
        }
    }
}
