import ComposableArchitecture
import Foundation

struct EventsClient {
    var getEvent: @Sendable (_ eventID: UUID, _ bearerToken: String) async throws -> Event
    var listEvents: @Sendable (_ dateFrom: Date?, _ dateTo: Date?, _ bearerToken: String) async throws -> [Event]
}

extension EventsClient: DependencyKey {
    static let liveValue = EventsClient(
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
                    path: "events",
                    method: .get,
                    queryItems: queryItems,
                    bearerToken: bearerToken
                )
            )
            let dto = try await MainActor.run {
                try AppConfiguration.jsonDecoder.decode(EventListDTO.self, from: data)
            }
            return dto.items.map(APIModelConverter.convert)
        }
    )
}

extension DependencyValues {
    var eventsClient: EventsClient {
        get { self[EventsClient.self] }
        set { self[EventsClient.self] = newValue }
    }
}
