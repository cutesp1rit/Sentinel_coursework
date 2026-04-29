import SentinelUI
import SentinelPlatformiOS
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct ReducerFlowTests {
    @Test
    func homeReducerScheduleLoadedMapsItemsAndRefreshesBattery() async {
        var initialState = HomeState()
        initialState.accessToken = "token"

        let snapshot = CalendarSyncClient.UpcomingSnapshot(
            access: .granted,
            items: [
                .init(
                    id: Fixture.eventID,
                    startAt: Fixture.referenceDate,
                    endAt: Fixture.secondaryDate,
                    subtitle: "",
                    title: "Planning"
                )
            ]
        )

        let store = TestStore(initialState: initialState) {
            HomeReducer()
        } withDependencies: {
            $0.batteryClient.evaluate = { items, access in
                #expect(items.count == 1)
                guard case .granted = access else {
                    Issue.record("Expected granted calendar access")
                    return .ready(.init(headline: "80%", detail: "Balanced", percentage: 80))
                }
                return .ready(.init(headline: "80%", detail: "Balanced", percentage: 80))
            }
        }

        await store.send(.scheduleLoaded(snapshot)) {
            $0.schedule.isLoading = false
            $0.schedule.errorMessage = nil
            $0.schedule.access = .granted
            $0.schedule.upcomingItems = [
                HomeScheduleItem(
                    id: Fixture.eventID,
                    endDate: Fixture.secondaryDate,
                    startDate: Fixture.referenceDate,
                    title: "Planning",
                    timeText: HomeReducer.timeText(startAt: Fixture.referenceDate, endAt: Fixture.secondaryDate),
                    subtitle: "Calendar"
                )
            ]
        }

        await store.receive(.batteryUpdated(.ready(.init(headline: "80%", detail: "Balanced", percentage: 80)))) {
            $0.battery = .ready(.init(headline: "80%", detail: "Balanced", percentage: 80))
        }
    }

    @Test
    func homeReducerSessionChangedToNilResetsState() async {
        var initialState = HomeState()
        initialState.accessToken = "token"
        initialState.userEmail = "jane@example.com"
        initialState.achievementGroups = [Fixture.achievementGroup()]
        initialState.schedule.access = .granted
        initialState.schedule.upcomingItems = [
            Fixture.homeItem(title: "Planning", startDate: Fixture.referenceDate, endDate: Fixture.secondaryDate)
        ]
        initialState.battery = .ready(.init(headline: "80%", detail: "Balanced", percentage: 80))

        let store = TestStore(initialState: initialState) {
            HomeReducer()
        }

        await store.send(.sessionChanged(nil)) {
            $0.accessToken = nil
            $0.userEmail = nil
            $0.achievementGroups = []
            $0.schedule = HomeScheduleState()
            $0.battery = .hidden
        }
    }

    @Test
    func chatListFeatureReloadLoadsChatsAndSelectsFirstChat() async {
        var initialState = ChatListFeature.State()
        initialState.accessToken = "token"

        let firstChat = Fixture.chat(id: Fixture.chatID, title: "Today")
        let secondChat = Fixture.chat(id: Fixture.secondUserID, title: "Inbox")

        let store = TestStore(initialState: initialState) {
            ChatListFeature()
        } withDependencies: {
            $0.chatClient.listChats = { token in
                #expect(token == "token")
                return [firstChat, secondChat]
            }
            $0.appSettingsClient.load = { await MainActor.run { .defaultValue } }
            $0.appSettingsClient.save = { _ in }
        }

        await store.send(.reload()) {
            $0.errorMessage = nil
            $0.isLoading = true
        }

        await store.receive(.chatsLoaded([firstChat, secondChat], preferredActiveChatID: nil, forceNewChat: false, requestToken: "token")) {
            $0.chats = [ChatListItem(chat: firstChat), ChatListItem(chat: secondChat)]
            $0.errorMessage = nil
            $0.hasLoaded = true
            $0.isLoading = false
            $0.activeChatID = Fixture.chatID
        }

        await store.receive(.delegate(.activeChatChanged(Fixture.chatID)))
    }

    @Test
    func chatListFeatureDeleteFlowRemovesChatAndUpdatesActiveSelection() async {
        let firstChat = Fixture.chat(id: Fixture.chatID, title: "Today")
        let secondChat = Fixture.chat(id: Fixture.secondUserID, title: "Inbox")

        var initialState = ChatListFeature.State()
        initialState.accessToken = "token"
        initialState.activeChatID = Fixture.chatID
        initialState.chats = [ChatListItem(chat: firstChat), ChatListItem(chat: secondChat)]

        let store = TestStore(initialState: initialState) {
            ChatListFeature()
        } withDependencies: {
            $0.chatClient.deleteChat = { chatID, token in
                #expect(chatID == Fixture.chatID)
                #expect(token == "token")
            }
            $0.appSettingsClient.load = { await MainActor.run { .defaultValue } }
            $0.appSettingsClient.save = { _ in }
        }

        await store.send(.chatDeleteRequested(Fixture.chatID))
        await store.receive(.chatDeleted(Fixture.chatID, requestToken: "token")) {
            $0.chats = [ChatListItem(chat: secondChat)]
            $0.activeChatID = Fixture.secondUserID
        }
        await store.receive(.delegate(.activeChatChanged(Fixture.secondUserID)))
    }

    @Test
    func chatThreadSendFlowTransitionsIntoSendingState() async {
        let createdChat = Fixture.chat(id: Fixture.chatID, title: "Hello")
        let assistantMessage = Fixture.chatMessage(role: .assistant, markdownText: "Reply", actions: nil, images: [])
        let attachment = ChatComposerAttachment(
            data: Data([0x01, 0x02]),
            previewData: Data([0x03]),
            filename: "image.png",
            mimeType: "image/png"
        )

        var initialState = ChatThreadFeature.State()
        initialState.accessToken = "token"
        initialState.draft = "Hello"
        initialState.composerAttachments = [attachment]

        let store = TestStore(initialState: initialState) {
            ChatThreadFeature()
        } withDependencies: {
            $0.appSettingsClient.load = {
                await MainActor.run {
                    AppSettings(
                        defaultPromptTemplate: "Prompt",
                        lastActiveChatID: nil,
                        lastActiveChatOpenedAt: nil,
                        selectedEnvironment: .local
                    )
                }
            }
            $0.chatClient.createChat = { title, token in
                #expect(title == "Hello")
                #expect(token == "token")
                return createdChat
            }
            $0.chatClient.uploadImage = { chatID, filename, mimeType, _, _ in
                #expect(chatID == Fixture.chatID)
                #expect(filename == "image.png")
                #expect(mimeType == "image/png")
                return ChatImageAttachment(
                    url: "https://example.com/image.png",
                    filename: filename,
                    localData: nil,
                    mimeType: mimeType,
                    previewData: nil
                )
            }
            $0.chatClient.sendMessage = { chatID, role, contentText, images, token in
                #expect(chatID == Fixture.chatID)
                #expect(role == "user")
                #expect(contentText?.contains("Hello") == true)
                #expect(images.count == 1)
                #expect(token == "token")
                return assistantMessage
            }
            $0.chatClient.listChats = { _ in [createdChat] }
            $0.chatClient.listMessages = { _, _, _, _ in ([assistantMessage], false) }
        }
        store.exhaustivity = .off

        await store.send(.sendButtonTapped)
        #expect(store.state.pendingLocalMessageID != nil)
        #expect(store.state.activeSendRequestID != nil)
        #expect(store.state.isSending)
        #expect(store.state.errorMessage == nil)
        #expect(store.state.sendStage == .delivering)
        #expect(store.state.shouldAutoScrollToBottom)
        #expect(store.state.draft.isEmpty)
        #expect(store.state.composerAttachments.isEmpty)
        #expect(store.state.messages.count == 1)
        #expect(store.state.messages.first?.deliveryState == .sending)
    }

    @Test
    func chatThreadApplySuggestionsFlowUpdatesMessageAndSyncs() async {
        let pendingAction = Fixture.eventAction(kind: .update, eventId: Fixture.eventID, title: "Updated", status: .pending)
        let updatedMessage = Fixture.chatMessage(
            role: .assistant,
            markdownText: "Updated",
            actions: [Fixture.eventAction(kind: .update, eventId: Fixture.eventID, title: "Updated", status: .accepted)]
        )

        var message = ChatThreadMessage(
            chatMessage: Fixture.chatMessage(
                role: .assistant,
                markdownText: "Original",
                actions: [pendingAction]
            )
        )
        let messageID = message.id
        guard let suggestionID = message.suggestionsPayload?.suggestions.first?.id else {
            Issue.record("Expected a suggestion ID")
            return
        }
        message.suggestionsPayload?.selectedSuggestionIDs = [suggestionID]

        var initialState = ChatThreadFeature.State()
        initialState.accessToken = "token"
        initialState.activeChatID = Fixture.chatID
        initialState.messages = [message]

        let store = TestStore(initialState: initialState) {
            ChatThreadFeature()
        } withDependencies: {
            $0.chatClient.applyActions = { chatID, returnedMessageID, acceptedIndices, token in
                #expect(chatID == Fixture.chatID)
                #expect(returnedMessageID == messageID)
                #expect(acceptedIndices == [0])
                #expect(token == "token")
                return updatedMessage
            }
            $0.eventsClient.listEvents = { _, _, _ in [Fixture.event(id: Fixture.eventID, title: "Updated")] }
            $0.eventsClient.getEvent = { _, _ in Fixture.event(id: Fixture.eventID, title: "Updated") }
            $0.calendarSyncClient.sync = { _ in .init(syncedEventIDs: [Fixture.eventID]) }
            $0.calendarSyncClient.detectConflicts = { _ in [:] }
        }

        await store.send(.addSelectedSuggestionsTapped(messageID)) {
            $0.messages[0].suggestionsPayload?.isApplying = true
            $0.errorMessage = nil
        }

        await store.receive(.suggestionApplyCompleted(messageID: messageID, updatedMessage: updatedMessage, requestToken: "token")) {
            $0.messages[0] = ChatThreadFeature.mergingUpdatedMessage(updatedMessage: updatedMessage, existingMessage: $0.messages[0])
            $0.errorMessage = nil
        }

        await store.receive(.delegate(.suggestionsApplied))
        await store.receive(.refreshSuggestionConflictsRequested(messageID))
    }
}
