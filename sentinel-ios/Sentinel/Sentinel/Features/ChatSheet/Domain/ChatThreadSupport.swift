import ComposableArchitecture
import SentinelCore
import Foundation

extension ChatThreadFeature {
    static func chatTitle(from draft: String) -> String {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return L10n.ChatSheet.newChat }
        return String(trimmed.replacingOccurrences(of: "\n", with: " ").prefix(48))
    }

    nonisolated static func errorMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        return error.localizedDescription
    }
}
