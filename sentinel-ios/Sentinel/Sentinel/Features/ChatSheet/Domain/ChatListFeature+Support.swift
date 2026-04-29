import ComposableArchitecture
import SentinelCore
import Foundation

extension ChatListFeature {
    func persistActiveChatEffect(chatID: UUID?) -> Effect<Action> {
        .run { [appSettingsClient] _ in
            var settings = await appSettingsClient.load()
            settings.markActiveChat(chatID)
            await appSettingsClient.save(settings)
        }
    }

    nonisolated static func errorMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        return error.localizedDescription
    }
}
