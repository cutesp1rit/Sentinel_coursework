import SentinelCore
import Foundation

extension CalendarSyncClient {
    public enum Access: Equatable, Sendable {
        case denied
        case granted
        case notRequested
    }

    public struct Draft: Equatable, Identifiable, Sendable {
        public let id: String
        public let allDay: Bool
        public let endAt: Date?
        public let eventKind: EventKind
        public let existingServerEventID: UUID?
        public let startAt: Date
        public let title: String

        public init(
            id: String,
            allDay: Bool,
            endAt: Date?,
            eventKind: EventKind,
            existingServerEventID: UUID?,
            startAt: Date,
            title: String
        ) {
            self.id = id
            self.allDay = allDay
            self.endAt = endAt
            self.eventKind = eventKind
            self.existingServerEventID = existingServerEventID
            self.startAt = startAt
            self.title = title
        }
    }

    public struct SyncRequest: Equatable, Sendable {
        public var deletedEventIDs: Set<UUID> = []
        public var events: [Event]

        public init(deletedEventIDs: Set<UUID> = [], events: [Event]) {
            self.deletedEventIDs = deletedEventIDs
            self.events = events
        }
    }

    public struct SyncResult: Equatable, Sendable {
        public var conflictedEventIDs: Set<UUID> = []
        public var deletedEventIDs: Set<UUID> = []
        public var syncedEventIDs: Set<UUID> = []

        public init(
            conflictedEventIDs: Set<UUID> = [],
            deletedEventIDs: Set<UUID> = [],
            syncedEventIDs: Set<UUID> = []
        ) {
            self.conflictedEventIDs = conflictedEventIDs
            self.deletedEventIDs = deletedEventIDs
            self.syncedEventIDs = syncedEventIDs
        }
    }

    public struct UpcomingItem: Equatable, Identifiable, Sendable {
        public let id: UUID
        public let startAt: Date
        public let endAt: Date?
        public let subtitle: String
        public let title: String

        public init(id: UUID, startAt: Date, endAt: Date?, subtitle: String, title: String) {
            self.id = id
            self.startAt = startAt
            self.endAt = endAt
            self.subtitle = subtitle
            self.title = title
        }
    }

    public struct UpcomingSnapshot: Equatable, Sendable {
        public var access: Access
        public var items: [UpcomingItem]

        public init(access: Access, items: [UpcomingItem]) {
            self.access = access
            self.items = items
        }
    }
}

extension Event {
    var syncURL: URL {
        URL(string: "sentinel://event/\(id.uuidString)")!
    }
}
