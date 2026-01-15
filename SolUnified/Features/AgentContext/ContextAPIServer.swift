//
//  ContextAPIServer.swift
//  SolUnified v2.0
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
//    GET /stats           - Today's statistics
//    GET /health          - Server health check
//    GET /calendar/events - Calendar events for a date
//    GET /objective       - Current objective
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
        case "/objective":
            return handleObjectiveRequest()
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
            "version": "2.0"
        ]

        // Current objective
        if let objective = ObjectiveStore.shared.currentObjective {
            response["objective"] = [
                "id": objective.id,
                "text": objective.text,
                "start_time": dateFormatter.string(from: objective.startTime),
                "duration_minutes": Int(objective.duration / 60),
                "is_paused": objective.isPaused
            ]
        }

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

        // Objective stats
        let objectiveResults = db.query(
            "SELECT COUNT(*) as count FROM objectives WHERE start_time > ?",
            parameters: [todayStr]
        )
        let objectiveCount = objectiveResults.first?["count"] as? Int ?? 0

        return httpResponse(status: 200, body: [
            "date": ISO8601DateFormatter().string(from: today),
            "clipboard_items": clipboardCount,
            "activity_events": activityCount,
            "context_sessions": contextCount,
            "objectives_today": objectiveCount,
            "average_focus": Int(avgFocus * 100)
        ])
    }

    private func handleHealthRequest() -> String {
        return httpResponse(status: 200, body: [
            "status": "ok",
            "version": "2.0",
            "uptime_requests": requestCount,
            "timestamp": dateFormatter.string(from: Date())
        ])
    }

    private func handleCalendarEventsRequest(date: String) -> String {
        // Parse the date parameter
        let targetDate: Date
        if let parsed = ISO8601DateFormatter().date(from: date) {
            targetDate = parsed
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let parsed = formatter.date(from: date) {
                targetDate = parsed
            } else {
                targetDate = Date()
            }
        }

        // Fetch events synchronously
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

    private func handleObjectiveRequest() -> String {
        if let objective = ObjectiveStore.shared.currentObjective {
            return httpResponse(status: 200, body: [
                "active": true,
                "objective": [
                    "id": objective.id,
                    "text": objective.text,
                    "start_time": dateFormatter.string(from: objective.startTime),
                    "duration_minutes": Int(objective.duration / 60),
                    "duration_formatted": objective.formattedDuration,
                    "is_paused": objective.isPaused
                ]
            ])
        } else {
            return httpResponse(status: 200, body: [
                "active": false,
                "objective": nil as String?
            ])
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
