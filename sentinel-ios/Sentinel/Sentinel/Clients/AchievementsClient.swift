import ComposableArchitecture
import Foundation

struct AchievementsClient: Sendable {
    var loadAchievements: @Sendable (_ bearerToken: String) async throws -> [AchievementGroup]
}

extension AchievementsClient: DependencyKey {
    static let liveValue = AchievementsClient(
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

extension DependencyValues {
    nonisolated var achievementsClient: AchievementsClient {
        get { self[AchievementsClient.self] }
        set { self[AchievementsClient.self] = newValue }
    }
}
