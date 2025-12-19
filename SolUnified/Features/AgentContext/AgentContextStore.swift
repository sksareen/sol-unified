import Foundation
import Combine

struct AgentContext: Codable {
    var mission: String
    var status: String
    var todos: [String]
}

struct AgentMessage: Codable, Identifiable {
    var id: String { timestamp } // Simple ID for SwiftUI
    let from: String
    let timestamp: String
    let content: String
    let priority: String?
    let action_requested: String?
}

struct AgentBridge: Codable {
    var bridge_version: String
    var shared_knowledge: SharedKnowledge?
    var message_to_josh: AgentMessage?
    var message_to_gunter: AgentMessage?
    var last_sync: String
    
    struct SharedKnowledge: Codable {
        var research_findings: [String]?
        var product_opportunities: [String]?
    }
}

class AgentContextStore: ObservableObject {
    @Published var joshContext: AgentContext?
    @Published var researchContext: AgentContext?
    @Published var agentBridge: AgentBridge?
    @Published var lastUpdated: Date = Date()
    @Published var isSyncing: Bool = false
    
    private let joshPath = "/Users/savarsareen/coding/earn/josh/context.json"
    private let researchPath = "/Users/savarsareen/coding/research/context.json"
    private let bridgePath = "/Users/savarsareen/coding/research/agent_bridge.json"
    
    private var joshMonitor: DispatchSourceFileSystemObject?
    private var researchMonitor: DispatchSourceFileSystemObject?
    private var bridgeMonitor: DispatchSourceFileSystemObject?
    
    private let memoryTracker = MemoryTracker.shared
    
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
        agentBridge = loadBridge()
        lastUpdated = Date()
        print("🔄 Contexts synced manually at \(lastUpdated)")
    }
    
    func forceSync() {
        isSyncing = true
        loadContexts()
        updateBridgeLastSync()
        
        // Brief delay to show syncing state for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.isSyncing = false
        }
    }
    
    private func updateBridgeLastSync() {
        guard var currentBridge = agentBridge else { return }
        
        currentBridge.last_sync = ISO8601DateFormatter().string(from: Date())
        
        // Save updated bridge
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(currentBridge)
            try data.write(to: URL(fileURLWithPath: bridgePath))
            
            // Update local state
            self.agentBridge = currentBridge
        } catch {
            print("Error updating bridge last_sync: \(error)")
        }
    }
    
    func sendMessage(content: String, to recipient: String) {
        guard var currentBridge = agentBridge else { return }
        
        let message = AgentMessage(
            from: "user",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            content: content,
            priority: "high",
            action_requested: nil
        )
        
        if recipient.lowercased() == "josh" {
            currentBridge.message_to_josh = message
        } else if recipient.lowercased() == "gunter" {
            currentBridge.message_to_gunter = message
        } else {
            // Broadcast to both
            currentBridge.message_to_josh = message
            currentBridge.message_to_gunter = message
        }
        
        currentBridge.last_sync = ISO8601DateFormatter().string(from: Date())
        
        // Save to file
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(currentBridge)
            try data.write(to: URL(fileURLWithPath: bridgePath))
            
            // Update local state immediately
            self.agentBridge = currentBridge
            
            // Trigger memory update
            memoryTracker.updateContextFile()
        } catch {
            print("Error writing bridge: \(error)")
        }
    }
    
    func refreshMemory() {
        memoryTracker.updateContextFile()
    }
    
    private func loadContext(from path: String) -> AgentContext? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let json = json else { return nil }
            
            let mission = json["mission"] as? String ?? "No mission set"
            let status = (json["status"] as? String) ?? (json["current_state"] as? String) ?? "Idle"
            
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
    
    private func loadBridge() -> AgentBridge? {
        guard let data = FileManager.default.contents(atPath: bridgePath) else { return nil }
        
        do {
            return try JSONDecoder().decode(AgentBridge.self, from: data)
        } catch {
            print("Error decoding bridge: \(error)")
            return nil
        }
    }
    
    private func startMonitoring() {
        monitorFile(path: joshPath) { [weak self] in
            DispatchQueue.main.async {
                self?.joshContext = self?.loadContext(from: self?.joshPath ?? "")
                self?.lastUpdated = Date()
            }
        }
        
        monitorFile(path: researchPath) { [weak self] in
            DispatchQueue.main.async {
                self?.researchContext = self?.loadContext(from: self?.researchPath ?? "")
                self?.lastUpdated = Date()
            }
        }
        
        monitorFile(path: bridgePath) { [weak self] in
            print("Bridge file changed!") // Debug log
            DispatchQueue.main.async {
                print("Reloading bridge data...")
                self?.agentBridge = self?.loadBridge()
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
        } else if path.contains("research/context") {
            researchMonitor = source
        } else {
            bridgeMonitor = source
        }
    }
    
    private func stopMonitoring() {
        joshMonitor?.cancel()
        researchMonitor?.cancel()
        bridgeMonitor?.cancel()
        
        joshMonitor = nil
        researchMonitor = nil
        bridgeMonitor = nil
    }
}
