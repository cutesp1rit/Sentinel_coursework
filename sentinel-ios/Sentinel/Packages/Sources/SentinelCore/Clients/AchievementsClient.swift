import ComposableArchitecture
import Foundation

public struct AchievementsClient: Sendable {
    public var loadAchievements: @Sendable (_ bearerToken: String) async throws -> [AchievementGroup]

    public init(loadAchievements: @escaping @Sendable (_ bearerToken: String) async throws -> [AchievementGroup]) {
        self.loadAchievements = loadAchievements
    }
}

extension AchievementsClient: DependencyKey {
    public static let liveValue = AchievementsClient(
        loadAchievements: { bearerToken in
            let data = try await liveAPISend(
                APIRequest(path: "achievements/", method: .get, bearerToken: bearerToken)
            )
            let dto = try await MainActor.run {
                try AppConfiguration.jsonDecoder.decode(AchievementsResponseDTO.self, from: data)
            }
            return dto.groups.map(APIModelConverter.convert)
        }
    )
}

public extension DependencyValues {
    nonisolated var achievementsClient: AchievementsClient {
        get { self[AchievementsClient.self] }
        set { self[AchievementsClient.self] = newValue }
    }
}
