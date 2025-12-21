//
//  SafeAgentComms.swift
//  SolUnified
//
//  Safe agent communication with conflict detection
//

import Foundation
import CryptoKit

struct SafeMessage: Codable {
    let id: String
    let from: String
    let to: String
    let content: String
    let timestamp: String
    let checksum: String
    
    init(from: String, to: String, content: String) {
        self.id = UUID().uuidString
        self.from = from
        self.to = to
        self.content = content
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.checksum = Self.generateChecksum(id: id, content: content, timestamp: timestamp)
    }
    
    static func generateChecksum(id: String, content: String, timestamp: String) -> String {
        let combined = "\(id):\(content):\(timestamp)"
        let data = Data(combined.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    var isValid: Bool {
        return Self.generateChecksum(id: id, content: content, timestamp: timestamp) == checksum
    }
}

struct MessageQueue: Codable {
    var messages: [SafeMessage] = []
    var lastModified: String
    var version: Int
    
    init() {
        self.lastModified = ISO8601DateFormatter().string(from: Date())
        self.version = 1
    }
    
    mutating func addMessage(_ message: SafeMessage) {
        messages.append(message)
        lastModified = ISO8601DateFormatter().string(from: Date())
        version += 1
    }
    
    func getMessagesFor(agent: String, since: String? = nil) -> [SafeMessage] {
        var filtered = messages.filter { $0.to == agent }
        
        if let since = since,
           let sinceDate = ISO8601DateFormatter().date(from: since) {
            filtered = filtered.filter { message in
                if let messageDate = ISO8601DateFormatter().date(from: message.timestamp) {
                    return messageDate > sinceDate
                }
                return true
            }
        }
        
        return filtered.sorted { $0.timestamp < $1.timestamp }
    }
}

class SafeAgentComms {
    static let shared = SafeAgentComms()
    
    private let queuePath = "/Users/savarsareen/coding/research/message_queue.json"
    private let lockPath = "/Users/savarsareen/coding/research/.message_lock"
    
    private init() {}
    
    func sendMessage(from: String, to: String, content: String) -> Bool {
        return performSafeOperation { queue in
            let message = SafeMessage(from: from, to: to, content: content)
            queue.addMessage(message)
            print("📨 Safe message sent: \(from) → \(to)")
            return true
        } ?? false
    }
    
    func getMessages(for agent: String, since: String? = nil) -> [SafeMessage] {
        return performSafeOperation { queue in
            return queue.getMessagesFor(agent: agent, since: since)
        } ?? []
    }
    
    func getAllMessages() -> [SafeMessage] {
        return performSafeOperation { queue in
            return queue.messages
        } ?? []
    }
    
    private func performSafeOperation<T>(_ operation: (inout MessageQueue) -> T) -> T? {
        // Try to acquire lock
        guard acquireLock() else {
            print("❌ Could not acquire message lock")
            return nil
        }
        
        defer { releaseLock() }
        
        do {
            // Load current queue
            var queue = loadQueue()
            
            // Perform operation
            let result = operation(&queue)
            
            // Save updated queue
            try saveQueue(queue)
            
            return result
        } catch {
            print("❌ Safe operation failed: \(error)")
            return nil
        }
    }
    
    private func loadQueue() -> MessageQueue {
        guard FileManager.default.fileExists(atPath: queuePath),
              let data = FileManager.default.contents(atPath: queuePath),
              let queue = try? JSONDecoder().decode(MessageQueue.self, from: data) else {
            return MessageQueue()
        }
        
        // Validate message integrity
        let validMessages = queue.messages.filter { $0.isValid }
        if validMessages.count != queue.messages.count {
            print("⚠️ Found \(queue.messages.count - validMessages.count) corrupted messages")
        }
        
        var cleanQueue = queue
        cleanQueue.messages = validMessages
        return cleanQueue
    }
    
    private func saveQueue(_ queue: MessageQueue) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(queue)
        try data.write(to: URL(fileURLWithPath: queuePath))
    }
    
    private func acquireLock() -> Bool {
        let maxRetries = 10
        let retryDelay: UInt32 = 100_000 // 0.1 seconds
        
        for _ in 0..<maxRetries {
            if !FileManager.default.fileExists(atPath: lockPath) {
                // Try to create lock file
                let lockContent = "\(ProcessInfo.processInfo.processIdentifier):\(Date().timeIntervalSince1970)"
                
                do {
                    try lockContent.write(toFile: lockPath, atomically: true, encoding: .utf8)
                    return true
                } catch {
                    // Lock creation failed, someone else got it
                }
            }
            
            // Check if lock is stale (older than 5 seconds)
            if let attributes = try? FileManager.default.attributesOfItem(atPath: lockPath),
               let modDate = attributes[.modificationDate] as? Date,
               Date().timeIntervalSince(modDate) > 5 {
                // Remove stale lock
                try? FileManager.default.removeItem(atPath: lockPath)
            }
            
            usleep(retryDelay)
        }
        
        return false
    }
    
    private func releaseLock() {
        try? FileManager.default.removeItem(atPath: lockPath)
    }
}

// MARK: - Integration with existing bridge
extension SafeAgentComms {
    func syncWithBridge() {
        let messages = getAllMessages()
        
        // Convert to bridge format and update
        // This can be called periodically to sync safe messages with the bridge file
        updateBridgeFromMessages(messages)
    }
    
    private func updateBridgeFromMessages(_ messages: [SafeMessage]) {
        let bridgePath = "/Users/savarsareen/coding/research/agent_bridge.json"
        
        guard let data = FileManager.default.contents(atPath: bridgePath),
              var bridge = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        // Get latest messages for each direction
        let latestToDevon = messages.filter { $0.to == "devon" || $0.to == "josh" }.last
        let latestToGunter = messages.filter { $0.to == "gunter" }.last
        
        // Update bridge with latest messages
        if let msg = latestToDevon {
            bridge["message_to_josh"] = [
                "from": msg.from,
                "timestamp": msg.timestamp,
                "content": msg.content,
                "priority": "high"
            ]
        }
        
        if let msg = latestToGunter {
            bridge["message_to_gunter"] = [
                "from": msg.from,
                "timestamp": msg.timestamp,
                "content": msg.content,
                "priority": "high"
            ]
        }
        
        bridge["last_sync"] = ISO8601DateFormatter().string(from: Date())
        
        // Save updated bridge
        do {
            let updatedData = try JSONSerialization.data(withJSONObject: bridge, options: .prettyPrinted)
            try updatedData.write(to: URL(fileURLWithPath: bridgePath))
            print("✅ Bridge synced with safe messages")
        } catch {
            print("❌ Failed to sync bridge: \(error)")
        }
    }
}