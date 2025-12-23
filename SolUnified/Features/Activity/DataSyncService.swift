//
//  DataSyncService.swift
//  SolUnified
//
//  Service to sync captured data to external API/AI model
//

import Foundation

class DataSyncService {
    static let shared = DataSyncService()
    
    private let apiEndpoint = "https://api.sol-unified.com/v1/ingest" // Placeholder
    private let db = Database.shared
    
    private init() {}
    
    func syncSequence(id: String) {
        guard let sequence = db.getSequence(id: id) else { return }
        
        // Get all events for this sequence
        let events = getEventsForSequence(id)
        
        let payload: [String: Any] = [
            "sequence_id": sequence.id,
            "type": sequence.type.rawValue,
            "start_time": Database.dateToString(sequence.startTime),
            "end_time": sequence.endTime.map { Database.dateToString($0) } as Any,
            "status": sequence.status.rawValue,
            "metadata": sequence.metadata as Any,
            "events": events.map { eventToDict($0) }
        ]
        
        // "Call API" - for now, we'll just log it or save to a file for the AI agent to pick up
        // In the future, this would be a network request
        sendToAPI(payload)
        
        // Also notify the local agent system via SafeAgentComms
        notifyAgent(sequenceId: id, eventCount: events.count)
    }
    
    private func getEventsForSequence(_ sequenceId: String) -> [ActivityEvent] {
        let results = db.query(
            "SELECT * FROM activity_log WHERE sequence_id = ? ORDER BY timestamp ASC",
            parameters: [sequenceId]
        )
        
        // We need to map the raw rows back to ActivityEvent
        // Since eventFromRow is private in ActivityStore, we duplicate simple mapping here or make it public
        // For now, I'll rely on a simplified mapping or move eventFromRow to Database extension?
        // Let's just do manual mapping here since we need it for export
        return results.compactMap { row in
            guard let eventTypeStr = row["event_type"] as? String,
                  let eventType = ActivityEventType(rawValue: eventTypeStr),
                  let timestampStr = row["timestamp"] as? String,
                  let timestamp = Database.stringToDate(timestampStr),
                  let createdAtStr = row["created_at"] as? String,
                  let createdAt = Database.stringToDate(createdAtStr) else {
                return nil
            }
            
            return ActivityEvent(
                id: row["id"] as? Int ?? 0,
                eventType: eventType,
                appBundleId: row["app_bundle_id"] as? String,
                appName: row["app_name"] as? String,
                windowTitle: row["window_title"] as? String,
                eventData: row["event_data"] as? String,
                timestamp: timestamp,
                createdAt: createdAt,
                sequenceId: row["sequence_id"] as? String
            )
        }
    }
    
    private func eventToDict(_ event: ActivityEvent) -> [String: Any] {
        var dict: [String: Any] = [
            "id": event.id,
            "type": event.eventType.rawValue,
            "timestamp": Database.dateToString(event.timestamp)
        ]
        
        if let app = event.appName { dict["app"] = app }
        if let title = event.windowTitle { dict["window"] = title }
        if let data = event.eventData {
            // Try to parse JSON data if possible
            if let jsonData = data.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) {
                dict["data"] = jsonObject
            } else {
                dict["data"] = data
            }
        }
        
        return dict
    }
    
    private func sendToAPI(_ payload: [String: Any]) {
        // Mock API Call
        print("🌐 [DataSync] Syncing sequence to API...")
        
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }
        
        // Save to a dump file for inspection/AI consumption
        let filename = "sequence_dump_\(payload["sequence_id"] ?? "unknown").json"
        let dumpPath = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        try? jsonString.write(to: dumpPath, atomically: true, encoding: .utf8)
        print("🌐 [DataSync] Dumped to \(dumpPath.path)")
    }
    
    private func notifyAgent(sequenceId: String, eventCount: Int) {
        let message = "New sequence captured: \(sequenceId) with \(eventCount) events. Ready for analysis."
        _ = SafeAgentComms.shared.sendMessage(from: "SolUnified", to: "Gunter", content: message)
    }
}

