import Foundation
import SwiftData

struct CalendarSyncMapping: Equatable, Sendable {
    let eventKitIdentifier: String
    let serverEventID: UUID
}

@MainActor
final class CalendarSyncStore {
    static let shared = CalendarSyncStore()

    private let container: ModelContainer

    private init() {
        do {
            container = try ModelContainer(for: SyncedCalendarRecord.self)
        } catch {
            fatalError("Failed to create calendar sync container: \(error)")
        }
    }

    func mappingByServerEventID() -> [UUID: CalendarSyncMapping] {
        let descriptor = FetchDescriptor<SyncedCalendarRecord>()
        let records = (try? container.mainContext.fetch(descriptor)) ?? []
        return Dictionary(
            uniqueKeysWithValues: records.map {
                (
                    $0.serverEventID,
                    CalendarSyncMapping(
                        eventKitIdentifier: $0.eventKitIdentifier,
                        serverEventID: $0.serverEventID
                    )
                )
            }
        )
    }

    func upsert(
        serverEventID: UUID,
        eventKitIdentifier: String,
        exportStatus: CalendarExportStatus,
        hasConflict: Bool,
        lastSyncedAt: Date
    ) {
        let descriptor = FetchDescriptor<SyncedCalendarRecord>()
        let existingRecord = try? container.mainContext
            .fetch(descriptor)
            .first(where: { $0.serverEventID == serverEventID })

        if let existingRecord {
            existingRecord.eventKitIdentifier = eventKitIdentifier
            existingRecord.exportStatus = exportStatus
            existingRecord.hasConflict = hasConflict
            existingRecord.lastSyncedAt = lastSyncedAt
        } else {
            let newRecord = SyncedCalendarRecord(
                serverEventID: serverEventID,
                eventKitIdentifier: eventKitIdentifier,
                exportStatus: exportStatus,
                hasConflict: hasConflict,
                lastSyncedAt: lastSyncedAt
            )
            container.mainContext.insert(newRecord)
        }

        try? container.mainContext.save()
    }

    func delete(serverEventID: UUID) {
        let descriptor = FetchDescriptor<SyncedCalendarRecord>()
        let records = (try? container.mainContext.fetch(descriptor)) ?? []
        records
            .filter { $0.serverEventID == serverEventID }
            .forEach(container.mainContext.delete)
        try? container.mainContext.save()
    }
}
