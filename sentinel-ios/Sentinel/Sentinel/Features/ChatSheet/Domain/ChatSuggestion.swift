import Foundation
import SentinelCore
import SwiftUI

struct ChatSuggestion: Equatable, Identifiable {
    let id: String
    let action: EventAction.Kind
    let actionIndex: Int
    let allDay: Bool
    let eventId: UUID?
    let eventKind: EventKind
    let endAt: Date?
    let startAt: Date?
    let status: EventAction.Status
    var title: String
    var timeRange: String
    var location: String
    var hasConflict: Bool

    init(actionIndex: Int, action: EventAction) {
        let resolvedStartAt = action.payload?.startAt ?? action.eventSnapshot?.startAt
        let resolvedEndAt = action.payload?.endAt ?? action.eventSnapshot?.endAt

        self.action = action.action
        self.actionIndex = actionIndex
        allDay = action.payload?.allDay ?? false
        eventId = action.eventId
        eventKind = action.payload?.type ?? .event
        endAt = resolvedEndAt
        startAt = resolvedStartAt
        status = action.status
        id = Self.stableID(actionIndex: actionIndex, action: action)
        title = Self.title(for: action)
        timeRange = Self.timeRange(for: action)
        location = Self.location(for: action)
        hasConflict = false
    }

    private static func title(for action: EventAction) -> String {
        if let title = action.payload?.title, !title.isEmpty {
            return title
        }
        if let snapshotTitle = action.eventSnapshot?.title, !snapshotTitle.isEmpty {
            return snapshotTitle
        }

        switch action.action {
        case .create:
            return "Create Event"
        case .update:
            return "Update Event"
        case .delete:
            return "Delete Event"
        }
    }

    private static func timeRange(for action: EventAction) -> String {
        let start = action.payload?.startAt ?? action.eventSnapshot?.startAt
        let end = action.payload?.endAt ?? action.eventSnapshot?.endAt

        switch (start, end) {
        case let (start?, end?):
            return "\(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
        case let (start?, nil):
            return start.formatted(date: .abbreviated, time: .shortened)
        default:
            return action.status.rawValue.capitalized
        }
    }

    private static func location(for action: EventAction) -> String {
        if let location = action.payload?.location, !location.isEmpty {
            return location
        }

        switch action.action {
        case .create:
            return "Create proposal"
        case .update:
            return action.eventSnapshot?.title ?? "Update proposal"
        case .delete:
            return action.eventSnapshot?.title ?? "Delete proposal"
        }
    }

    private static func stableID(actionIndex: Int, action: EventAction) -> String {
        if let eventId = action.eventId {
            return "event-\(eventId.uuidString)-\(actionIndex)"
        }
        return "proposal-\(actionIndex)"
    }

    var statusText: String? {
        switch status {
        case .accepted:
            return L10n.ChatSheet.statusAccepted
        case .pending:
            return nil
        case .rejected:
            return L10n.ChatSheet.statusRejected
        }
    }

    var statusTint: Color {
        switch status {
        case .accepted:
            return .green
        case .pending, .rejected:
            return .secondary
        }
    }
}
