import Foundation

enum DefaultPromptEnvelope {
    private static let startMarker = "<sentinel_default_prompt>"
    private static let endMarker = "</sentinel_default_prompt>"

    static func applying(prompt: String, to userMessage: String?) -> String? {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            return userMessage?.nilIfEmpty
        }

        let promptBlock = "\(startMarker)\n\(trimmedPrompt)\n\(endMarker)"
        let trimmedMessage = userMessage?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let trimmedMessage, !trimmedMessage.isEmpty else {
            return promptBlock
        }

        return "\(promptBlock)\n\n\(trimmedMessage)"
    }

    static func displayText(from rawText: String?) -> String? {
        guard let rawText else { return nil }

        guard rawText.hasPrefix(startMarker),
              let endRange = rawText.range(of: endMarker) else {
            return rawText.nilIfEmpty
        }

        let visibleText = rawText[endRange.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return String(visibleText).nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
