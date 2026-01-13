//
//  CalendarView.swift
//  SolUnified
//
//  Calendar tab showing today's events
//

import SwiftUI

struct CalendarView: View {
    @ObservedObject private var calendarStore = CalendarStore.shared
    @State private var selectedDate = Date()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CALENDAR")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Color.brutalistTextMuted)

                    Text(formattedDate(selectedDate))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color.brutalistTextPrimary)
                }

                Spacer()

                // Date navigation
                HStack(spacing: 8) {
                    Button(action: { moveDate(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(Color.brutalistTextSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { selectedDate = Date() }) {
                        Text("Today")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.brutalistAccent)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { moveDate(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color.brutalistTextSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Button(action: {
                    Task {
                        calendarStore.invalidateCache()
                        await calendarStore.refreshTodayEvents(forceRefresh: true)
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(Color.brutalistTextSecondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Refresh calendars")
                .padding(.leading, 16)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.brutalistBgSecondary)

            Divider()

            // Content
            if !calendarStore.hasAccess {
                // Permission needed
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(Color.brutalistTextMuted)

                    Text("Calendar Access Required")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.brutalistTextPrimary)

                    Text("Grant calendar access in System Settings to view your events.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.brutalistTextSecondary)
                        .multilineTextAlignment(.center)

                    Button(action: {
                        Task { await calendarStore.retryAccess() }
                    }) {
                        Text("Request Access")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.brutalistAccent)
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.brutalistBgPrimary)

            } else if calendarStore.isLoading {
                // Loading
                VStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading events...")
                        .font(.system(size: 12))
                        .foregroundColor(Color.brutalistTextMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.brutalistBgPrimary)

            } else if calendarStore.todayEvents.isEmpty {
                // No events
                VStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 36))
                        .foregroundColor(Color.brutalistTextMuted)

                    Text("No events today")
                        .font(.system(size: 14))
                        .foregroundColor(Color.brutalistTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.brutalistBgPrimary)

            } else {
                // Event list
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(calendarStore.todayEvents) { event in
                            CalendarEventRow(event: event, timeFormatter: timeFormatter)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Color.brutalistBgPrimary)
            }
        }
        .background(Color.brutalistBgPrimary)
        .onAppear {
            Task { await calendarStore.refreshTodayEvents() }
        }
        .onChange(of: selectedDate) { _ in
            Task {
                calendarStore.todayEvents = await calendarStore.getEvents(for: selectedDate)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private func moveDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
        }
    }
}

struct CalendarEventRow: View {
    let event: CalendarEvent
    let timeFormatter: DateFormatter

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time column
            VStack(alignment: .trailing, spacing: 2) {
                if event.isAllDay {
                    Text("All day")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.brutalistTextSecondary)
                } else {
                    Text(timeFormatter.string(from: event.startDate))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.brutalistTextPrimary)
                    Text(timeFormatter.string(from: event.endDate))
                        .font(.system(size: 11))
                        .foregroundColor(Color.brutalistTextMuted)
                }
            }
            .frame(width: 70, alignment: .trailing)

            // Color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(event.isExternal ? Color.orange : Color.brutalistAccent)
                .frame(width: 3)

            // Event details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.brutalistTextPrimary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                                .font(.system(size: 10))
                            Text(location)
                                .lineLimit(1)
                        }
                        .font(.system(size: 11))
                        .foregroundColor(Color.brutalistTextMuted)
                    }

                    if !event.attendees.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2")
                                .font(.system(size: 10))
                            Text("\(event.attendees.count)")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(Color.brutalistTextMuted)
                    }

                    Text(event.calendarName)
                        .font(.system(size: 10))
                        .foregroundColor(Color.brutalistTextMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.brutalistBgTertiary)
                        .cornerRadius(3)
                }
            }

            Spacer()

            // External meeting indicator
            if event.isExternal {
                Image(systemName: "person.crop.circle.badge.clock")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                    .help("External meeting")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.brutalistBgPrimary)
        .contentShape(Rectangle())
    }
}
