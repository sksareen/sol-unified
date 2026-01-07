//
//  CalendarAction.swift
//  SolUnified
//
//  EventKit integration for calendar operations
//

import Foundation
import EventKit

class CalendarActionExecutor {

    private let eventStore = EKEventStore()
    private var hasAccess = false

    // MARK: - Access Request

    func requestAccess() async throws -> Bool {
        if hasAccess {
            return true
        }

        let granted: Bool
        if #available(macOS 14.0, *) {
            granted = try await eventStore.requestFullAccessToEvents()
        } else {
            granted = try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }

        hasAccess = granted
        return granted
    }

    // MARK: - Check Availability

    func checkAvailability(_ toolCall: ToolCall) async throws -> ToolResult {
        guard try await requestAccess() else {
            return ToolResult(
                toolCallId: toolCall.id,
                result: "{\"error\": \"Calendar access denied. Please grant calendar permission in System Settings.\"}",
                success: false
            )
        }

        guard let args = parseArguments(toolCall.arguments, as: CheckCalendarArgs.self) else {
            return ToolResult(
                toolCallId: toolCall.id,
                result: "{\"error\": \"Invalid arguments for check_calendar\"}",
                success: false
            )
        }

        guard let startDate = parseDate(args.startDate),
              let endDate = parseDate(args.endDate) else {
            return ToolResult(
                toolCallId: toolCall.id,
                result: "{\"error\": \"Invalid date format. Use ISO 8601 format.\"}",
                success: false
            )
        }

        // Get events in the range
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)

        // Build busy slots
        let busySlots = events.map { event -> [String: String] in
            return [
                "start": ISO8601DateFormatter().string(from: event.startDate),
                "end": ISO8601DateFormatter().string(from: event.endDate),
                "title": event.title ?? "Busy"
            ]
        }

        // Calculate free slots (simple implementation)
        let freeSlots = calculateFreeSlots(
            busyEvents: events,
            startDate: startDate,
            endDate: endDate
        )

        let result: [String: Any] = [
            "date_range": [
                "start": args.startDate,
                "end": args.endDate
            ],
            "busy_slots": busySlots,
            "free_slots": freeSlots,
            "total_events": events.count
        ]

        let resultData = try JSONSerialization.data(withJSONObject: result)
        let resultStr = String(data: resultData, encoding: .utf8) ?? "{}"

        return ToolResult(
            toolCallId: toolCall.id,
            result: resultStr,
            success: true
        )
    }

    // MARK: - Create Event

    func createEvent(_ toolCall: ToolCall) async throws -> ToolResult {
        guard try await requestAccess() else {
            return ToolResult(
                toolCallId: toolCall.id,
                result: "{\"error\": \"Calendar access denied. Please grant calendar permission in System Settings.\"}",
                success: false
            )
        }

        guard let args = parseArguments(toolCall.arguments, as: CreateEventArgs.self) else {
            return ToolResult(
                toolCallId: toolCall.id,
                result: "{\"error\": \"Invalid arguments for create_calendar_event\"}",
                success: false
            )
        }

        guard let startTime = parseDate(args.startTime) else {
            return ToolResult(
                toolCallId: toolCall.id,
                result: "{\"error\": \"Invalid start_time format. Use ISO 8601 format.\"}",
                success: false
            )
        }

        // Create the event
        let event = EKEvent(eventStore: eventStore)
        event.title = args.title
        event.startDate = startTime
        event.endDate = startTime.addingTimeInterval(TimeInterval(args.durationMinutes * 60))

        if let location = args.location {
            event.location = location
        }

        // Set calendar (use default if available)
        if let defaultCalendar = eventStore.defaultCalendarForNewEvents {
            event.calendar = defaultCalendar
        } else {
            // Find first writable calendar
            let calendars = eventStore.calendars(for: .event)
            if let writableCalendar = calendars.first(where: { $0.allowsContentModifications }) {
                event.calendar = writableCalendar
            } else {
                return ToolResult(
                    toolCallId: toolCall.id,
                    result: "{\"error\": \"No writable calendar found.\"}",
                    success: false
                )
            }
        }

        // Add attendees if provided (note: adding attendees may not work without server-based calendar)
        // This is a limitation of EventKit on macOS
        if let attendees = args.attendees, !attendees.isEmpty {
            // EventKit doesn't allow directly setting attendees on local calendars
            // The attendees would need to be invited through the calendar server
            // For now, we'll note this in the result
        }

        do {
            try eventStore.save(event, span: .thisEvent)

            var result: [String: Any] = [
                "success": true,
                "event_id": event.eventIdentifier ?? "unknown",
                "title": args.title,
                "start": args.startTime,
                "end": ISO8601DateFormatter().string(from: event.endDate),
                "calendar": event.calendar.title
            ]

            if let location = args.location {
                result["location"] = location
            }

            if let attendees = args.attendees, !attendees.isEmpty {
                result["note"] = "Attendees (\(attendees.joined(separator: ", "))) noted but automatic invites require a server-based calendar."
            }

            let resultData = try JSONSerialization.data(withJSONObject: result)
            let resultStr = String(data: resultData, encoding: .utf8) ?? "{}"

            return ToolResult(
                toolCallId: toolCall.id,
                result: resultStr,
                success: true
            )

        } catch {
            return ToolResult(
                toolCallId: toolCall.id,
                result: "{\"error\": \"Failed to save event: \(error.localizedDescription)\"}",
                success: false
            )
        }
    }

    // MARK: - Helpers

    private func parseDate(_ dateString: String) -> Date? {
        // Try ISO 8601 first
        let iso8601 = ISO8601DateFormatter()
        if let date = iso8601.date(from: dateString) {
            return date
        }

        // Try common date formats
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd HH:mm"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                return f
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        // Try natural language parsing
        return parseNaturalDate(dateString)
    }

    private func parseNaturalDate(_ string: String) -> Date? {
        let lowercased = string.lowercased()
        let calendar = Calendar.current
        let now = Date()

        if lowercased == "today" {
            return calendar.startOfDay(for: now)
        } else if lowercased == "tomorrow" {
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        } else if lowercased.contains("next week") {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: now)
        }

        // Try to parse weekday names
        let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        for (index, day) in weekdays.enumerated() {
            if lowercased.contains(day) {
                let targetWeekday = index + 1  // Calendar weekdays are 1-indexed
                var components = calendar.dateComponents([.weekday], from: now)
                let currentWeekday = components.weekday ?? 1

                var daysToAdd = targetWeekday - currentWeekday
                if daysToAdd <= 0 {
                    daysToAdd += 7  // Next occurrence
                }

                return calendar.date(byAdding: .day, value: daysToAdd, to: calendar.startOfDay(for: now))
            }
        }

        return nil
    }

    private func calculateFreeSlots(busyEvents: [EKEvent], startDate: Date, endDate: Date) -> [[String: String]] {
        var freeSlots: [[String: String]] = []
        let calendar = Calendar.current

        // Sort events by start time
        let sortedEvents = busyEvents.sorted { $0.startDate < $1.startDate }

        // Define working hours (9 AM to 6 PM)
        let workingHoursStart = 9
        let workingHoursEnd = 18

        var currentDate = startDate
        let dateFormatter = ISO8601DateFormatter()

        while currentDate < endDate {
            // Get start of working day
            var workDayStart = calendar.date(bySettingHour: workingHoursStart, minute: 0, second: 0, of: currentDate) ?? currentDate
            let workDayEnd = calendar.date(bySettingHour: workingHoursEnd, minute: 0, second: 0, of: currentDate) ?? currentDate

            // Skip weekends
            let weekday = calendar.component(.weekday, from: currentDate)
            if weekday == 1 || weekday == 7 {
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
                continue
            }

            // Find free slots in this day
            let dayEvents = sortedEvents.filter { event in
                event.startDate < workDayEnd && event.endDate > workDayStart
            }

            var slotStart = workDayStart

            for event in dayEvents {
                if event.startDate > slotStart {
                    // Free slot from slotStart to event.startDate
                    let slotEnd = min(event.startDate, workDayEnd)
                    let duration = slotEnd.timeIntervalSince(slotStart) / 60  // in minutes

                    if duration >= 30 {  // Only show slots of 30 mins or more
                        freeSlots.append([
                            "start": dateFormatter.string(from: slotStart),
                            "end": dateFormatter.string(from: slotEnd),
                            "duration_minutes": String(Int(duration))
                        ])
                    }
                }
                slotStart = max(slotStart, event.endDate)
            }

            // Free slot after last event
            if slotStart < workDayEnd {
                let duration = workDayEnd.timeIntervalSince(slotStart) / 60

                if duration >= 30 {
                    freeSlots.append([
                        "start": dateFormatter.string(from: slotStart),
                        "end": dateFormatter.string(from: workDayEnd),
                        "duration_minutes": String(Int(duration))
                    ])
                }
            }

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return freeSlots
    }

    private func parseArguments<T: Decodable>(_ json: String, as type: T.Type) -> T? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Argument Types

struct CheckCalendarArgs: Codable {
    let startDate: String
    let endDate: String

    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

struct CreateEventArgs: Codable {
    let title: String
    let startTime: String
    let durationMinutes: Int
    let location: String?
    let attendees: [String]?

    enum CodingKeys: String, CodingKey {
        case title
        case startTime = "start_time"
        case durationMinutes = "duration_minutes"
        case location
        case attendees
    }
}
