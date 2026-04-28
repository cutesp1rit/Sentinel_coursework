import Foundation
import Testing
@testable import Sentinel

@MainActor
struct AchievementAndAuthStateTests {
    @Test
    func achievementModelsExposeProgressAndCopy() {
        let unlocked = Fixture.achievementLevel(unlocked: true, earnedAt: Fixture.referenceDate)
        let locked = Fixture.achievementLevel(
            id: Fixture.secondLevelID,
            level: 2,
            targetValue: 10,
            title: "Builder",
            unlocked: false
        )
        let group = Fixture.achievementGroup(levels: [unlocked, locked])

        #expect(group.highestUnlockedLevel == 1)
        #expect(group.nextLockedLevel?.id == Fixture.secondLevelID)
        #expect(group.categoryTitle == "Daily Planning")
        #expect(group.displayTitle == L10n.Achievements.eventsCreated)
        #expect(group.progressFraction == 0.2)
        #expect(!group.progressCopy.isEmpty)
        #expect(!unlocked.levelTitle.isEmpty)
        #expect(unlocked.statusCopy.contains("2023") || unlocked.statusCopy == L10n.Achievements.unlocked)
        #expect(locked.statusCopy == L10n.Achievements.target(10))
    }

    @Test
    func authStateDerivedTitlesAndProgressMatchFlow() {
        var state = AuthState()
        #expect(state.isAuthenticated == false)
        #expect(state.screenTitle == L10n.Profile.loginHeroTitle)
        #expect(state.screenSubtitle == L10n.Profile.loginBody)
        #expect(state.progressLabel == nil)

        state.mode = .register
        state.registerStep = .email
        #expect(state.screenTitle == L10n.Profile.registerEmailStepTitle)
        #expect(state.progressLabel == L10n.Profile.stepProgress(1, 3))

        state.registerStep = .credentials
        #expect(state.screenSubtitle == L10n.Profile.registerPasswordStepBody)
        #expect(state.progressLabel == L10n.Profile.stepProgress(2, 3))

        state.flow = .verificationPending
        #expect(state.screenTitle == L10n.Profile.verifyHeroTitle)
        #expect(state.progressLabel == L10n.Profile.stepProgress(3, 3))

        state.flow = .forgotPassword
        #expect(state.screenTitle == L10n.Profile.forgotPasswordHeroTitle)
        #expect(state.progressLabel == nil)

        state.session = Fixture.authenticatedSession()
        #expect(state.isAuthenticated)
    }

    @Test
    func lightweightStateContainersExposeCountsAndDefaults() {
        let achievementsState = AchievementsState(
            accessToken: "token",
            groups: [
                Fixture.achievementGroup(),
                Fixture.achievementGroup(groupCode: "active_days", currentValue: 1)
            ]
        )
        #expect(achievementsState.totalUnlockedCount == 2)
        #expect(achievementsState.totalLevelCount == 4)
    }
}
