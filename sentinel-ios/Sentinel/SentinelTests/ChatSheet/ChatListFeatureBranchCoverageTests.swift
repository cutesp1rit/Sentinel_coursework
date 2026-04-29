import SentinelUI
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct ChatListFeatureBranchCoverageTests {
    @Test
    func signedOutAndLoadedNoopBranchesStayStable() async {
        let signedOutStore = TestStore(initialState: ChatListFeature.State()) {
            ChatListFeature()
        }

        await signedOutStore.send(.sheetPresented)
        await signedOutStore.send(.onAppear)
        await signedOutStore.send(.chatDeleteRequested(Fixture.chatID))

        var loadedState = ChatListFeature.State()
        loadedState.accessToken = "token"
        loadedState.hasLoaded = true
        let loadedStore = TestStore(initialState: loadedState) {
            ChatListFeature()
        }

        await loadedStore.send(.onAppear)
        #expect(loadedStore.state.hasLoaded)
        #expect(loadedStore.state.isLoading == false)
    }

    @Test
    func newChatRowTapAndMismatchedRequestTokensCoverBranches() async {
        let saveCalls = Box<[AppSettings]>([])
        var initialState = ChatListFeature.State()
        initialState.accessToken = "token"
        initialState.activeChatID = Fixture.chatID
        initialState.chats = [
            ChatListItem(chat: Fixture.chat(id: Fixture.chatID, title: "Today")),
            ChatListItem(chat: Fixture.chat(id: Fixture.secondUserID, title: "Inbox"))
        ]

        let store = TestStore(initialState: initialState) {
            ChatListFeature()
        } withDependencies: {
            $0.appSettingsClient.load = { await MainActor.run { .defaultValue } }
            $0.appSettingsClient.save = { settings in
                saveCalls.value.append(settings)
            }
        }
        store.exhaustivity = .off

        await store.send(.rowTapped(Fixture.secondUserID)) {
            $0.activeChatID = Fixture.secondUserID
        }
        await store.receive(.delegate(.activeChatChanged(Fixture.secondUserID)))

        await store.send(.newChatTapped) {
            $0.activeChatID = nil
        }
        await store.receive(.delegate(.activeChatChanged(nil)))

        await store.send(.chatDeleteFailed("Ignore", requestToken: "other"))
        #expect(store.state.errorMessage == nil)

        await store.send(.chatsFailed("Ignore", requestToken: "other"))
        #expect(store.state.errorMessage == nil)

        #expect(saveCalls.value.isEmpty == false)
    }

    @Test
    func recentChatResolvedSameChatOnlyReloadsAndForceNewChatBranchSelectsPreferred() async {
        let inbox = Fixture.chat(id: Fixture.secondUserID, title: "Inbox")
        var state = ChatListFeature.State()
        state.accessToken = "token"
        state.activeChatID = Fixture.secondUserID
        state.chats = [ChatListItem(chat: inbox)]

        let store = TestStore(initialState: state) {
            ChatListFeature()
        } withDependencies: {
            $0.appSettingsClient.load = { await MainActor.run { .defaultValue } }
            $0.appSettingsClient.save = { _ in }
            $0.chatClient.listChats = { _ in [inbox] }
        }
        store.exhaustivity = .off

        await store.send(.recentChatResolved(Fixture.secondUserID))
        await store.receive(.reload(preferredActiveChatID: Fixture.secondUserID, forceNewChat: false)) {
            $0.errorMessage = nil
            $0.isLoading = true
        }
        await store.receive(.chatsLoaded([inbox], preferredActiveChatID: Fixture.secondUserID, forceNewChat: false, requestToken: "token")) {
            $0.chats = [ChatListItem(chat: inbox)]
            $0.errorMessage = nil
            $0.hasLoaded = true
            $0.isLoading = false
        }

        await store.send(.chatsLoaded([inbox], preferredActiveChatID: nil, forceNewChat: true, requestToken: "token")) {
            $0.chats = [ChatListItem(chat: inbox)]
            $0.errorMessage = nil
            $0.hasLoaded = true
            $0.isLoading = false
            $0.activeChatID = nil
        }
        await store.receive(.delegate(.activeChatChanged(nil)))
    }
}
