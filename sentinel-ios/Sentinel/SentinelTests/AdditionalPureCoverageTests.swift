import SentinelUI
import SentinelCore
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct AdditionalPureCoverageTests {
    @Test
    func homeAchievementsAndBatteryModelBranches() {
        var state = HomeState()
        state.achievementGroups = [
            Fixture.achievementGroup(groupCode: "events_created", currentValue: 9),
            Fixture.achievementGroup(groupCode: "active_days", currentValue: 1)
        ]

        #expect(state.nextAchievementHighlights.count == 2)
        #expect(state.nextAchievementHighlights.first?.progressFraction ?? 0 >= state.nextAchievementHighlights.last?.progressFraction ?? 0)
        #expect(state.achievementPreviewHighlights.count == 2)

        #expect(HomeBatteryState.hidden.isVisible == false)
        #expect(HomeBatteryState.placeholder.isVisible)
        #expect(HomeBatteryState.setupRequired(.enableAppleIntelligence).isActionable)
        #expect(HomeBatteryState.ready(.init(headline: "80%", detail: "Balanced", percentage: 80)).displaySnapshot.percentage == 80)
    }

    @Test
    func chatThreadMessageAttachmentRecoveryAndFailureFlags() {
        let message = ChatThreadMessage(
            role: .user,
            text: "Body",
            images: [
                ChatImageAttachment(
                    url: "",
                    filename: "local.png",
                    localData: Data([0x01]),
                    mimeType: "image/png",
                    previewData: Data([0x02])
                )
            ],
            deliveryState: .failed
        )

        #expect(message.failedComposerAttachments.count == 1)
        #expect(message.failedComposerAttachments.first?.filename == "local.png")
        #expect(message.isFailedToSend)
    }

    @Test
    func apiConfigurationAndConvertersCoverRemainingBranches() {
        let token = TokenDTO(accessToken: "abc", tokenType: "bearer")
        #expect(APIModelConverter.convert(token) == Session(accessToken: "abc", tokenType: "bearer"))
        #expect(AppConfiguration.apiBaseURL.absoluteString.contains("/api/v1"))
    }
}
