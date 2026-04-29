import SentinelUI
import SentinelCore
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct DefaultPromptEnvelopeTests {
    @Test
    func applyingWithoutPromptReturnsTrimmedUserMessage() {
        #expect(DefaultPromptEnvelope.applying(prompt: "   ", to: "  hello  ") == "  hello  ")
        #expect(DefaultPromptEnvelope.applying(prompt: "", to: nil) == nil)
    }

    @Test
    func applyingWithPromptWrapsPromptAndOptionalMessage() {
        let promptOnly = DefaultPromptEnvelope.applying(prompt: "Focus", to: nil)
        #expect(promptOnly?.contains("<sentinel_default_prompt>") == true)
        #expect(promptOnly?.contains("Focus") == true)

        let promptAndMessage = DefaultPromptEnvelope.applying(prompt: "Focus", to: "Plan the day")
        #expect(promptAndMessage?.contains("</sentinel_default_prompt>") == true)
        #expect(promptAndMessage?.hasSuffix("Plan the day") == true)
    }

    @Test
    func displayTextStripsEnvelopeAndReturnsNilForEmptyVisibleText() {
        let raw = """
        <sentinel_default_prompt>
        Focus
        </sentinel_default_prompt>

        Plan the day
        """
        #expect(DefaultPromptEnvelope.displayText(from: raw) == "Plan the day")
        #expect(DefaultPromptEnvelope.displayText(from: "Plain text") == "Plain text")
        #expect(DefaultPromptEnvelope.displayText(from: "<sentinel_default_prompt>\nFocus\n</sentinel_default_prompt>\n\n   ") == nil)
        #expect(DefaultPromptEnvelope.displayText(from: nil) == nil)
    }
}
