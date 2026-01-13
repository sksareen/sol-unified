//
//  ContextAPIServer.swift
//  SolUnified
//
//  Local HTTP API server for real-time context access.
//  Any Claude Code agent can query http://localhost:7654/context
//
//  Endpoints:
//    GET /context         - Current work context summary
//    GET /clipboard       - Recent clipboard items
//    GET /activity        - Recent activity events
//    GET /contexts        - All recent contexts
//    GET /search?q=TERM   - Search across all context
//    GET /health          - Server health check
//

import Foundation
import Network

class ContextAPIServer: ObservableObject {
    static let shared = ContextAPIServer()
    
    @Published var isRunning = false
    @Published var port: UInt16 = 7654
    @Published var requestCount: Int = 0
    
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.solunified.apiserver")
    
    private let db = Database.shared
    private let contextGraph = ContextGraphManager.shared
    private let clipboardStore = ClipboardStore.shared
    private let contextExporter = ContextExporter.shared
    
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    private init() {}
    
    // MARK: - Server Lifecycle
    
    func start(port: UInt16 = 7654) {
        guard !isRunning else { return }
        
        self.port = port
        
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            
            listener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: port))
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        print("🌐 Context API server running on http://localhost:\(port)")
                    case .failed(let error):
                        print("❌ Context API server failed: \(error)")
                        self?.isRunning = false
                    case .cancelled:
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: queue)
            
        } catch {
            print("❌ Failed to start Context API server: \(error)")
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        print("🌐 Context API server stopped")
    }
    
    // MARK: - Connection Handling
    
    private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                self.receiveRequest(on: connection)
            case .failed, .cancelled:
                connection.cancel()
            default:
                break
            }
        }
        
        connection.start(queue: queue)
    }
    
    private func receiveRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self = self else { return }
            
            if let error = error {
                print("⚠️ Request receive error: \(error)")
                connection.cancel()
                return
            }
            
            guard let data = data, !data.isEmpty else {
                connection.cancel()
                return
            }
            
            let request = String(data: data, encoding: .utf8) ?? ""
            let response = self.handleRequest(request)
            
            self.sendResponse(response, on: connection)
        }
    }
    
    private func sendResponse(_ response: String, on connection: NWConnection) {
        let responseData = response.data(using: .utf8) ?? Data()
        
        connection.send(content: responseData, completion: .contentProcessed { error in
            if let error = error {
                print("⚠️ Response send error: \(error)")
            }
            connection.cancel()
        })
    }
    
    // MARK: - Request Routing
    
    private func handleRequest(_ request: String) -> String {
        // Parse HTTP request
        let lines = request.split(separator: "\r\n")
        guard let firstLine = lines.first else {
            return httpResponse(status: 400, body: ["error": "Invalid request"])
        }
        
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else {
            return httpResponse(status: 400, body: ["error": "Invalid request"])
        }
        
        let method = String(parts[0])
        let pathWithQuery = String(parts[1])
        
        // Parse path and query
        let pathComponents = pathWithQuery.split(separator: "?", maxSplits: 1)
        let path = String(pathComponents[0])
        let query = pathComponents.count > 1 ? parseQueryString(String(pathComponents[1])) : [:]
        
        DispatchQueue.main.async {
            self.requestCount += 1
        }
        
        // Route request based on method
        if method == "POST" {
            // Parse body from request
            let bodyStartIndex = request.range(of: "\r\n\r\n")?.upperBound ?? request.startIndex
            let body = String(request[bodyStartIndex...])
            return handlePostRequest(path: path, body: body)
        }

        if method == "PUT" {
            // Parse body from request
            let bodyStartIndex = request.range(of: "\r\n\r\n")?.upperBound ?? request.startIndex
            let body = String(request[bodyStartIndex...])
            return handlePutRequest(path: path, body: body)
        }

        guard method == "GET" else {
            return httpResponse(status: 405, body: ["error": "Method not allowed"])
        }

        switch path {
        case "/", "/context":
            return handleContextRequest()
        case "/clipboard":
            let limit = Int(query["limit"] ?? "10") ?? 10
            let app = query["app"]
            return handleClipboardRequest(limit: limit, app: app)
        case "/activity":
            let hours = Int(query["hours"] ?? "4") ?? 4
            return handleActivityRequest(hours: hours)
        case "/contexts":
            let hours = Int(query["hours"] ?? "24") ?? 24
            return handleContextsRequest(hours: hours)
        case "/search":
            guard let q = query["q"], !q.isEmpty else {
                return httpResponse(status: 400, body: ["error": "Missing query parameter 'q'"])
            }
            return handleSearchRequest(query: q)
        case "/stats":
            return handleStatsRequest()
        case "/health":
            return handleHealthRequest()
        case "/calendar/events":
            let dateStr = query["date"] ?? ISO8601DateFormatter().string(from: Date())
            return handleCalendarEventsRequest(date: dateStr)
        case "/people/search":
            guard let q = query["q"], !q.isEmpty else {
                return httpResponse(status: 400, body: ["error": "Missing query parameter 'q'"])
            }
            let fuzzy = query["fuzzy"] != "false"
            return handlePeopleSearchRequest(query: q, fuzzy: fuzzy)
        case "/agent/actions":
            let status = query["status"]
            return handleGetActionsRequest(status: status)
        default:
            return httpResponse(status: 404, body: ["error": "Not found", "path": path])
        }
    }
    
    private func parseQueryString(_ query: String) -> [String: String] {
        var result: [String: String] = [:]
        let pairs = query.split(separator: "&")
        for pair in pairs {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2 {
                let key = String(kv[0]).removingPercentEncoding ?? String(kv[0])
                let value = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                result[key] = value
            }
        }
        return result
    }
    
    // MARK: - Endpoint Handlers
    
    private func handleContextRequest() -> String {
        var response: [String: Any] = [
            "generated_at": dateFormatter.string(from: Date()),
            "version": "1.0"
        ]
        
        // Active context
        if let active = contextGraph.activeContext {
            response["active_context"] = [
                "id": active.id,
                "label": active.label,
                "type": active.type.rawValue,
                "start_time": dateFormatter.string(from: active.startTime),
                "duration_minutes": Int(active.duration / 60),
                "focus_score": round(active.focusScore * 100) / 100,
                "apps": Array(active.apps),
                "event_count": active.eventCount
            ]
        }
        
        // Recent clipboard (last 5)
        let recentClipboard = clipboardStore.items.prefix(5).map { item -> [String: Any] in
            return [
                "content_preview": truncate(item.contentPreview ?? item.contentText, maxLength: 100) ?? "",
                "source_app": item.sourceAppName ?? "unknown",
                "timestamp": dateFormatter.string(from: item.createdAt)
            ]
        }
        response["recent_clipboard"] = recentClipboard
        
        // Activity summary
        let oneHourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date()
        let cutoffStr = Database.dateToString(oneHourAgo)
        
        let activityResults = db.query("""
            SELECT app_name, COUNT(*) as count
            FROM activity_log
            WHERE timestamp > ? AND app_name IS NOT NULL
            GROUP BY app_name
            ORDER BY count DESC
            LIMIT 5
        """, parameters: [cutoffStr])
        
        let topApps = activityResults.compactMap { $0["app_name"] as? String }
        let totalEvents = activityResults.reduce(0) { $0 + ($1["count"] as? Int ?? 0) }
        
        response["activity_summary"] = [
            "last_hour_events": totalEvents,
            "top_apps": topApps
        ]
        
        return httpResponse(status: 200, body: response)
    }
    
    private func handleClipboardRequest(limit: Int, app: String?) -> String {
        var items: [[String: Any]] = []
        
        let filtered: [ClipboardItem]
        if let app = app {
            filtered = Array(clipboardStore.items.filter { 
                ($0.sourceAppName ?? "").localizedCaseInsensitiveContains(app)
            }.prefix(limit))
        } else {
            filtered = Array(clipboardStore.items.prefix(limit))
        }
        
        for item in filtered {
            items.append([
                "content": truncate(item.contentText, maxLength: 500) ?? "",
                "content_type": item.contentType.rawValue,
                "source_app": item.sourceAppName ?? "unknown",
                "source_window": truncate(item.sourceWindowTitle, maxLength: 100) ?? "",
                "timestamp": dateFormatter.string(from: item.createdAt)
            ])
        }
        
        return httpResponse(status: 200, body: ["items": items, "count": items.count])
    }
    
    private func handleActivityRequest(hours: Int) -> String {
        let cutoff = Calendar.current.date(byAdding: .hour, value: -hours, to: Date()) ?? Date()
        let cutoffStr = Database.dateToString(cutoff)
        
        let results = db.query("""
            SELECT app_name, window_title, event_type, timestamp
            FROM activity_log
            WHERE timestamp > ? AND app_name IS NOT NULL
            ORDER BY timestamp DESC
            LIMIT 100
        """, parameters: [cutoffStr])
        
        let events = results.map { row -> [String: Any] in
            return [
                "app": row["app_name"] as? String ?? "",
                "window": truncate(row["window_title"] as? String, maxLength: 100) ?? "",
                "event_type": row["event_type"] as? String ?? "",
                "timestamp": row["timestamp"] as? String ?? ""
            ]
        }
        
        return httpResponse(status: 200, body: ["events": events, "hours": hours])
    }
    
    private func handleContextsRequest(hours: Int) -> String {
        let contexts = contextGraph.getRecentContexts(hours: hours)
        
        let contextList = contexts.map { ctx -> [String: Any] in
            return [
                "id": ctx.id,
                "label": ctx.label,
                "type": ctx.type.rawValue,
                "start_time": dateFormatter.string(from: ctx.startTime),
                "end_time": ctx.endTime.map { dateFormatter.string(from: $0) } as Any,
                "duration_minutes": Int(ctx.duration / 60),
                "focus_score": round(ctx.focusScore * 100) / 100,
                "apps": Array(ctx.apps),
                "event_count": ctx.eventCount,
                "is_active": ctx.isActive
            ]
        }
        
        return httpResponse(status: 200, body: ["contexts": contextList, "hours": hours])
    }
    
    private func handleSearchRequest(query: String) -> String {
        var results: [[String: Any]] = []
        let pattern = "%\(query)%"
        
        // Search clipboard
        let clipboardResults = db.query("""
            SELECT 'clipboard' as type, content_preview as content, source_app_name as source, created_at
            FROM clipboard_history
            WHERE content_text LIKE ? OR content_preview LIKE ?
            ORDER BY created_at DESC
            LIMIT 10
        """, parameters: [pattern, pattern])
        
        for row in clipboardResults {
            results.append([
                "type": "clipboard",
                "content": truncate(row["content"] as? String, maxLength: 200) ?? "",
                "source": row["source"] as? String ?? "",
                "timestamp": row["created_at"] as? String ?? ""
            ])
        }
        
        // Search activity
        let activityResults = db.query("""
            SELECT 'activity' as type, window_title as content, app_name as source, timestamp
            FROM activity_log
            WHERE window_title LIKE ?
            ORDER BY timestamp DESC
            LIMIT 10
        """, parameters: [pattern])
        
        for row in activityResults {
            results.append([
                "type": "activity",
                "content": truncate(row["content"] as? String, maxLength: 200) ?? "",
                "source": row["source"] as? String ?? "",
                "timestamp": row["timestamp"] as? String ?? ""
            ])
        }
        
        // Sort by timestamp
        results.sort { 
            ($0["timestamp"] as? String ?? "") > ($1["timestamp"] as? String ?? "")
        }
        
        return httpResponse(status: 200, body: ["query": query, "results": Array(results.prefix(20))])
    }
    
    private func handleStatsRequest() -> String {
        let today = Calendar.current.startOfDay(for: Date())
        let todayStr = Database.dateToString(today)
        
        // Get counts
        let clipboardResults = db.query(
            "SELECT COUNT(*) as count FROM clipboard_history WHERE created_at > ?",
            parameters: [todayStr]
        )
        let clipboardCount = clipboardResults.first?["count"] as? Int ?? 0
        
        let activityResults = db.query(
            "SELECT COUNT(*) as count FROM activity_log WHERE timestamp > ?",
            parameters: [todayStr]
        )
        let activityCount = activityResults.first?["count"] as? Int ?? 0
        
        let contextResults = db.query(
            "SELECT COUNT(*) as count FROM context_nodes WHERE start_time > ?",
            parameters: [todayStr]
        )
        let contextCount = contextResults.first?["count"] as? Int ?? 0
        
        // Average focus
        let focusResults = db.query(
            "SELECT AVG(focus_score) as avg FROM context_nodes WHERE start_time > ?",
            parameters: [todayStr]
        )
        let avgFocus = focusResults.first?["avg"] as? Double ?? 0
        
        return httpResponse(status: 200, body: [
            "date": ISO8601DateFormatter().string(from: today),
            "clipboard_items": clipboardCount,
            "activity_events": activityCount,
            "context_sessions": contextCount,
            "average_focus": Int(avgFocus * 100)
        ])
    }
    
    private func handleHealthRequest() -> String {
        return httpResponse(status: 200, body: [
            "status": "ok",
            "uptime_requests": requestCount,
            "timestamp": dateFormatter.string(from: Date())
        ])
    }

    // MARK: - Calendar Events Handler

    private func handleCalendarEventsRequest(date: String) -> String {
        // Parse the date parameter
        let targetDate: Date
        if let parsed = ISO8601DateFormatter().date(from: date) {
            targetDate = parsed
        } else {
            // Try simple date format
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let parsed = formatter.date(from: date) {
                targetDate = parsed
            } else {
                targetDate = Date()
            }
        }

        // Fetch events synchronously using semaphore (API server runs on background queue)
        var events: [[String: Any]] = []
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            let calendarEvents = await CalendarStore.shared.getEvents(for: targetDate)
            events = calendarEvents.map { event -> [String: Any] in
                return [
                    "id": event.id,
                    "title": event.title,
                    "start": self.dateFormatter.string(from: event.startDate),
                    "end": self.dateFormatter.string(from: event.endDate),
                    "location": event.location ?? "",
                    "attendees": event.attendees,
                    "calendar": event.calendarName,
                    "is_all_day": event.isAllDay,
                    "is_external": event.isExternal
                ]
            }
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 5)

        return httpResponse(status: 200, body: [
            "date": date,
            "events": events,
            "count": events.count
        ])
    }

    // MARK: - People Search Handler

    private func handlePeopleSearchRequest(query: String, fuzzy: Bool) -> String {
        let allPeople = PeopleStore.shared.people

        // Filter people by name
        let matches: [Person]
        if fuzzy {
            matches = allPeople.filter {
                $0.name.localizedCaseInsensitiveContains(query)
            }
        } else {
            matches = allPeople.filter {
                $0.name.localizedCaseInsensitiveCompare(query) == .orderedSame
            }
        }

        let people = matches.prefix(10).map { person -> [String: Any] in
            var result: [String: Any] = [
                "id": person.id,
                "name": person.name
            ]

            if let oneLiner = person.oneLiner {
                result["one_liner"] = oneLiner
            }
            if let notes = person.notes {
                result["notes"] = truncate(notes, maxLength: 500) ?? ""
            }
            if let email = person.email {
                result["email"] = email
            }
            if let linkedin = person.linkedin {
                result["linkedin"] = linkedin
            }
            if let location = person.currentCity ?? person.location {
                result["location"] = location
            }
            if !person.tags.isEmpty {
                result["tags"] = person.tags
            }
            if !person.organizations.isEmpty {
                result["organizations"] = person.organizations.compactMap { personOrg -> [String: Any]? in
                    guard let org = personOrg.organization else { return nil }
                    var orgData: [String: Any] = [
                        "name": org.name
                    ]
                    if let role = personOrg.role {
                        orgData["role"] = role
                    }
                    if personOrg.isCurrent {
                        orgData["is_current"] = true
                    }
                    return orgData
                }
            }

            return result
        }

        return httpResponse(status: 200, body: [
            "query": query,
            "found": !people.isEmpty,
            "people": Array(people),
            "count": people.count
        ])
    }

    // MARK: - Agent Actions GET Handler

    private func handleGetActionsRequest(status: String?) -> String {
        // Use semaphore to safely access MainActor property
        var actions: [[String: Any]] = []
        var pendingCount = 0
        let semaphore = DispatchSemaphore(value: 0)

        DispatchQueue.main.async {
            let allActions = AgentActionStore.shared.actions

            let filtered: [AgentAction]
            if let statusFilter = status {
                if let targetStatus = AgentActionStatus(rawValue: statusFilter) {
                    filtered = allActions.filter { $0.status == targetStatus }
                } else {
                    filtered = allActions
                }
            } else {
                filtered = allActions
            }

            actions = filtered.prefix(50).map { action -> [String: Any] in
                var result: [String: Any] = [
                    "id": action.id,
                    "type": action.type.rawValue,
                    "title": action.title,
                    "summary": action.summary,
                    "status": action.status.rawValue,
                    "created_at": self.dateFormatter.string(from: action.createdAt)
                ]

                if let details = action.details {
                    result["details"] = details
                }
                if let draftContent = action.draftContent {
                    result["draft_content"] = self.truncate(draftContent, maxLength: 1000) ?? ""
                }
                if let eventId = action.relatedEventId {
                    result["related_event_id"] = eventId
                }
                if let eventTitle = action.relatedEventTitle {
                    result["related_event_title"] = eventTitle
                }
                if let actionUrl = action.actionUrl {
                    result["action_url"] = actionUrl
                }
                if let reviewedAt = action.reviewedAt {
                    result["reviewed_at"] = self.dateFormatter.string(from: reviewedAt)
                }

                return result
            }

            pendingCount = allActions.filter { $0.status == .pending }.count
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 5)

        return httpResponse(status: 200, body: [
            "actions": actions,
            "count": actions.count,
            "pending_count": pendingCount
        ])
    }

    // MARK: - POST Request Handler

    private func handlePostRequest(path: String, body: String) -> String {
        switch path {
        case "/agent/actions":
            return handleCreateAction(body: body)
        case "/people":
            return handleCreatePerson(body: body)
        default:
            return httpResponse(status: 404, body: ["error": "POST endpoint not found", "path": path])
        }
    }

    // MARK: - PUT Request Handler

    private func handlePutRequest(path: String, body: String) -> String {
        // Match /people/{id} pattern
        if path.hasPrefix("/people/") {
            let personId = String(path.dropFirst("/people/".count))
            if !personId.isEmpty && !personId.contains("/") {
                return handleUpdatePerson(id: personId, body: body)
            }
        }
        return httpResponse(status: 404, body: ["error": "PUT endpoint not found", "path": path])
    }

    private func handleCreateAction(body: String) -> String {
        guard let data = body.data(using: .utf8) else {
            return httpResponse(status: 400, body: ["error": "Invalid request body"])
        }

        // Expected JSON structure:
        // {
        //   "type": "meeting_brief" | "linkedin_draft" | "email_draft" | "research_summary" | "reminder" | "other",
        //   "title": "Meeting with Acme Corp",
        //   "summary": "Brief description",
        //   "details": "Full details (optional)",
        //   "related_event_id": "event-id (optional)",
        //   "related_event_title": "Calendar event title (optional)",
        //   "draft_content": "The actual draft message/brief (optional)",
        //   "action_url": "URL to open when user clicks action (optional)"
        // }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return httpResponse(status: 400, body: ["error": "Invalid JSON"])
            }

            guard let typeStr = json["type"] as? String,
                  let type = AgentActionType(rawValue: typeStr),
                  let title = json["title"] as? String,
                  let summary = json["summary"] as? String else {
                return httpResponse(status: 400, body: ["error": "Missing required fields: type, title, summary"])
            }

            let action = AgentAction(
                type: type,
                title: title,
                summary: summary,
                details: json["details"] as? String,
                relatedEventId: json["related_event_id"] as? String,
                relatedEventTitle: json["related_event_title"] as? String,
                draftContent: json["draft_content"] as? String,
                actionUrl: json["action_url"] as? String
            )

            // Add to store (runs on main thread)
            DispatchQueue.main.async {
                AgentActionStore.shared.addAction(action)
            }

            return httpResponse(status: 201, body: [
                "success": true,
                "action_id": action.id,
                "message": "Action created successfully"
            ])

        } catch {
            return httpResponse(status: 400, body: ["error": "JSON parsing error: \(error.localizedDescription)"])
        }
    }

    // MARK: - Create Person Handler

    private func handleCreatePerson(body: String) -> String {
        guard let data = body.data(using: .utf8) else {
            return httpResponse(status: 400, body: ["error": "Invalid request body"])
        }

        // Expected JSON structure:
        // {
        //   "name": "John Doe" (required),
        //   "one_liner": "CEO at Acme Corp",
        //   "notes": "Met at conference...",
        //   "email": "john@example.com",
        //   "phone": "+1234567890",
        //   "linkedin": "https://linkedin.com/in/johndoe",
        //   "location": "San Francisco, CA",
        //   "current_city": "San Francisco",
        //   "tags": ["investor", "tech"]
        // }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return httpResponse(status: 400, body: ["error": "Invalid JSON"])
            }

            guard let name = json["name"] as? String, !name.isEmpty else {
                return httpResponse(status: 400, body: ["error": "Missing required field: name"])
            }

            // Create Person object
            var person = Person(name: name)
            person.oneLiner = json["one_liner"] as? String
            person.notes = json["notes"] as? String
            person.email = json["email"] as? String
            person.phone = json["phone"] as? String
            person.linkedin = json["linkedin"] as? String
            person.location = json["location"] as? String
            person.currentCity = json["current_city"] as? String
            person.boardPriority = json["board_priority"] as? String

            if let tags = json["tags"] as? [String] {
                person.tags = tags
            }

            // Save using semaphore for main thread access
            var success = false
            let semaphore = DispatchSemaphore(value: 0)

            DispatchQueue.main.async {
                success = PeopleStore.shared.savePerson(person)
                semaphore.signal()
            }

            _ = semaphore.wait(timeout: .now() + 5)

            if success {
                return httpResponse(status: 201, body: [
                    "success": true,
                    "person_id": person.id,
                    "message": "Contact created successfully"
                ])
            } else {
                return httpResponse(status: 500, body: ["error": "Failed to save contact"])
            }

        } catch {
            return httpResponse(status: 400, body: ["error": "JSON parsing error: \(error.localizedDescription)"])
        }
    }

    // MARK: - Update Person Handler

    private func handleUpdatePerson(id: String, body: String) -> String {
        guard let data = body.data(using: .utf8) else {
            return httpResponse(status: 400, body: ["error": "Invalid request body"])
        }

        // Expected JSON structure (all fields optional, only provided fields are updated):
        // {
        //   "name": "John Doe",
        //   "one_liner": "CEO at Acme Corp",
        //   "notes": "Updated notes...",
        //   "email": "john@example.com",
        //   "phone": "+1234567890",
        //   "linkedin": "https://linkedin.com/in/johndoe",
        //   "location": "San Francisco, CA",
        //   "current_city": "San Francisco",
        //   "tags": ["investor", "tech"]
        // }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return httpResponse(status: 400, body: ["error": "Invalid JSON"])
            }

            // Find existing person using semaphore
            var existingPerson: Person?
            let semaphore = DispatchSemaphore(value: 0)

            DispatchQueue.main.async {
                existingPerson = PeopleStore.shared.getPerson(id: id)
                semaphore.signal()
            }

            _ = semaphore.wait(timeout: .now() + 5)

            guard var person = existingPerson else {
                return httpResponse(status: 404, body: ["error": "Contact not found", "id": id])
            }

            // Update fields if provided
            if let name = json["name"] as? String, !name.isEmpty {
                person.name = name
            }
            if let oneLiner = json["one_liner"] as? String {
                person.oneLiner = oneLiner.isEmpty ? nil : oneLiner
            }
            if let notes = json["notes"] as? String {
                person.notes = notes.isEmpty ? nil : notes
            }
            if let email = json["email"] as? String {
                person.email = email.isEmpty ? nil : email
            }
            if let phone = json["phone"] as? String {
                person.phone = phone.isEmpty ? nil : phone
            }
            if let linkedin = json["linkedin"] as? String {
                person.linkedin = linkedin.isEmpty ? nil : linkedin
            }
            if let location = json["location"] as? String {
                person.location = location.isEmpty ? nil : location
            }
            if let currentCity = json["current_city"] as? String {
                person.currentCity = currentCity.isEmpty ? nil : currentCity
            }
            if let boardPriority = json["board_priority"] as? String {
                person.boardPriority = boardPriority.isEmpty ? nil : boardPriority
            }
            if let tags = json["tags"] as? [String] {
                person.tags = tags
            }

            // Update timestamp
            person.updatedAt = Date()

            // Save using semaphore for main thread access
            var success = false
            let saveSemaphore = DispatchSemaphore(value: 0)

            DispatchQueue.main.async {
                success = PeopleStore.shared.savePerson(person)
                saveSemaphore.signal()
            }

            _ = saveSemaphore.wait(timeout: .now() + 5)

            if success {
                return httpResponse(status: 200, body: [
                    "success": true,
                    "person_id": person.id,
                    "message": "Contact updated successfully"
                ])
            } else {
                return httpResponse(status: 500, body: ["error": "Failed to update contact"])
            }

        } catch {
            return httpResponse(status: 400, body: ["error": "JSON parsing error: \(error.localizedDescription)"])
        }
    }

    // MARK: - Helpers
    
    private func httpResponse(status: Int, body: [String: Any]) -> String {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 201: statusText = "Created"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 405: statusText = "Method Not Allowed"
        default: statusText = "Error"
        }
        
        let jsonData = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
        let jsonString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        
        return """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: application/json\r
        Access-Control-Allow-Origin: *\r
        Content-Length: \(jsonString.utf8.count)\r
        Connection: close\r
        \r
        \(jsonString)
        """
    }
    
    private func truncate(_ string: String?, maxLength: Int) -> String? {
        guard let string = string else { return nil }
        if string.count <= maxLength { return string }
        return String(string.prefix(maxLength - 3)) + "..."
    }
}

