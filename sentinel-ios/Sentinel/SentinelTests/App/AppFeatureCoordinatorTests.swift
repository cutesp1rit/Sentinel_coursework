import SentinelUI
import SentinelCore
import ComposableArchitecture
import CoreGraphics
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct AppFeatureCoordinatorTests {
    private func makeStore(initialState: AppFeature.State) -> TestStore<AppFeature.State, AppFeature.Action> {
        TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.appSettingsClient.load = { await MainActor.run { .defaultValue } }
            $0.appSettingsClient.save = { _ in }
            $0.achievementsClient.loadAchievements = { _ in [] }
            $0.batteryClient.evaluate = { _, _ in .hidden }
            $0.batteryClient.evaluateDay = { _ in .hidden }
            $0.calendarSyncClient.loadUpcoming = { .init(access: .notRequested, items: []) }
            $0.calendarSyncClient.sync = { _ in .init() }
            $0.chatClient.listChats = { _ in [] }
            $0.chatClient.listMessages = { _, _, _, _ in ([], false) }
            $0.sessionStorageClient.load = { nil }
            $0.sessionStorageClient.clear = {}
            $0.authClient.getMe = { _ in Fixture.user() }
        }
    }

    @Test
    func taskAndAuthRestorationBranchesCoordinatePresentationAndSessions() async {
        let store = makeStore(initialState: AppFeature.State())
        store.exhaustivity = .off

        await store.send(.task)
        await store.receive(.auth(.restoreRequested)) {
            $0.auth.hasAttemptedRestore = true
            $0.auth.errorMessage = nil
            $0.auth.isRestoring = true
        }

        await store.send(.auth(.restoredSession(nil))) {
            $0.home.accessToken = nil
            $0.home.userEmail = nil
            $0.profile.accessToken = nil
            $0.profile.userEmail = nil
            $0.rebalance.accessToken = ""
            $0.isAuthFlowPresented = false
            $0.isProfileSheetPresented = false
            $0.isChatSheetPresented = false
            $0.isRebalanceSheetPresented = false
        }
        await store.receive(.home(.sessionChanged(nil)))
        await store.receive(.profile(.sessionChanged(nil)))

        let session = Fixture.authenticatedSession()
        await store.send(.auth(.submitSucceeded(session))) {
            $0.auth.email = "jane.doe@example.com"
            $0.auth.errorMessage = nil
            $0.auth.flow = .auth
            $0.auth.mode = .login
            $0.auth.registerStep = .email
            $0.auth.isSubmitting = false
            $0.auth.password = ""
            $0.auth.confirmPassword = ""
            $0.auth.resetToken = ""
            $0.auth.verificationToken = ""
            $0.auth.session = session
            $0.auth.statusMessage = nil
            $0.auth.verificationRequiredEmail = nil
            $0.rebalance.accessToken = "access-token"
            $0.isAuthFlowPresented = false
            $0.isChatSheetPresented = true
        }
        await store.receive(.chatSheet(.accessTokenChanged("access-token")))
        await store.receive(.home(.sessionChanged(session))) {
            $0.home.accessToken = "access-token"
            $0.home.userEmail = "jane.doe@example.com"
        }
        await store.receive(.profile(.sessionChanged(session))) {
            $0.profile.accessToken = "access-token"
            $0.profile.userEmail = "jane.doe@example.com"
        }
    }

    @Test
    func homePresentationBranchesDriveAuthProfileChatAndRebalance() async {
        var state = AppFeature.State()
        state.auth.session = Fixture.authenticatedSession()
        state.isChatSheetPresented = true

        let store = makeStore(initialState: state)
        store.exhaustivity = .off

        await store.send(.home(.chatTapped))
        #expect(store.state.isChatSheetPresented)

        await store.send(.home(.profileTapped)) {
            $0.wasChatSheetPresentedBeforeProfile = true
            $0.isChatSheetPresented = false
            $0.isProfileSheetPresented = true
        }

        await store.send(.profileSheetDismissed) {
            $0.isProfileSheetPresented = false
            $0.isChatSheetPresented = true
            $0.wasChatSheetPresentedBeforeProfile = false
        }

        await store.send(.home(.rebalanceTapped)) {
            $0.wasChatSheetPresentedBeforeRebalance = true
            $0.isChatSheetPresented = false
            $0.isProfileSheetPresented = false
            $0.rebalance = RebalanceFeature.State(accessToken: "access-token")
            $0.isRebalanceSheetPresented = true
        }

        await store.send(.rebalanceSheetDismissed) {
            $0.isRebalanceSheetPresented = false
            $0.isChatSheetPresented = true
            $0.wasChatSheetPresentedBeforeRebalance = false
        }
    }

    @Test
    func signedOutHomeActionsOpenAuthFlowAndDismissalsUpdateFlags() async {
        let store = makeStore(initialState: AppFeature.State())

        await store.send(.home(.profileTapped)) {
            $0.auth.flow = .auth
            $0.auth.mode = .login
            $0.auth.registerStep = .email
            $0.isAuthFlowPresented = true
        }

        await store.send(.home(.signInTapped))
        #expect(store.state.auth.mode == .login)
        #expect(store.state.isAuthFlowPresented)

        await store.send(.home(.createAccountTapped)) {
            $0.auth.flow = .auth
            $0.auth.mode = .register
            $0.auth.registerStep = .email
            $0.isAuthFlowPresented = true
        }

        await store.send(.authFlowDismissed) {
            $0.isAuthFlowPresented = false
        }

        await store.send(.authFlowPresentationChanged(true)) {
            $0.isAuthFlowPresented = true
        }

        await store.send(.chatSheetPresentationChanged(true))
        #expect(store.state.isChatSheetPresented == false)

        await store.send(.profileSheetPresentationChanged(true)) {
            $0.isProfileSheetPresented = true
        }

        await store.send(.rebalanceSheetPresentationChanged(true)) {
            $0.isRebalanceSheetPresented = true
        }

        await store.send(.chatSheetDismissed)
        #expect(store.state.isChatSheetPresented == false)
    }

    @Test
    func coordinatorDelegateBranchesRefreshHomeAndClosePresentation() async {
        var state = AppFeature.State()
        state.auth.session = Fixture.authenticatedSession()
        state.isRebalanceSheetPresented = true
        state.isChatSheetPresented = true
        state.wasChatSheetPresentedBeforeRebalance = true
        state.isProfileSheetPresented = true

        let store = makeStore(initialState: state)
        store.exhaustivity = .off

        await store.send(.rebalance(.delegate(.close))) {
            $0.isRebalanceSheetPresented = false
            $0.isChatSheetPresented = true
            $0.wasChatSheetPresentedBeforeRebalance = false
        }

        var appliedState = state
        appliedState.isRebalanceSheetPresented = true
        let appliedStore = makeStore(initialState: appliedState)
        appliedStore.exhaustivity = .off

        await appliedStore.send(.rebalance(.delegate(.applied))) {
            $0.isRebalanceSheetPresented = false
            $0.isChatSheetPresented = false
            $0.wasChatSheetPresentedBeforeRebalance = false
        }
        await appliedStore.receive(.home(.onAppear))

        await appliedStore.send(.chatSheet(.delegate(.suggestionApplyCompleted)))
        await appliedStore.receive(.home(.onAppear))

        await appliedStore.send(.profile(.delegate(.sessionEnded))) {
            $0.isProfileSheetPresented = false
            $0.isChatSheetPresented = false
            $0.isRebalanceSheetPresented = false
        }
        await appliedStore.receive(.auth(.restoredSession(nil))) {
            $0.home.accessToken = nil
            $0.home.userEmail = nil
            $0.profile.accessToken = nil
            $0.profile.userEmail = nil
            $0.rebalance.accessToken = ""
            $0.isAuthFlowPresented = false
            $0.isProfileSheetPresented = false
            $0.isChatSheetPresented = false
            $0.isRebalanceSheetPresented = false
        }
    }

    @Test
    func appStateInsetHeightMatchesDetents() {
        var state = AppFeature.State()
        #expect(state.chatSheetInsetHeight(containerHeight: 800) == 0)

        state.isChatSheetPresented = true
        state.chatSheet.detent = .collapsed
        #expect(state.chatSheetInsetHeight(containerHeight: 800) == AppGrid.value(24))

        state.chatSheet.detent = .medium
        #expect(state.chatSheetInsetHeight(containerHeight: 800) == max(CGFloat(800) * 0.56, 420))

        state.chatSheet.detent = .large
        #expect(state.chatSheetInsetHeight(containerHeight: 800) == CGFloat(800) * 0.82)
    }
}
