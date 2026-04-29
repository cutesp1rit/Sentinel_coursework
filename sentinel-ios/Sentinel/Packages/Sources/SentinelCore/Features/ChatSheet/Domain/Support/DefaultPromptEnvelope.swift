import Foundation

public enum DefaultPromptEnvelope {
    public nonisolated static func applying(prompt: String, to userMessage: String?) -> String? {
        let startMarker = "<sentinel_default_prompt>"
        let endMarker = "</sentinel_default_prompt>"
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            return normalized(userMessage)
        }

        let promptBlock = "\(startMarker)\n\(trimmedPrompt)\n\(endMarker)"
        let trimmedMessage = userMessage?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let trimmedMessage, !trimmedMessage.isEmpty else {
            return promptBlock
        }

        return "\(promptBlock)\n\n\(trimmedMessage)"
    }

    public nonisolated static func displayText(from rawText: String?) -> String? {
        let startMarker = "<sentinel_default_prompt>"
        let endMarker = "</sentinel_default_prompt>"
        guard let rawText else { return nil }

        guard rawText.hasPrefix(startMarker),
              let endRange = rawText.range(of: endMarker) else {
            return normalized(rawText)
        }

        let visibleText = rawText[endRange.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized(String(visibleText))
    }

    private nonisolated static func normalized(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }
        return value
    }
}
