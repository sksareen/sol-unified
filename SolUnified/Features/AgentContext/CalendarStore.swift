//
//  CalendarStore.swift
//  SolUnified
//
//  Calendar data access for the Context API
//

import Foundation
import EventKit
import AppKit

@MainActor
class CalendarStore: ObservableObject {
    static let shared = CalendarStore()

    @Published var todayEvents: [CalendarEvent] = []
    @Published var hasAccess: Bool = false
    @Published var isLoading: Bool = false

    private var hasRequestedAccess: Bool = false  // Prevent repeated requests
    private var hasOpenedSettings: Bool = false   // Prevent spam opening settings

    private var eventStore = EKEventStore()

    private init() {
        // Listen for calendar database changes (sync completion)
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            print("📅 Event store changed - refreshing calendars")
            Task { @MainActor in
                await self?.refreshTodayEvents()
            }
        }

        Task {
            await requestAccess()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Access

    func requestAccess() async {
        // Prevent repeated requests
        guard !hasRequestedAccess else {
            print("📅 Already requested access, skipping...")
            return
        }
        hasRequestedAccess = true

        let status = EKEventStore.authorizationStatus(for: .event)
        print("📅 Calendar authorization status: \(status.rawValue)")

        print("📅 Requesting calendar access...")
        do {
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
            print("📅 Calendar access result: \(granted)")
            hasAccess = granted

            if granted {
                // Check what calendars we can see
                let calendars = eventStore.calendars(for: .event)
                print("📅 After permission - Available calendars: \(calendars.count)")
                for cal in calendars {
                    print("   - \(cal.title) (source: \(cal.source?.title ?? "?"))")
                }
                await refreshTodayEvents()
            } else if !hasOpenedSettings {
                hasOpenedSettings = true
                print("📅 Access denied. Opening System Settings (once)...")
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
        } catch {
            print("📅 Calendar access error: \(error)")
            hasAccess = false
        }
    }

    /// Call this when user manually clicks refresh after granting permission
    func retryAccess() async {
        hasRequestedAccess = false
        hasOpenedSettings = false
        await requestAccess()
    }

    // MARK: - Fetch Events

    func resetEventStore() {
        print("📅 Resetting event store...")
        eventStore.reset()
        eventStore = EKEventStore()
        // Re-register notification
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            print("📅 Event store changed - refreshing calendars")
            Task { @MainActor in
                await self?.refreshTodayEvents()
            }
        }
    }

    func getEvents(for date: Date) async -> [CalendarEvent] {
        if !hasAccess {
            await requestAccess()
            guard hasAccess else { return [] }
        }

        // Refresh sources to pick up iCloud/Google calendars
        eventStore.refreshSourcesIfNecessary()

        // Give more time for sources to sync
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        // Debug: List all available calendars
        let allCalendars = eventStore.calendars(for: .event)
        print("📅 Available calendars (\(allCalendars.count)):")
        for cal in allCalendars {
            print("   - \(cal.title) (source: \(cal.source?.title ?? "unknown"), type: \(cal.type.rawValue))")
        }

        // Also list sources
        let sources = eventStore.sources
        print("📅 Calendar sources (\(sources.count)):")
        for source in sources {
            print("   - \(source.title) (type: \(source.sourceType.rawValue))")
        }

        print("📅 Fetching events from \(startOfDay) to \(endOfDay)")

        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil  // nil = all calendars
        )

        let ekEvents = eventStore.events(matching: predicate)
        print("📅 Found \(ekEvents.count) events")

        return ekEvents.map { event in
            CalendarEvent(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                notes: event.notes,
                attendees: event.attendees?.compactMap { $0.name } ?? [],
                calendarName: event.calendar?.title ?? "Unknown",
                isAllDay: event.isAllDay
            )
        }.sorted { $0.startDate < $1.startDate }
    }

    func refreshTodayEvents() async {
        isLoading = true
        todayEvents = await getEvents(for: Date())
        isLoading = false
    }

    // MARK: - Convenience

    func getUpcomingExternalMeetings(days: Int = 7) async -> [CalendarEvent] {
        guard hasAccess else { return [] }

        var allEvents: [CalendarEvent] = []
        let calendar = Calendar.current

        for dayOffset in 0..<days {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: Date()) {
                let events = await getEvents(for: date)
                allEvents.append(contentsOf: events.filter { $0.isExternal })
            }
        }

        return allEvents
    }
}
