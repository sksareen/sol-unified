import Foundation
import Combine

struct AgentContext: Codable {
    var mission: String
    var status: String
    var todos: [String]
    
    // Allow flexible parsing for other fields we might add later
    // but these are the core ones we care about for the UI
}

class AgentContextStore: ObservableObject {
    @Published var joshContext: AgentContext?
    @Published var researchContext: AgentContext?
    @Published var lastUpdated: Date = Date()
    
    private let joshPath = "/Users/savarsareen/coding/earn/josh/context.json"
    private let researchPath = "/Users/savarsareen/coding/research/context.json"
    
    private var joshMonitor: DispatchSourceFileSystemObject?
    private var researchMonitor: DispatchSourceFileSystemObject?
    
    init() {
        loadContexts()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func loadContexts() {
        joshContext = loadContext(from: joshPath)
        researchContext = loadContext(from: researchPath)
        lastUpdated = Date()
    }
    
    private func loadContext(from path: String) -> AgentContext? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        
        do {
            // Use a custom decoder strategy if needed, but standard JSONDecoder should work
            // given our struct matches the JSON structure
            // We might need a wrapper since the JSON has specific keys
            
            // Let's use a more flexible dictionary approach first to map to our struct
            // because the JSON structure might vary slightly between agents
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            guard let json = json else { return nil }
            
            let mission = json["mission"] as? String ?? "No mission set"
            
            // Handle status which might be "current_state" or "status"
            let status = (json["status"] as? String) ?? (json["current_state"] as? String) ?? "Idle"
            
            // Handle todos/priorities
            var todos: [String] = []
            if let todoList = json["todos"] as? [String] {
                todos = todoList
            } else if let priorities = json["next_priorities"] as? [String] {
                todos = priorities
            }
            
            return AgentContext(mission: mission, status: status, todos: todos)
            
        } catch {
            print("Error decoding context at \(path): \(error)")
            return nil
        }
    }
    
    private func startMonitoring() {
        monitorFile(path: joshPath) { [weak self] in
            print("Josh context changed")
            DispatchQueue.main.async {
                self?.joshContext = self?.loadContext(from: self?.joshPath ?? "")
                self?.lastUpdated = Date()
            }
        }
        
        monitorFile(path: researchPath) { [weak self] in
            print("Research context changed")
            DispatchQueue.main.async {
                self?.researchContext = self?.loadContext(from: self?.researchPath ?? "")
                self?.lastUpdated = Date()
            }
        }
    }
    
    private func monitorFile(path: String, onChange: @escaping () -> Void) {
        let fileURL = URL(fileURLWithPath: path)
        let fileDescriptor = open(fileURL.path, O_EVTONLY)
        
        guard fileDescriptor != -1 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.global()
        )
        
        source.setEventHandler {
            onChange()
        }
        
        source.setCancelHandler {
            close(fileDescriptor)
        }
        
        source.resume()
        
        if path.contains("josh") {
            joshMonitor = source
        } else {
            researchMonitor = source
        }
    }
    
    private func stopMonitoring() {
        joshMonitor?.cancel()
        researchMonitor?.cancel()
        joshMonitor = nil
        researchMonitor = nil
    }
}
