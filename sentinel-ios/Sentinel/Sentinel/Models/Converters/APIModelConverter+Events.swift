import Foundation

extension APIModelConverter {
    nonisolated static func convert(_ dto: EventDTO) -> Event {
        Event(
            id: dto.id,
            userId: dto.userId,
            title: dto.title,
            description: dto.description,
            startAt: dto.startAt,
            endAt: dto.endAt,
            allDay: dto.allDay,
            type: EventKind(rawValue: dto.type) ?? .event,
            location: dto.location,
            isFixed: dto.isFixed,
            source: dto.source,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    nonisolated static func convert(_ dto: EventMutationPayloadDTO) -> EventMutationPayload {
        EventMutationPayload(
            title: dto.title,
            description: dto.description,
            startAt: dto.startAt,
            endAt: dto.endAt,
            allDay: dto.allDay,
            type: dto.type.flatMap(EventKind.init(rawValue:)),
            location: dto.location,
            isFixed: dto.isFixed,
            source: dto.source
        )
    }

    nonisolated static func convert(_ dto: EventSnapshotDTO) -> EventAction.Snapshot {
        EventAction.Snapshot(
            title: dto.title,
            startAt: dto.startAt,
            endAt: dto.endAt
        )
    }

    nonisolated static func convert(_ dto: EventActionDTO) -> EventAction {
        EventAction(
            action: EventAction.Kind(rawValue: dto.action) ?? .create,
            eventId: dto.eventId,
            payload: dto.payload.map(convert),
            status: EventAction.Status(rawValue: dto.status) ?? .pending,
            eventSnapshot: dto.eventSnapshot.map(convert)
        )
    }

    nonisolated static func convert(_ dto: EventActionsContentDTO) -> EventActionsContent {
        EventActionsContent(
            type: dto.type,
            actions: dto.actions.map(convert)
        )
    }
}
