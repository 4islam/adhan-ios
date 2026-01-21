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
    private let suiteName = "group.adhan.ntrust.ai"
    
    private init() {
        loadLogs()
    }
    
    private var defaults: UserDefaults {
        return UserDefaults(suiteName: suiteName) ?? .standard
    }
    
    func log(_ message: String) {
        let entry = LogEntry(message: message)
        DispatchQueue.main.async {
            self.logs.insert(entry, at: 0) // Newest first
            self.saveLogs()
        }
        print("LOG: \(message)") // Also print to console
    }
    
    func clearLogs() {
        logs.removeAll()
        saveLogs()
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
