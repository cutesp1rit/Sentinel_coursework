import Foundation
import SwiftData

enum CalendarExportStatus: String, Codable, Equatable, Sendable {
    case conflicted
    case synced
}

@Model
final class SyncedCalendarRecord {
    @Attribute(.unique) var serverEventID: UUID
    var eventKitIdentifier: String
    var exportStatusRaw: String
    var hasConflict: Bool
    var lastSyncedAt: Date

    init(
        serverEventID: UUID,
        eventKitIdentifier: String,
        exportStatus: CalendarExportStatus,
        hasConflict: Bool,
        lastSyncedAt: Date
    ) {
        self.serverEventID = serverEventID
        self.eventKitIdentifier = eventKitIdentifier
        self.exportStatusRaw = exportStatus.rawValue
        self.hasConflict = hasConflict
        self.lastSyncedAt = lastSyncedAt
    }

    var exportStatus: CalendarExportStatus {
        get { CalendarExportStatus(rawValue: exportStatusRaw) ?? .synced }
        set { exportStatusRaw = newValue.rawValue }
    }
}
