//
//  ActionDispatcher.swift
//  SolUnified
//
//  Routes tool calls to appropriate executors
//

import Foundation

class ActionDispatcher {

    private let calendarExecutor = CalendarActionExecutor()

    // MARK: - Dispatch

    func dispatch(_ toolCall: ToolCall) async -> ToolResult {
        guard let tool = AgentTool(rawValue: toolCall.toolName) else {
            return ToolResult(
                toolCallId: toolCall.id,
                result: "{\"error\": \"Unknown tool: \(toolCall.toolName)\"}",
                success: false
            )
        }

        do {
            switch tool {
            case .lookupContact:
                return try await executeLookupContact(toolCall)

            case .searchMemory:
                return try await executeSearchMemory(toolCall)

            case .checkCalendar:
                return try await calendarExecutor.checkAvailability(toolCall)

            case .createCalendarEvent:
                return try await calendarExecutor.createEvent(toolCall)

            case .sendEmail:
                return try await executeComposeEmail(toolCall)

            case .searchContext:
                return try await executeSearchContext(toolCall)

            case .saveMemory:
                return try await executeSaveMemory(toolCall)
            }
        } catch {
            return ToolResult(
                toolCallId: toolCall.id,
                result: "{\"error\": \"\(error.localizedDescription)\"}",
                success: false
            )
        }
    }

    // MARK: - Contact Lookup

    private func executeLookupContact(_ toolCall: ToolCall) async throws -> ToolResult {
        guard let args = parseArguments(toolCall.arguments, as: LookupContactArgs.self) else {
            return ToolResult(
                toolCallId: toolCall.id,
                result: "{\"error\": \"Invalid arguments for lookup_contact\"}",
                success: false
            )
        }

        let contacts = ContactsStore.shared.findContact(named: args.name)

        if contacts.isEmpty {
            return ToolResult(
                toolCallId: toolCall.id,
                result: "{\"found\": false, \"message\": \"No contact found with name '\(args.name)'\"}",
                success: true
            )
        }

        let contactsJson = contacts.map { contact -> [String: Any] in
            var dict: [String: Any] = [
                "id": contact.id,
                "name": contact.name,
                "relationship": contact.relationship.displayName
            ]
            if let email = contact.email { dict["email"] = email }
            if let phone = contact.phone { dict["phone"] = phone }
            if let company = contact.company { dict["company"] = company }
            if let role = contact.role { dict["role"] = role }
            if let notes = contact.notes { dict["notes"] = notes }

            // Include preferences if available
            if let meetingPrefs = contact.preferences.meetingPreferences {
                if !meetingPrefs.preferredLocations.isEmpty {
                    dict["preferred_locations"] = meetingPrefs.preferredLocations
                }
                if !meetingPrefs.preferredTimes.isEmpty {
                    dict["preferred_times"] = meetingPrefs.preferredTimes
                }
            }

            return dict
        }

        let result: [String: Any] = [
            "found": true,
            "count": contacts.count,
            "contacts": contactsJson
        ]

        let resultData = try JSONSerialization.data(withJSONObject: result)
        let resultStr = String(data: resultData, encoding: .utf8) ?? "{}"

        return ToolResult(
            toolCallId: toolCall.id,
            result: resultStr,
            success: true
        )
    }

    // MARK: - Memory Search

    private func executeSearchMemory(_ toolCall: ToolCall) async throws -> ToolResult {
        guard let args = parseArguments(toolCall.arguments, as: SearchMemoryArgs.self) else {
            return ToolResult(
                toolCallId: toolCall.id,
                result: "{\"error\": \"Invalid arguments for search_memory\"}",
                success: false
            )
        }

        var category: MemoryCategory?
        if let categoryStr = args.category {
            category = MemoryCategory(rawValue: categoryStr)
        }

        let query = MemoryQuery(
            category: category,
            keywords: args.keywords,
            minConfidence: 0.3,
            limit: 10
        )

        let memories = MemoryStore.shared.query(query)

        let memoriesJson = memories.map { memory -> [String: Any] in
            return [
                "category": memory.category.displayName,
                "key": memory.key,
                "value": memory.value,
                "confidence": memory.confidence
            ]
        }

        let result: [String: Any] = [
            "count": memories.count,
            "memories": memoriesJson
        ]

        let resultData = try JSONSerialization.data(withJSONObject: result)
        let resultStr = String(data: resultData, encoding: .utf8) ?? "{}"

        return ToolResult(
            toolCallId: toolCall.id,
            result: resultStr,
            success: true
        )
    }

