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
}

class LogManager: ObservableObject {
    static let shared = LogManager()
    
    @Published var logs: [LogEntry] = []
    
    private let storageKey = "ApplicationLogs"
    
    private init() {
        loadLogs()
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
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadLogs() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([LogEntry].self, from: data) {
            self.logs = decoded
        }
    }
}
