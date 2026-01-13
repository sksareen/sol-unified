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

            // People/CRM tools
            case .searchPeople:
                return try await executeSearchPeople(toolCall)

            case .addPerson:
                return try await executeAddPerson(toolCall)

            case .updatePerson:
                return try await executeUpdatePerson(toolCall)

            case .addConnection:
                return try await executeAddConnection(toolCall)

            case .getNetwork:
                return try await executeGetNetwork(toolCall)
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

        // Load tasks from agent_state.json
        let tasks = loadTasksFromAgentState()

        // Filter to active tasks (not archived/completed) unless query specifically asks for them
        let queryLower = args.query.lowercased()
        let includeCompleted = queryLower.contains("completed") || queryLower.contains("done") || queryLower.contains("finished")
        let includeArchived = queryLower.contains("archived") || queryLower.contains("archive") || queryLower.contains("all")

        let filteredTasks = tasks.filter { task in
            let status = task["status"] as? String ?? ""
            if status == "archived" && !includeArchived { return false }
            if status == "completed" && !includeCompleted { return false }
            return true
        }

        let result: [String: Any] = [
            "query": args.query,
            "tasks": filteredTasks,
            "clipboard_results": Array(clipboardResults)
        ]

        let resultData = try JSONSerialization.data(withJSONObject: result)
        let resultStr = String(data: resultData, encoding: .utf8) ?? "{}"

        return ToolResult(
            toolCallId: toolCall.id,
            result: resultStr,
            success: true
        )
    }

    // MARK: - Task Loading

    private func loadTasksFromAgentState() -> [[String: Any]] {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let agentStatePath = documents.appendingPathComponent("agent_state.json").path

        guard let data = FileManager.default.contents(atPath: agentStatePath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tasksDict = json["tasks"] as? [String: [String: Any]] else {
            return []
        }

        return tasksDict.values.map { task in
            var taskInfo: [String: Any] = [
                "id": task["id"] ?? "",
                "title": task["title"] ?? "",
                "description": task["description"] ?? "",
                "status": task["status"] ?? "pending",
                "priority": task["priority"] ?? "medium",
                "assigned_to": task["assigned_to"] ?? "me",
                "project": task["project"] ?? "general"
            ]
            if let createdAt = task["created_at"] { taskInfo["created_at"] = createdAt }
            if let updatedAt = task["updated_at"] { taskInfo["updated_at"] = updatedAt }
            return taskInfo
        }
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

    // MARK: - People/CRM Tools

    private func executeSearchPeople(_ toolCall: ToolCall) async throws -> ToolResult {
        guard let args = parseArguments(toolCall.arguments, as: SearchPeopleArgs.self) else {
            return ToolResult(
                toolCallId: toolCall.id,
                result: "{\"error\": \"Invalid arguments for search_people\"}",
                success: false
            )
        }

        let people = PeopleStore.shared.searchPeople(query: args.query)
        let results = people.prefix(15).map { person -> [String: Any] in
            var dict: [String: Any] = [
                "id": person.id,
                "name": person.name
            ]
            if let email = person.email { dict["email"] = email }
            if let oneLiner = person.oneLiner { dict["one_liner"] = oneLiner }
            if !person.tags.isEmpty { dict["tags"] = person.tags }
            if !person.organizations.isEmpty {
                dict["organizations"] = person.organizations.compactMap { $0.organization?.name }
            }
            dict["connection_count"] = person.connections.count
            return dict
        }

        let result: [String: Any] = [
            "query": args.query,
            "count": people.count,
            "people": Array(results)
        ]

        let resultData = try JSONSerialization.data(withJSONObject: result)
        let resultStr = String(data: resultData, encoding: .utf8) ?? "{}"

        return ToolResult(
            toolCallId: toolCall.id,
            result: resultStr,
            success: true
        )
    }

    private func executeAddPerson(_ toolCall: ToolCall) async throws -> ToolResult {
        guard let args = parseArguments(toolCall.arguments, as: AddPersonArgs.self) else {
            return ToolResult(
                toolCallId: toolCall.id,
                result: "{\"error\": \"Invalid arguments for add_person\"}",
                success: false
            )
        }

        // Check if person already exists
        if let existing = PeopleStore.shared.getPersonByName(args.name) {
            let result: [String: Any] = [
                "success": false,
                "message": "Person with name '\(args.name)' already exists",
                "existing_person_id": existing.id
            ]
            let resultData = try JSONSerialization.data(withJSONObject: result)
            return ToolResult(
                toolCallId: toolCall.id,
                result: String(data: resultData, encoding: .utf8) ?? "{}",
                success: true
            )
        }

        var person = Person(
            name: args.name,
            oneLiner: args.one_liner,
            notes: args.notes,
            location: args.location,
            currentCity: args.current_city,
            email: args.email,
            phone: args.phone,
            linkedin: args.linkedin
        )
        person.tags = args.tags ?? []

        let success = PeopleStore.shared.savePerson(person)

        let result: [String: Any] = [
            "success": success,
            "message": success ? "Person '\(args.name)' added successfully" : "Failed to add person",
            "person_id": person.id
        ]

        let resultData = try JSONSerialization.data(withJSONObject: result)
        return ToolResult(
            toolCallId: toolCall.id,
            result: String(data: resultData, encoding: .utf8) ?? "{}",
            success: success
        )
    }

    private func executeUpdatePerson(_ toolCall: ToolCall) async throws -> ToolResult {
        guard let args = parseArguments(toolCall.arguments, as: UpdatePersonArgs.self) else {
            return ToolResult(
                toolCallId: toolCall.id,
                result: "{\"error\": \"Invalid arguments for update_person\"}",
                success: false
            )
        }

        // Find person by ID or name
        var person: Person?
        if let id = args.id {
            person = PeopleStore.shared.getPerson(id: id)
        } else if let name = args.name {
            person = PeopleStore.shared.getPersonByName(name)
        }

        guard var existingPerson = person else {
            let identifier = args.id ?? args.name ?? "unknown"
            let result: [String: Any] = [
                "success": false,
                "message": "Person '\(identifier)' not found. Use search_people to find the correct person first."
            ]
            let resultData = try JSONSerialization.data(withJSONObject: result)
            return ToolResult(
                toolCallId: toolCall.id,
                result: String(data: resultData, encoding: .utf8) ?? "{}",
                success: false
            )
        }

        // Update fields if provided
        if let name = args.new_name, !name.isEmpty {
            existingPerson.name = name
        }
        if let oneLiner = args.one_liner {
            existingPerson.oneLiner = oneLiner.isEmpty ? nil : oneLiner
        }
        if let notes = args.notes {
            existingPerson.notes = notes.isEmpty ? nil : notes
        }
        if let email = args.email {
            existingPerson.email = email.isEmpty ? nil : email
        }
        if let phone = args.phone {
            existingPerson.phone = phone.isEmpty ? nil : phone
        }
        if let linkedin = args.linkedin {
            existingPerson.linkedin = linkedin.isEmpty ? nil : linkedin
        }
        if let location = args.location {
            existingPerson.location = location.isEmpty ? nil : location
        }
        if let currentCity = args.current_city {
            existingPerson.currentCity = currentCity.isEmpty ? nil : currentCity
        }
        if let tags = args.tags {
            existingPerson.tags = tags
        }

        existingPerson.updatedAt = Date()

        let success = PeopleStore.shared.savePerson(existingPerson)

        let result: [String: Any] = [
            "success": success,
            "message": success ? "Person '\(existingPerson.name)' updated successfully" : "Failed to update person",
            "person_id": existingPerson.id
        ]

        let resultData = try JSONSerialization.data(withJSONObject: result)
        return ToolResult(
            toolCallId: toolCall.id,
            result: String(data: resultData, encoding: .utf8) ?? "{}",
            success: success
        )
    }

    private func executeAddConnection(_ toolCall: ToolCall) async throws -> ToolResult {
        guard let args = parseArguments(toolCall.arguments, as: AddConnectionArgs.self) else {
            return ToolResult(
                toolCallId: toolCall.id,
                result: "{\"error\": \"Invalid arguments for add_connection\"}",
                success: false
            )
        }

        // Find both people by name
        guard let personA = PeopleStore.shared.getPersonByName(args.person_a_name) else {
            let result: [String: Any] = [
                "success": false,
                "message": "Person '\(args.person_a_name)' not found"
            ]
            let resultData = try JSONSerialization.data(withJSONObject: result)
            return ToolResult(
                toolCallId: toolCall.id,
                result: String(data: resultData, encoding: .utf8) ?? "{}",
                success: false
            )
        }

        guard let personB = PeopleStore.shared.getPersonByName(args.person_b_name) else {
            let result: [String: Any] = [
                "success": false,
                "message": "Person '\(args.person_b_name)' not found"
            ]
            let resultData = try JSONSerialization.data(withJSONObject: result)
            return ToolResult(
                toolCallId: toolCall.id,
                result: String(data: resultData, encoding: .utf8) ?? "{}",
                success: false
            )
        }

        let connectionType = ConnectionType(rawValue: args.connection_type ?? "known") ?? .known
        let success = PeopleStore.shared.addConnection(
            personAId: personA.id,
            personBId: personB.id,
            context: args.context,
            type: connectionType
        )

        let result: [String: Any] = [
            "success": success,
            "message": success ? "Connection created between '\(args.person_a_name)' and '\(args.person_b_name)'" : "Failed to create connection"
        ]

        let resultData = try JSONSerialization.data(withJSONObject: result)
        return ToolResult(
            toolCallId: toolCall.id,
            result: String(data: resultData, encoding: .utf8) ?? "{}",
            success: success
        )
    }

    private func executeGetNetwork(_ toolCall: ToolCall) async throws -> ToolResult {
        let args = parseArguments(toolCall.arguments, as: GetNetworkArgs.self)

        var people = PeopleStore.shared.people

        // Filter by tag if specified
        if let filterTag = args?.filter_tag, !filterTag.isEmpty {
            people = people.filter { $0.tags.contains(filterTag) }
        }

        let stats = PeopleStore.shared.getStats()

        let peopleList = people.prefix(50).map { person -> [String: Any] in
            var dict: [String: Any] = [
                "id": person.id,
                "name": person.name
            ]
            if !person.tags.isEmpty { dict["tags"] = person.tags }
            if args?.include_connections == true {
                dict["connections"] = person.connections.compactMap { conn -> [String: Any]? in
                    guard let connectedPerson = conn.connectedPerson else { return nil }
                    return [
                        "person_name": connectedPerson.name,
                        "type": conn.connectionType.rawValue,
                        "context": conn.context ?? ""
                    ]
                }
            }
            return dict
        }

        let result: [String: Any] = [
            "total_people": stats.peopleCount,
            "total_connections": stats.connectionCount,
            "total_organizations": stats.orgCount,
            "total_tags": stats.tagCount,
            "people": peopleList
        ]

        let resultData = try JSONSerialization.data(withJSONObject: result)
        return ToolResult(
            toolCallId: toolCall.id,
            result: String(data: resultData, encoding: .utf8) ?? "{}",
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

// People/CRM Argument Types

struct SearchPeopleArgs: Codable {
    let query: String
}

struct AddPersonArgs: Codable {
    let name: String
    let email: String?
    let phone: String?
    let one_liner: String?
    let notes: String?
    let linkedin: String?
    let location: String?
    let current_city: String?
    let tags: [String]?
}

struct UpdatePersonArgs: Codable {
    let id: String?          // ID of person to update (preferred)
    let name: String?        // Name to search for if ID not provided
    let new_name: String?    // New name to set
    let email: String?
    let phone: String?
    let one_liner: String?
    let notes: String?
    let linkedin: String?
    let location: String?
    let current_city: String?
    let tags: [String]?
}

struct AddConnectionArgs: Codable {
    let person_a_name: String
    let person_b_name: String
    let context: String?
    let connection_type: String?
}

struct GetNetworkArgs: Codable {
    let filter_tag: String?
    let include_connections: Bool?
}
