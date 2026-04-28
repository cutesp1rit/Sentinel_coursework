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
    func homeReducerOnAppearLoadsScheduleAchievementsAndBattery() async {
        var initialState = HomeState()
        initialState.accessToken = "token"

        let groups = [Fixture.achievementGroup()]
        let snapshot = CalendarSyncClient.UpcomingSnapshot(access: .notRequested, items: [])

        let store = TestStore(initialState: initialState) {
            HomeReducer()
        } withDependencies: {
            $0.batteryClient.evaluate = { _, _ in .placeholder }
            $0.calendarSyncClient.loadUpcoming = {
                try? await Task.sleep(for: .milliseconds(20))
                return snapshot
            }
            $0.achievementsClient.loadAchievements = { token in
                #expect(token == "token")
                try? await Task.sleep(for: .milliseconds(40))
                return groups
            }
        }

        await store.send(.onAppear) {
            $0.schedule.isLoading = true
            $0.schedule.errorMessage = nil
        }

        await store.receive(.batteryUpdated(.placeholder)) {
            $0.battery = .placeholder
        }

        await store.receive(.scheduleLoaded(snapshot)) {
            $0.schedule.isLoading = false
            $0.schedule.errorMessage = nil
            $0.schedule.access = .notRequested
            $0.schedule.upcomingItems = []
        }

        await store.receive(.batteryUpdated(.placeholder))

        await store.receive(.achievementsLoaded(groups)) {
            $0.achievementGroups = groups
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
}