    // MARK: - Context Search

    private func executeSearchContext(_ toolCall: ToolCall) async throws -> ToolResult {
        guard let args = parseArguments(toolCall.arguments, as: SearchContextArgs.self) else {
            return ToolResult(
                toolCallId: toolCall.id,
                result: "{\"error\": \"Invalid arguments for search_context\"}",
                success: false
            )
        }

        // Search clipboard
        let clipboardResults = ClipboardStore.shared.searchHistory(query: args.query)
            .prefix(5)
            .map { item -> [String: Any] in
                var dict: [String: Any] = [
                    "type": "clipboard",
                    "content_type": item.contentType.rawValue,
                    "created_at": ISO8601DateFormatter().string(from: item.createdAt)
                ]
                if let text = item.contentText {
                    dict["content"] = String(text.prefix(200))
                }
                if let app = item.sourceAppName {
                    dict["source_app"] = app
                }
                return dict
            }

        let result: [String: Any] = [
            "query": args.query,
            "results": Array(clipboardResults)
        ]

        let resultData = try JSONSerialization.data(withJSONObject: result)
        let resultStr = String(data: resultData, encoding: .utf8) ?? "{}"

        return ToolResult(
            toolCallId: toolCall.id,
            result: resultStr,
            success: true
        )
    }

    // MARK: - Save Memory

    private func executeSaveMemory(_ toolCall: ToolCall) async throws -> ToolResult {
        guard let args = parseArguments(toolCall.arguments, as: SaveMemoryArgs.self) else {
            return ToolResult(
                toolCallId: toolCall.id,
                result: "{\"error\": \"Invalid arguments for save_memory\"}",
                success: false
            )
        }

        guard let category = MemoryCategory(rawValue: args.category) else {
            return ToolResult(
                toolCallId: toolCall.id,
                result: "{\"error\": \"Invalid category: \(args.category)\"}",
                success: false
            )
        }

        MemoryStore.shared.learnFact(
            category: category,
            key: args.key,
            value: args.value,
            source: .agentLearned,
            confidence: 0.8
        )

        let result: [String: Any] = [
            "success": true,
            "message": "Memory saved: \(args.key) = \(args.value)"
        ]

        let resultData = try JSONSerialization.data(withJSONObject: result)
        let resultStr = String(data: resultData, encoding: .utf8) ?? "{}"

        return ToolResult(
            toolCallId: toolCall.id,
            result: resultStr,
            success: true
        )
    }

    // MARK: - Email (Placeholder)

    private func executeComposeEmail(_ toolCall: ToolCall) async throws -> ToolResult {
        guard let args = parseArguments(toolCall.arguments, as: SendEmailArgs.self) else {
            return ToolResult(
                toolCallId: toolCall.id,
                result: "{\"error\": \"Invalid arguments for send_email\"}",
                success: false
            )
        }

        // For now, just return the composed email for user review
        // In the future, this could actually send via Mail.app or an email API
        let result: [String: Any] = [
            "status": "draft_created",
            "message": "Email draft created (sending not yet implemented)",
            "email": [
                "to": args.to,
                "subject": args.subject,
                "body": args.body
            ]
        ]

        let resultData = try JSONSerialization.data(withJSONObject: result)
        let resultStr = String(data: resultData, encoding: .utf8) ?? "{}"

        return ToolResult(
            toolCallId: toolCall.id,
            result: resultStr,
            success: true
        )
    }

    // MARK: - Helpers

    private func parseArguments<T: Decodable>(_ json: String, as type: T.Type) -> T? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Argument Types

struct LookupContactArgs: Codable {
    let name: String
}

struct SearchMemoryArgs: Codable {
    let keywords: [String]
    let category: String?
}

struct SearchContextArgs: Codable {
    let query: String
}

struct SaveMemoryArgs: Codable {
    let category: String
    let key: String
    let value: String
}

struct SendEmailArgs: Codable {
    let to: String
    let subject: String
    let body: String
}
