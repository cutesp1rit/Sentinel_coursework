import ComposableArchitecture
import Foundation

struct RebalanceDayInput: Equatable, Sendable {
    let date: Date
    let resourceBattery: Double?
}

struct RebalanceProposedEvent: Equatable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let startAt: Date
    let endAt: Date?
    let originalStartAt: Date
    let originalEndAt: Date?
    let changed: Bool
}

struct RebalancePreview: Equatable, Sendable {
    let proposed: [RebalanceProposedEvent]
    let summary: String
    let changedCount: Int
    let unchangedCount: Int
}

struct RebalanceApplyEvent: Equatable, Sendable {
    let id: UUID
    let startAt: Date
    let endAt: Date?
}

struct RebalanceClient: Sendable {
    var apply: @Sendable (_ events: [RebalanceApplyEvent], _ bearerToken: String) async throws -> Void
    var propose: @Sendable (_ timezone: String, _ days: [RebalanceDayInput], _ userPrompt: String?, _ bearerToken: String) async throws -> RebalancePreview
}

extension RebalanceClient: DependencyKey {
    static let liveValue = RebalanceClient(
        apply: { events, bearerToken in
            let body = try await MainActor.run {
                try AppConfiguration.jsonEncoder.encode(
                    RebalanceApplyRequestDTO(
                        events: events.map {
                            RebalanceApplyEventDTO(
                                id: $0.id,
                                startAt: $0.startAt,
                                endAt: $0.endAt
                            )
                        }
                    )
                )
            }
            _ = try await liveAPISend(
                APIRequest(
                    path: "events/rebalance/apply",
                    method: .post,
                    body: body,
                    bearerToken: bearerToken
                )
            )
        },
        propose: { timezone, days, userPrompt, bearerToken in
            let body = try await MainActor.run {
                try AppConfiguration.jsonEncoder.encode(
                    RebalanceRequestDTO(
                        timezone: timezone,
                        days: days.map {
                            RebalanceDayDTO(
                                date: $0.date.formatted(.iso8601.year().month().day()),
                                resourceBattery: $0.resourceBattery
                            )
                        },
                        userPrompt: userPrompt
                    )
                )
            }
            let data = try await liveAPISend(
                APIRequest(
                    path: "events/rebalance",
                    method: .post,
                    body: body,
                    bearerToken: bearerToken,
                    timeoutInterval: 180
                )
            )
            let dto = try await MainActor.run {
                try AppConfiguration.jsonDecoder.decode(RebalanceResponseDTO.self, from: data)
            }
            return RebalancePreview(
                proposed: dto.proposed.map {
                    RebalanceProposedEvent(
                        id: $0.id,
                        title: $0.title,
                        startAt: $0.startAt,
                        endAt: $0.endAt,
                        originalStartAt: $0.originalStartAt,
                        originalEndAt: $0.originalEndAt,
                        changed: $0.changed
                    )
                },
                summary: dto.summary,
                changedCount: dto.changedCount,
                unchangedCount: dto.unchangedCount
            )
        }
    )
}

extension DependencyValues {
    nonisolated var rebalanceClient: RebalanceClient {
        get { self[RebalanceClient.self] }
        set { self[RebalanceClient.self] = newValue }
    }
}

private struct RebalanceDayDTO: Codable, Equatable {
    let date: String
    let resourceBattery: Double?

    enum CodingKeys: String, CodingKey {
        case date
        case resourceBattery = "resource_battery"
    }
}

private struct RebalanceRequestDTO: Codable, Equatable {
    let timezone: String
    let days: [RebalanceDayDTO]
    let userPrompt: String?

    enum CodingKeys: String, CodingKey {
        case timezone
        case days
        case userPrompt = "user_prompt"
    }
}

private struct RebalanceProposedEventDTO: Codable, Equatable {
    let id: UUID
    let title: String
    let startAt: Date
    let endAt: Date?
    let originalStartAt: Date
    let originalEndAt: Date?
    let changed: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case startAt = "start_at"
        case endAt = "end_at"
        case originalStartAt = "original_start_at"
        case originalEndAt = "original_end_at"
        case changed
    }
}

private struct RebalanceResponseDTO: Codable, Equatable {
    let proposed: [RebalanceProposedEventDTO]
    let summary: String
    let changedCount: Int
    let unchangedCount: Int

    enum CodingKeys: String, CodingKey {
        case proposed
        case summary
        case changedCount = "changed_count"
        case unchangedCount = "unchanged_count"
    }
}

private struct RebalanceApplyEventDTO: Codable, Equatable {
    let id: UUID
    let startAt: Date
    let endAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case startAt = "start_at"
        case endAt = "end_at"
    }
}

private struct RebalanceApplyRequestDTO: Codable, Equatable {
    let events: [RebalanceApplyEventDTO]
}
