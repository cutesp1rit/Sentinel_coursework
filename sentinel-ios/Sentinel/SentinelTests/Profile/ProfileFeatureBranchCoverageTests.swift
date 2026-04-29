import SentinelUI
import SentinelPlatformiOS
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct ProfileFeatureBranchCoverageTests {
    @Test
    func displayNameDeletePromptAndSessionBranchesUpdateState() async {
        var state = ProfileFeature.State()
        #expect(state.displayName == L10n.App.title)

        state.userEmail = "john_smith.dev@example.com"
        #expect(state.displayName == "John Smith Dev")

        let store = TestStore(initialState: state) {
            ProfileFeature()
        }

        await store.send(.deletePromptVisibilityChanged(true)) {
            $0.isDeletePromptVisible = true
        }

        await store.send(.sessionChanged(Fixture.authenticatedSession(email: "profile@example.com"))) {
            $0.accessToken = "access-token"
            $0.userEmail = "profile@example.com"
        }
    }

    @Test
    func onAppearWithoutTokenAndPromptNoopBranchesStayStable() async {
        var initialState = ProfileFeature.State()
        initialState.defaultPromptTemplate = "Saved"
        initialState.lastSavedDefaultPromptTemplate = "Saved"

        let store = TestStore(initialState: initialState) {
            ProfileFeature()
        }

        await store.send(.onAppear)
        #expect(store.state.isLoading == false)

        await store.send(.promptEditingEnded)
        #expect(store.state.isSavingPrompt == false)
    }

    @Test
    func environmentAndLogoutBranchesPersistSettingsAndSurfaceFailure() async {
        let saved = Box<[AppSettings]>([])
        let logoutStore = TestStore(
            initialState: ProfileFeature.State(accessToken: "token")
        ) {
            ProfileFeature()
        } withDependencies: {
            $0.appSettingsClient.load = { await MainActor.run { .defaultValue } }
            $0.appSettingsClient.save = { settings in
                saved.value.append(settings)
            }
            $0.sessionStorageClient.clear = {
                struct SampleError: LocalizedError {
                    var errorDescription: String? { "Clear failed" }
                }
                throw SampleError()
            }
        }
        logoutStore.exhaustivity = .off

        await logoutStore.send(.environmentChanged(.production)) {
            $0.selectedEnvironment = .production
        }
        await logoutStore.receive(.loaded(AppSettings(
            defaultPromptTemplate: "",
            lastActiveChatID: nil,
            lastActiveChatOpenedAt: nil,
            selectedEnvironment: .production
        ))) {
            $0.defaultPromptTemplate = ""
            $0.lastSavedDefaultPromptTemplate = ""
            $0.selectedEnvironment = .production
            $0.isLoading = false
            $0.isSavingPrompt = false
        }

        #expect(saved.value.last?.selectedEnvironment == .production)

        await logoutStore.send(.logoutTapped) {
            $0.errorMessage = nil
            $0.isLoading = true
        }
        await logoutStore.receive(.logoutFailed("Clear failed")) {
            $0.errorMessage = "Clear failed"
            $0.isDeletingAccount = false
            $0.isLoading = false
        }
    }
}
