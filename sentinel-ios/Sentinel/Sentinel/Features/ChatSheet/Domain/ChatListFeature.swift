import ComposableArchitecture
import Foundation

@Reducer
struct ChatListFeature {
    @Dependency(\.appSettingsClient) var appSettingsClient
    @Dependency(\.chatClient) var chatClient

    @ObservableState
    struct State: Equatable {
        var accessToken: String?
        var activeChatID: UUID?
        var chats: [ChatListItem] = []
        var errorMessage: String?
        var hasLoaded = false
        var isLoading = false

        var activeChatTitle: String {
            guard let activeChatID else { return L10n.ChatSheet.newChat }
            return chats.first(where: { $0.id == activeChatID })?.title ?? L10n.ChatSheet.newChat
        }
    }

    @CasePathable
    enum Action: Equatable {
        case accessTokenChanged(String?)
        case activeChatChanged(UUID?)
        case chatDeleteFailed(String, requestToken: String)
        case chatDeleteRequested(UUID)
        case chatDeleted(UUID, requestToken: String)
        case chatsFailed(String, requestToken: String)
        case chatsLoaded([Chat], preferredActiveChatID: UUID?, forceNewChat: Bool, requestToken: String)
        case newChatTapped
        case onAppear
        case recentChatResolved(UUID?)
        case reload(preferredActiveChatID: UUID? = nil, forceNewChat: Bool = false)
        case rowTapped(UUID)
        case sheetPresented
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case activeChatChanged(UUID?)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .accessTokenChanged(token):
                state.accessToken = token
                guard token != nil else {
                    state.activeChatID = nil
                    state.chats = []
                    state.errorMessage = nil
                    state.hasLoaded = false
                    state.isLoading = false
                    return .none
                }
                state.hasLoaded = false
                return .send(.reload())

            case let .activeChatChanged(chatID):
                state.activeChatID = chatID
                return persistActiveChatEffect(chatID: chatID)

            case let .chatDeleteFailed(message, requestToken):
                guard state.accessToken == requestToken else { return .none }
                state.errorMessage = message
                return .none

            case let .chatDeleteRequested(chatID):
                guard let accessToken = state.accessToken else { return .none }
                return .run { [chatClient] send in
                    do {
                        try await chatClient.deleteChat(chatID, accessToken)
                        await send(.chatDeleted(chatID, requestToken: accessToken))
                    } catch {
                        await send(.chatDeleteFailed(Self.errorMessage(for: error), requestToken: accessToken))
                    }
                }

            case let .chatDeleted(chatID, requestToken):
                guard state.accessToken == requestToken else { return .none }
                state.chats.removeAll { $0.id == chatID }
                let nextActiveChatID = state.activeChatID == chatID ? state.chats.first?.id : state.activeChatID
                state.activeChatID = nextActiveChatID
                return .merge(
                    persistActiveChatEffect(chatID: nextActiveChatID),
                    .send(.delegate(.activeChatChanged(nextActiveChatID)))
                )

            case let .chatsFailed(message, requestToken):
                guard state.accessToken == requestToken else { return .none }
                state.errorMessage = message
                state.isLoading = false
                return .none

            case let .chatsLoaded(chats, preferredActiveChatID, forceNewChat, requestToken):
                guard state.accessToken == requestToken else { return .none }
                state.chats = chats.map(ChatListItem.init)
                state.errorMessage = nil
                state.hasLoaded = true
                state.isLoading = false

                let nextActiveChatID: UUID? = if forceNewChat {
                    preferredActiveChatID
                } else {
                    preferredActiveChatID
                        ?? state.activeChatID.flatMap { activeChatID in
                            state.chats.contains(where: { $0.id == activeChatID }) ? activeChatID : nil
                        }
                        ?? state.chats.first?.id
                }

                guard nextActiveChatID != state.activeChatID else { return .none }
                state.activeChatID = nextActiveChatID
                return .merge(
                    persistActiveChatEffect(chatID: nextActiveChatID),
                    .send(.delegate(.activeChatChanged(nextActiveChatID)))
                )

            case .newChatTapped:
                state.activeChatID = nil
                return .merge(
                    persistActiveChatEffect(chatID: nil),
                    .send(.delegate(.activeChatChanged(nil)))
                )

            case .onAppear:
                guard state.accessToken != nil, !state.hasLoaded else { return .none }
                return .send(.reload())

            case let .reload(preferredActiveChatID, forceNewChat):
                guard let accessToken = state.accessToken, !state.isLoading else { return .none }
                state.errorMessage = nil
                state.isLoading = true
                return .run { [chatClient] send in
                    do {
                        let chats = try await chatClient.listChats(accessToken)
                        await send(
                            .chatsLoaded(
                                chats,
                                preferredActiveChatID: preferredActiveChatID,
                                forceNewChat: forceNewChat,
                                requestToken: accessToken
                            )
                        )
                    } catch {
                        await send(.chatsFailed(Self.errorMessage(for: error), requestToken: accessToken))
                    }
                }

            case let .recentChatResolved(chatID):
                if state.activeChatID != chatID {
                    state.activeChatID = chatID
                    return .merge(
                        persistActiveChatEffect(chatID: chatID),
                        .send(.delegate(.activeChatChanged(chatID))),
                        .send(.reload(preferredActiveChatID: chatID, forceNewChat: chatID == nil))
                    )
                }
                return .merge(
                    persistActiveChatEffect(chatID: chatID),
                    .send(.reload(preferredActiveChatID: chatID, forceNewChat: chatID == nil))
                )

            case let .rowTapped(chatID):
                state.activeChatID = chatID
                return .merge(
                    persistActiveChatEffect(chatID: chatID),
                    .send(.delegate(.activeChatChanged(chatID)))
                )

            case .sheetPresented:
                guard state.accessToken != nil else { return .none }
                return .run { [appSettingsClient] send in
                    let settings = await appSettingsClient.load()
                    await send(.recentChatResolved(settings.recentActiveChatID()))
                }

            case .delegate:
                return .none
            }
        }
    }
}

private extension ChatListFeature {
    func persistActiveChatEffect(chatID: UUID?) -> Effect<Action> {
        .run { [appSettingsClient] _ in
            var settings = await appSettingsClient.load()
            settings.markActiveChat(chatID)
            await appSettingsClient.save(settings)
        }
    }

    static func errorMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        return error.localizedDescription
    }
}
