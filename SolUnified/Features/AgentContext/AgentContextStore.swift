import Foundation
import Combine

struct AgentStatus: Codable, Identifiable {
    let name: String
    let last_active: String?
    let current_focus: String
    let status: String
    
    var id: String { name }
    
    init(name: String, last_active: String?, current_focus: String, status: String) {
        self.name = name
        self.last_active = last_active
        self.current_focus = current_focus
        self.status = status
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.last_active = try container.decodeIfPresent(String.self, forKey: .last_active)
        self.current_focus = try container.decode(String.self, forKey: .current_focus)
        self.status = try container.decode(String.self, forKey: .status)
        // name is derived from the dictionary key, set externally
        self.name = ""
    }
    
    enum CodingKeys: String, CodingKey {
        case last_active
        case current_focus
        case status
    }
}

struct AgentMessage: Codable, Identifiable {
    let id = UUID()
    let from: String
    let to: String?
    let timestamp: String
    let content: String
    let priority: String?
    let action_requested: String?
    
    enum CodingKeys: String, CodingKey {
        case from, to, timestamp, content, priority, action_requested
    }
}

struct AgentState: Codable {
    let version: String
    let last_updated: String
    let system_status: String
    let active_agents: [String: AgentStatus]
    
    enum CodingKeys: String, CodingKey {
        case version, last_updated, system_status, active_agents
    }
}

class AgentContextStore: ObservableObject {
    @Published var agentState: AgentState?
    @Published var messages: [AgentMessage] = []
    @Published var lastUpdated: Date = Date()
    @Published var isSyncing: Bool = false
    
    private let statePath = NSHomeDirectory() + "/Documents/agent_state.json"
    private let messagesPath = NSHomeDirectory() + "/Documents/agent_messages.log"
    
    private var stateMonitor: DispatchSourceFileSystemObject?
    private var messagesMonitor: DispatchSourceFileSystemObject?
    
    private let memoryTracker = MemoryTracker.shared
    
    init() {
        loadData()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func loadData() {
        agentState = loadState()
        messages = loadMessages()
        lastUpdated = Date()
        print("🔄 Agent data loaded at \(lastUpdated)")
    }
    
    func forceSync() {
        isSyncing = true
        loadData()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.isSyncing = false
        }
    }
    
    func refreshMemory() {
        memoryTracker.updateContextFile()
    }
    
    private func loadState() -> AgentState? {
        guard let data = FileManager.default.contents(atPath: statePath) else {
            print("⚠️ Could not read agent_state.json")
            return nil
        }
        
        do {
            // Parse manually to inject agent names
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let json = json,
                  let version = json["version"] as? String,
                  let lastUpdated = json["last_updated"] as? String,
                  let systemStatus = json["system_status"] as? String,
                  let activeAgentsDict = json["active_agents"] as? [String: [String: Any]] else {
                return nil
            }
            
            var agents: [String: AgentStatus] = [:]
            for (name, agentData) in activeAgentsDict {
                let lastActive = agentData["last_active"] as? String
                let currentFocus = agentData["current_focus"] as? String ?? ""
                let status = agentData["status"] as? String ?? "offline"
                
                agents[name] = AgentStatus(
                    name: name,
                    last_active: lastActive,
                    current_focus: currentFocus,
                    status: status
                )
            }
            
            return AgentState(
                version: version,
                last_updated: lastUpdated,
                system_status: systemStatus,
                active_agents: agents
            )
        } catch {
            print("Error decoding agent_state.json: \(error)")
            return nil
        }
    }
    
    private func loadMessages() -> [AgentMessage] {
        guard let content = try? String(contentsOfFile: messagesPath, encoding: .utf8) else {
            print("⚠️ Could not read agent_messages.log")
            return []
        }
        
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        var parsedMessages: [AgentMessage] = []
        
        for line in lines {
            guard let data = line.data(using: .utf8) else { continue }
            
            do {
                let message = try JSONDecoder().decode(AgentMessage.self, from: data)
                parsedMessages.append(message)
            } catch {
                print("⚠️ Could not parse message line: \(error)")
            }
        }
        
        // Return in reverse chronological order (newest first)
        return parsedMessages.reversed()
    }
    
    private func startMonitoring() {
        monitorFile(path: statePath) { [weak self] in
            DispatchQueue.main.async {
                self?.agentState = self?.loadState()
                self?.lastUpdated = Date()
            }
        }
        
        monitorFile(path: messagesPath) { [weak self] in
            DispatchQueue.main.async {
                self?.messages = self?.loadMessages() ?? []
                self?.lastUpdated = Date()
            }
        }
    }
    
    private func monitorFile(path: String, onChange: @escaping () -> Void) {
        let fileURL = URL(fileURLWithPath: path)
        let fileDescriptor = open(fileURL.path, O_EVTONLY)
        
        guard fileDescriptor != -1 else {
            print("⚠️ Could not open file descriptor for \(path)")
            return
        }
        
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
        
        if path.contains("agent_state") {
            stateMonitor = source
        } else {
            messagesMonitor = source
        }
    }
    
    private func stopMonitoring() {
        stateMonitor?.cancel()
        messagesMonitor?.cancel()
        
        stateMonitor = nil
        messagesMonitor = nil
    }
}
