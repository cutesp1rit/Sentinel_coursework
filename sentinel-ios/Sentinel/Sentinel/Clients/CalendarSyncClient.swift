import ComposableArchitecture
import EventKit
import Foundation

struct CalendarSyncClient: Sendable {
    enum Access: Equatable, Sendable {
        case denied
        case granted
        case notRequested
    }

    struct Draft: Equatable, Identifiable, Sendable {
        let id: String
        let allDay: Bool
        let endAt: Date?
        let eventKind: EventKind
        let existingServerEventID: UUID?
        let startAt: Date
        let title: String
    }

    struct SyncRequest: Equatable, Sendable {
        var deletedEventIDs: Set<UUID> = []
        var events: [Event]
    }

    struct SyncResult: Equatable, Sendable {
        var conflictedEventIDs: Set<UUID> = []
        var deletedEventIDs: Set<UUID> = []
        var syncedEventIDs: Set<UUID> = []
    }

    struct UpcomingItem: Equatable, Identifiable, Sendable {
        let id: UUID
        let startAt: Date
        let endAt: Date?
        let subtitle: String
        let title: String
    }

    struct UpcomingSnapshot: Equatable, Sendable {
        var access: Access
        var items: [UpcomingItem]
    }

    var detectConflicts: @Sendable (_ drafts: [Draft]) async -> [Draft.ID: Bool]
    var loadUpcoming: @Sendable () async -> UpcomingSnapshot
    var sync: @Sendable (_ request: SyncRequest) async throws -> SyncResult
}

extension CalendarSyncClient: DependencyKey {
    static let liveValue = CalendarSyncClient(
        detectConflicts: { drafts in
            await Self.detectConflictsOnMain(drafts)
        },
        loadUpcoming: {
            await Self.loadUpcomingOnMain()
        },
        sync: { request in
            try await Self.syncOnMain(request)
        }
    )
}

extension DependencyValues {
    nonisolated var calendarSyncClient: CalendarSyncClient {
        get { self[CalendarSyncClient.self] }
        set { self[CalendarSyncClient.self] = newValue }
    }
}

private extension CalendarSyncClient {
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

    @MainActor
    static func detectConflictsOnMain(_ drafts: [Draft]) -> [Draft.ID: Bool] {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess:
            break
        case .writeOnly, .notDetermined, .denied, .restricted:
            return Dictionary(uniqueKeysWithValues: drafts.map { ($0.id, false) })
        @unknown default:
            return Dictionary(uniqueKeysWithValues: drafts.map { ($0.id, false) })
        }

        let eventStore = EKEventStore()
        let mappings = CalendarSyncStore.shared.mappingByServerEventID()

        return Dictionary(uniqueKeysWithValues: drafts.map { draft in
            let excludedEventIdentifier = draft.existingServerEventID
                .flatMap { mappings[$0]?.eventKitIdentifier }
            let hasConflict = Self.hasConflict(
                in: eventStore,
                startAt: draft.startAt,
                endAt: Self.normalizedEndDate(
                    startAt: draft.startAt,
                    endAt: draft.endAt,
                    allDay: draft.allDay,
                    eventKind: draft.eventKind
                ),
                excludedEventIdentifier: excludedEventIdentifier
            )
            return (draft.id, hasConflict)
        })
    }

    @MainActor
    static func loadUpcomingOnMain() async -> UpcomingSnapshot {
        let currentStatus = EKEventStore.authorizationStatus(for: .event)
        let resolvedStatus: EKAuthorizationStatus

        switch currentStatus {
        case .fullAccess:
            resolvedStatus = currentStatus
        case .notDetermined:
            let store = EKEventStore()
            let granted = (try? await requestAccess(for: store)) ?? false
            resolvedStatus = granted ? .fullAccess : .denied
        case .writeOnly, .denied, .restricted:
            resolvedStatus = currentStatus
        @unknown default:
            resolvedStatus = .denied
        }

        guard resolvedStatus == .fullAccess else {
            let access: Access = switch resolvedStatus {
            case .notDetermined:
                .notRequested
            case .denied, .restricted, .writeOnly:
                .denied
            case .fullAccess:
                .granted
            @unknown default:
                .denied
            }
            return UpcomingSnapshot(access: access, items: [])
        }

        let eventStore = EKEventStore()
        let startDate = Calendar.current.startOfDay(for: Date())
        let endDate = Calendar.current.date(byAdding: .day, value: 90, to: startDate) ?? startDate
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let items = eventStore.events(matching: predicate)
            .sorted { lhs, rhs in
                (lhs.startDate ?? .distantFuture) < (rhs.startDate ?? .distantFuture)
            }
            .map { event in
                UpcomingItem(
                    id: UUID(),
                    startAt: event.startDate ?? startDate,
                    endAt: event.endDate,
                    subtitle: event.location ?? "",
                    title: event.title.isEmpty ? "Untitled Event" : event.title
                )
            }

        return UpcomingSnapshot(access: .granted, items: Array(items))
    }

    @MainActor
    static func syncOnMain(_ request: SyncRequest) async throws -> SyncResult {
        let eventStore = EKEventStore()
        try await Self.ensureWritableAccess(for: eventStore)

        let mappings = CalendarSyncStore.shared.mappingByServerEventID()
        let defaultCalendar = try Self.defaultCalendar(for: eventStore)

        var result = SyncResult()

        for event in request.events {
            let ekEvent = Self.resolveEvent(
                for: event,
                using: eventStore,
                mappings: mappings,
                defaultCalendar: defaultCalendar
            )

            Self.apply(event: event, to: ekEvent, in: defaultCalendar)

            let hasConflict = Self.hasConflict(
                in: eventStore,
                startAt: ekEvent.startDate,
                endAt: ekEvent.endDate,
                excludedEventIdentifier: ekEvent.eventIdentifier
            )

            try eventStore.save(ekEvent, span: .thisEvent, commit: false)
            guard let eventKitIdentifier = ekEvent.eventIdentifier else {
                continue
            }

            result.syncedEventIDs.insert(event.id)
            if hasConflict {
                result.conflictedEventIDs.insert(event.id)
            }

            let exportStatus: CalendarExportStatus = hasConflict ? .conflicted : .synced
            CalendarSyncStore.shared.upsert(
                serverEventID: event.id,
                eventKitIdentifier: eventKitIdentifier,
                exportStatus: exportStatus,
                hasConflict: hasConflict,
                lastSyncedAt: Date()
            )
        }

        for deletedEventID in request.deletedEventIDs {
            if let record = mappings[deletedEventID],
               let ekEvent = eventStore.event(withIdentifier: record.eventKitIdentifier) {
                try eventStore.remove(ekEvent, span: .thisEvent, commit: false)
                result.deletedEventIDs.insert(deletedEventID)
            }

            CalendarSyncStore.shared.delete(serverEventID: deletedEventID)
        }

        if !request.events.isEmpty || !request.deletedEventIDs.isEmpty {
            try eventStore.commit()
        }
        return result
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
}

private extension Event {
    var syncURL: URL {
        URL(string: "sentinel://event/\(id.uuidString)")!
    }
}
