import ComposableArchitecture
import Foundation

struct EventsClient {
    var createEvent: @Sendable (_ payload: EventMutationPayload, _ bearerToken: String) async throws -> Event
    var deleteEvent: @Sendable (_ eventID: UUID, _ bearerToken: String) async throws -> Void
    var getEvent: @Sendable (_ eventID: UUID, _ bearerToken: String) async throws -> Event
    var listEvents: @Sendable (_ dateFrom: Date?, _ dateTo: Date?, _ bearerToken: String) async throws -> [Event]
    var updateEvent: @Sendable (_ eventID: UUID, _ payload: EventMutationPayload, _ bearerToken: String) async throws -> Event
}

extension EventsClient: DependencyKey {
    static let liveValue = EventsClient(
        createEvent: { payload, bearerToken in
            let body = try await MainActor.run {
                try AppConfiguration.jsonEncoder.encode(
                    try payload.eventCreateRequestDTO()
                )
            }
            let data = try await liveAPISend(
                APIRequest(
                    path: "events/",
                    method: .post,
                    body: body,
                    bearerToken: bearerToken
                )
            )
            let dto = try await MainActor.run {
                try AppConfiguration.jsonDecoder.decode(EventDTO.self, from: data)
            }
            return APIModelConverter.convert(dto)
        },
        deleteEvent: { eventID, bearerToken in
            _ = try await liveAPISend(
                APIRequest(
                    path: "events/\(eventID.uuidString)",
                    method: .delete,
                    bearerToken: bearerToken
                )
            )
        },
        getEvent: { eventID, bearerToken in
            let data = try await liveAPISend(
                APIRequest(
                    path: "events/\(eventID.uuidString)",
                    method: .get,
                    bearerToken: bearerToken
                )
            )
            let dto = try await MainActor.run {
                try AppConfiguration.jsonDecoder.decode(EventDTO.self, from: data)
            }
            return APIModelConverter.convert(dto)
        },
        listEvents: { dateFrom, dateTo, bearerToken in
            var queryItems: [URLQueryItem] = []
            if let dateFrom {
                queryItems.append(URLQueryItem(name: "date_from", value: ISO8601DateFormatter().string(from: dateFrom)))
            }
            if let dateTo {
                queryItems.append(URLQueryItem(name: "date_to", value: ISO8601DateFormatter().string(from: dateTo)))
            }
            let data = try await liveAPISend(
                APIRequest(
                    path: "events/",
                    method: .get,
                    queryItems: queryItems,
                    bearerToken: bearerToken
                )
            )
            let dto = try await MainActor.run {
                try AppConfiguration.jsonDecoder.decode(EventListDTO.self, from: data)
            }
            return dto.items.map(APIModelConverter.convert)
        },
        updateEvent: { eventID, payload, bearerToken in
            let body = try await MainActor.run {
                try AppConfiguration.jsonEncoder.encode(payload.eventUpdateRequestDTO())
            }
            let data = try await liveAPISend(
                APIRequest(
                    path: "events/\(eventID.uuidString)",
                    method: .patch,
                    body: body,
                    bearerToken: bearerToken
                )
            )
            let dto = try await MainActor.run {
                try AppConfiguration.jsonDecoder.decode(EventDTO.self, from: data)
            }
            return APIModelConverter.convert(dto)
        }
    )
}

extension DependencyValues {
    nonisolated var eventsClient: EventsClient {
        get { self[EventsClient.self] }
        set { self[EventsClient.self] = newValue }
    }
}

private extension EventMutationPayload {
    enum PayloadMappingError: LocalizedError {
        case missingRequiredCreateFields

        var errorDescription: String? {
            switch self {
            case .missingRequiredCreateFields:
                return "Accepted event proposal is missing required fields for event creation."
            }
        }
    }

    func eventCreateRequestDTO() throws -> EventCreateRequestDTO {
        guard let title, !title.isEmpty,
              let startAt,
              let allDay,
              let type else {
            throw PayloadMappingError.missingRequiredCreateFields
        }

        return EventCreateRequestDTO(
            title: title,
            description: description,
            startAt: startAt,
            endAt: endAt,
            allDay: allDay,
            type: type.rawValue,
            location: location,
            isFixed: isFixed ?? false,
            source: source ?? "ai"
        )
    }

    func eventUpdateRequestDTO() -> EventUpdateRequestDTO {
        EventUpdateRequestDTO(
            title: title,
            description: description,
            startAt: startAt,
            endAt: endAt,
            allDay: allDay,
            type: type?.rawValue,
            location: location,
            isFixed: isFixed
        )
    }
}
