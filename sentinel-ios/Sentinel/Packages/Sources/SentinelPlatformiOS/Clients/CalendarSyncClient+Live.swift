import EventKit
import SentinelCore
import Foundation

extension CalendarSyncClientLive {
    @MainActor
    static func detectConflictsOnMain(_ drafts: [CalendarSyncClient.Draft]) -> [CalendarSyncClient.Draft.ID: Bool] {
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
    static func loadUpcomingOnMain() async -> CalendarSyncClient.UpcomingSnapshot {
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
            let access: CalendarSyncClient.Access = switch resolvedStatus {
            case .notDetermined:
                .notRequested
            case .denied, .restricted, .writeOnly:
                .denied
            case .fullAccess:
                .granted
            @unknown default:
                .denied
            }
            return .init(access: access, items: [])
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
                CalendarSyncClient.UpcomingItem(
                    id: UUID(),
                    startAt: event.startDate ?? startDate,
                    endAt: event.endDate,
                    subtitle: event.location ?? "",
                    title: event.title.isEmpty ? "Untitled Event" : event.title
                )
            }

        return .init(access: .granted, items: Array(items))
    }

    @MainActor
    static func syncOnMain(_ request: CalendarSyncClient.SyncRequest) async throws -> CalendarSyncClient.SyncResult {
        let eventStore = EKEventStore()
        try await Self.ensureWritableAccess(for: eventStore)

        let mappings = CalendarSyncStore.shared.mappingByServerEventID()
        let defaultCalendar = try Self.defaultCalendar(for: eventStore)

        var result = CalendarSyncClient.SyncResult()

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
}
