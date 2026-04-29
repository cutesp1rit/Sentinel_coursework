import EventKit
import SentinelCore
import Foundation

enum CalendarSyncClientLive {
    enum Constants {
        static let sentinelCalendarTitle = "Sentinel"
    }

    enum CalendarSyncError: LocalizedError {
        case noWritableCalendar
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .noWritableCalendar:
                return "No writable calendar is available for Sentinel sync."
            case .permissionDenied:
                return "Calendar access is required to sync accepted events."
            }
        }
    }

    @MainActor
    static func apply(event: Event, to ekEvent: EKEvent, in calendar: EKCalendar) {
        ekEvent.calendar = calendar
        ekEvent.title = event.title
        ekEvent.notes = event.description
        ekEvent.startDate = event.startAt
        ekEvent.endDate = normalizedEndDate(
            startAt: event.startAt,
            endAt: event.endAt,
            allDay: event.allDay,
            eventKind: event.type
        )
        ekEvent.isAllDay = event.allDay
        ekEvent.location = event.location
        ekEvent.url = event.syncURL
    }

    @MainActor
    static func defaultCalendar(for eventStore: EKEventStore) throws -> EKCalendar {
        if let existingSentinelCalendar = eventStore.calendars(for: .event).first(where: {
            $0.title == Constants.sentinelCalendarTitle && $0.allowsContentModifications
        }) {
            return existingSentinelCalendar
        }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = Constants.sentinelCalendarTitle
        calendar.cgColor = CGColor(red: 0.11, green: 0.45, blue: 0.96, alpha: 1)

        if let source = preferredSource(for: eventStore) {
            calendar.source = source
            try eventStore.saveCalendar(calendar, commit: true)
            return calendar
        }

        throw CalendarSyncError.noWritableCalendar
    }

    @MainActor
    static func ensureWritableAccess(for eventStore: EKEventStore) async throws {
        let currentStatus = EKEventStore.authorizationStatus(for: .event)
        switch currentStatus {
        case .fullAccess:
            return
        case .writeOnly, .denied, .restricted:
            throw CalendarSyncError.permissionDenied
        case .notDetermined:
            let granted = try await requestAccess(for: eventStore)
            guard granted else {
                throw CalendarSyncError.permissionDenied
            }
        @unknown default:
            throw CalendarSyncError.permissionDenied
        }
    }

    @MainActor
    static func findEventByURL(
        _ url: URL,
        startAt: Date,
        endAt: Date,
        in eventStore: EKEventStore
    ) -> EKEvent? {
        let predicate = eventStore.predicateForEvents(withStart: startAt, end: endAt, calendars: nil)
        return eventStore
            .events(matching: predicate)
            .first(where: { $0.url == url })
    }

    @MainActor
    static func hasConflict(
        in eventStore: EKEventStore,
        startAt: Date,
        endAt: Date,
        excludedEventIdentifier: String?
    ) -> Bool {
        let predicate = eventStore.predicateForEvents(withStart: startAt, end: endAt, calendars: nil)
        return eventStore
            .events(matching: predicate)
            .contains { candidate in
                guard candidate.eventIdentifier != excludedEventIdentifier else {
                    return false
                }

                guard let candidateStartDate = candidate.startDate else {
                    return false
                }

                let candidateEndDate = candidate.endDate ?? candidateStartDate
                return candidateStartDate < endAt && candidateEndDate > startAt
            }
    }

    nonisolated static func normalizedEndDate(
        startAt: Date,
        endAt: Date?,
        allDay: Bool,
        eventKind: EventKind
    ) -> Date {
        if allDay {
            let startOfDay = Calendar.current.startOfDay(for: startAt)
            return endAt ?? Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startAt
        }

        if let endAt, endAt > startAt {
            return endAt
        }

        switch eventKind {
        case .event:
            return startAt.addingTimeInterval(60 * 30)
        case .reminder:
            return startAt.addingTimeInterval(60)
        }
    }

    @MainActor
    static func preferredSource(for eventStore: EKEventStore) -> EKSource? {
        if let defaultSource = eventStore.defaultCalendarForNewEvents?.source,
           defaultSource.sourceType != .subscribed {
            return defaultSource
        }

        return eventStore.sources.first(where: { source in
            switch source.sourceType {
            case .local, .calDAV, .exchange, .mobileMe:
                return true
            case .birthdays, .subscribed:
                return false
            @unknown default:
                return false
            }
        })
    }

    @MainActor
    static func requestAccess(for eventStore: EKEventStore) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            eventStore.requestFullAccessToEvents { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    @MainActor
    static func resolveEvent(
        for event: Event,
        using eventStore: EKEventStore,
        mappings: [UUID: CalendarSyncMapping],
        defaultCalendar: EKCalendar
    ) -> EKEvent {
        if let existingIdentifier = mappings[event.id]?.eventKitIdentifier,
           let existingEvent = eventStore.event(withIdentifier: existingIdentifier) {
            return existingEvent
        }

        let endDate = normalizedEndDate(
            startAt: event.startAt,
            endAt: event.endAt,
            allDay: event.allDay,
            eventKind: event.type
        )

        if let deduplicatedEvent = findEventByURL(
            event.syncURL,
            startAt: event.startAt,
            endAt: endDate,
            in: eventStore
        ) {
            return deduplicatedEvent
        }

        let newEvent = EKEvent(eventStore: eventStore)
        newEvent.calendar = defaultCalendar
        return newEvent
    }
}
