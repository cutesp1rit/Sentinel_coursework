import SentinelUI
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct BranchCoverageTests {
    @Test
    func homeBatteryDisplaySnapshotsCoverAllStates() {
        let hidden = HomeBatteryState.hidden.displaySnapshot
        #expect(hidden.headline == L10n.Home.batteryUnavailableTitle)

        let placeholder = HomeBatteryState.placeholder.displaySnapshot
        #expect(placeholder.headline == L10n.Home.batteryPlaceholderTitle)

        let enable = HomeBatteryState.setupRequired(.enableAppleIntelligence).displaySnapshot
        #expect(enable.headline == L10n.Home.batteryEnableTitle)

        let download = HomeBatteryState.setupRequired(.downloadModel).displaySnapshot
        #expect(download.headline == L10n.Home.batteryDownloadTitle)

        let ready = HomeBatteryState.ready(.init(headline: "70%", detail: "Balanced", percentage: 70)).displaySnapshot
        #expect(ready.percentage == 70)
    }

    @Test
    func chatListFeatureHelpersCoverTitleAndErrors() {
        var state = ChatListFeature.State()
        #expect(state.activeChatTitle == L10n.ChatSheet.newChat)

        state.activeChatID = Fixture.chatID
        state.chats = [ChatListItem(chat: Fixture.chat(id: Fixture.chatID, title: "Today"))]
        #expect(state.activeChatTitle == "Today")

        state.activeChatID = Fixture.secondUserID
        #expect(state.activeChatTitle == L10n.ChatSheet.newChat)

        let apiError = APIError(code: "BAD", message: "Readable", details: nil)
        #expect(ChatListFeature.errorMessage(for: apiError) == "Readable")
    }

    @Test
    func calendarReducerSupportCoversErrorAndDequeueBranches() {
        let apiError = APIError(code: "BAD", message: "Readable", details: nil)
        #expect(CalendarReducer.errorMessage(for: apiError) == "Readable")

        var state = CalendarState(accessToken: "token")
        state.selectedDate = Fixture.referenceDate
        state.events = [Fixture.event()]
        let validID = CalendarState.sectionID(for: Fixture.referenceDate)
        state.queuedDayBatterySectionIDs = ["missing", validID]

        let effect = CalendarReducer.dequeueDayBatteryEffect(
            state: &state,
            batteryClient: BatteryClient(
                evaluate: { _, _ in .hidden },
                evaluateDay: { _ in .ready(42) }
            )
        )
        #expect(state.activeDayBatterySectionID == validID)
        #expect(state.dayBatteryCache[validID]?.state == .loading)
        #expect(String(describing: effect).isEmpty == false)
    }

    @Test
    func chatSuggestionFallbackBranchesWithoutPayloadOrSnapshot() {
        let create = ChatSuggestion(
            actionIndex: 0,
            action: EventAction(action: .create, eventId: nil, payload: nil, status: .pending, eventSnapshot: nil)
        )
        #expect(create.title == "Create Event")
        #expect(create.location == "Create proposal")

        let update = ChatSuggestion(
            actionIndex: 1,
            action: EventAction(action: .update, eventId: Fixture.eventID, payload: nil, status: .pending, eventSnapshot: nil)
        )
        #expect(update.title == "Update Event")
        #expect(update.location == "Update proposal")

        let delete = ChatSuggestion(
            actionIndex: 2,
            action: EventAction(action: .delete, eventId: Fixture.secondEventID, payload: nil, status: .pending, eventSnapshot: nil)
        )
        #expect(delete.title == "Delete Event")
        #expect(delete.location == "Delete proposal")
    }

    @Test
    func apiModelConverterChatBranchesCoverChatDTOAndNonUserRoles() {
        let chat = APIModelConverter.convert(
            ChatDTO(
                id: Fixture.chatID,
                userId: Fixture.userID,
                title: "Today",
                lastMessageAt: Fixture.referenceDate,
                createdAt: Fixture.referenceDate,
                updatedAt: Fixture.referenceDate
            )
        )
        #expect(chat.id == Fixture.chatID)

        let assistant = APIModelConverter.convert(
            ChatMessageDTO(
                id: Fixture.messageID,
                chatId: Fixture.chatID,
                role: "assistant",
                contentText: "Assistant reply",
                contentStructured: .eventActions(
                    EventActionsContentDTO(
                        type: "event_actions",
                        actions: [
                            EventActionDTO(
                                action: "create",
                                eventId: nil,
                                eventSnapshot: nil,
                                payload: EventMutationPayloadDTO(
                                    title: "Planning",
                                    description: nil,
                                    startAt: Fixture.referenceDate,
                                    endAt: Fixture.secondaryDate,
                                    allDay: false,
                                    type: "event",
                                    location: "Office",
                                    isFixed: false,
                                    source: "ai"
                                ),
                                status: "pending"
                            )
                        ]
                    )
                ),
                aiModel: "gpt",
                createdAt: Fixture.referenceDate
            )
        )
        #expect(assistant.role == .assistant)
        #expect(assistant.content.eventActions?.actions.count == 1)

        let system = APIModelConverter.convert(
            ChatMessageDTO(
                id: UUID(),
                chatId: Fixture.chatID,
                role: "system",
                contentText: "System note",
                contentStructured: nil,
                aiModel: nil,
                createdAt: Fixture.referenceDate
            )
        )
        #expect(system.role == .system)

        let tool = APIModelConverter.convert(
            ChatMessageDTO(
                id: UUID(),
                chatId: Fixture.chatID,
                role: "tool",
                contentText: "Tool output",
                contentStructured: nil,
                aiModel: nil,
                createdAt: Fixture.referenceDate
            )
        )
        #expect(tool.role == .tool)
    }

    @Test
    func chatThreadFeatureRetryAndResetBranches() async {
        let failedAttachment = ChatComposerAttachment(
            data: Data([0x01]),
            previewData: nil,
            filename: "image.png",
            mimeType: "image/png"
        )
        let failedMessage = ChatThreadMessage(
            id: Fixture.messageID,
            role: .user,
            text: "Retry",
            images: [failedAttachment.imageAttachment],
            deliveryState: .failed
        )

        var initialState = ChatThreadFeature.State()
        initialState.accessToken = "token"
        initialState.messages = [failedMessage]

        let store = TestStore(initialState: initialState) {
            ChatThreadFeature()
        } withDependencies: {
            $0.appSettingsClient.load = {
                await MainActor.run {
                    AppSettings(
                        defaultPromptTemplate: "",
                        lastActiveChatID: nil,
                        lastActiveChatOpenedAt: nil,
                        selectedEnvironment: .local
                    )
                }
            }
            $0.chatClient.createChat = { _, _ in Fixture.chat() }
            $0.chatClient.uploadImage = { _, filename, mimeType, _, _ in
                ChatImageAttachment(url: "https://example.com/\(filename)", filename: filename, localData: nil, mimeType: mimeType, previewData: nil)
            }
            $0.chatClient.sendMessage = { _, _, _, _, _ in Fixture.chatMessage(role: .assistant, markdownText: "Done", actions: nil, images: []) }
            $0.chatClient.listChats = { _ in [Fixture.chat()] }
            $0.chatClient.listMessages = { _, _, _, _ in ([Fixture.chatMessage(role: .assistant, markdownText: "Done", actions: nil, images: [])], false) }
        }
        store.exhaustivity = .off

        await store.send(.failedMessageRetryTapped(Fixture.messageID))
        #expect(store.state.isSending)
        #expect(store.state.messages.first?.deliveryState == .sending)

        await store.send(.accessTokenChanged(nil)) {
            $0 = .init()
        }
    }
}
