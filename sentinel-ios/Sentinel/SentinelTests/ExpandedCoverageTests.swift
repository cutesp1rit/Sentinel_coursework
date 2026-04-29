import SentinelUI
import SentinelPlatformiOS
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct ExpandedCoverageTests {
    @Test
    func appSettingsTrackRecentActiveChatWithinTenMinuteWindow() {
        let openedAt = Fixture.referenceDate
        let validReference = openedAt.addingTimeInterval(9 * 60 + 59)
        let expiredReference = openedAt.addingTimeInterval(10 * 60)

        let settings = AppSettings(
            defaultPromptTemplate: "Prompt",
            lastActiveChatID: Fixture.chatID,
            lastActiveChatOpenedAt: openedAt,
            selectedEnvironment: .local
        )

        #expect(settings.recentActiveChatID(referenceDate: validReference) == Fixture.chatID)
        #expect(settings.recentActiveChatID(referenceDate: expiredReference) == nil)

        var mutable = settings
        mutable.markActiveChat(nil, at: Fixture.secondaryDate)
        #expect(mutable.lastActiveChatID == nil)
        #expect(mutable.lastActiveChatOpenedAt == nil)
    }

    @Test
    func batteryScheduleSummaryMergesOverlapAndBuildsFallbackAndAssessmentStates() {
        let entries = [
            BatteryScheduleEntry(endDate: Fixture.secondaryDate, startDate: Fixture.referenceDate),
            BatteryScheduleEntry(endDate: Fixture.tertiaryDate, startDate: Fixture.referenceDate.addingTimeInterval(30 * 60)),
            BatteryScheduleEntry(endDate: Fixture.quaternaryDate.addingTimeInterval(30 * 60), startDate: Fixture.quaternaryDate)
        ]

        let summary = BatteryScheduleSummary.make(
            from: entries,
            windowStart: Fixture.referenceDate,
            windowEnd: Fixture.referenceDate.addingTimeInterval(6 * 60 * 60)
        )

        #expect(summary.eventCount == 3)
        #expect(summary.busyBlocks.count == 2)
        #expect(summary.busyBlocks.first?.itemCount == 2)
        #expect(summary.totalBusyHours == 2.5)
        #expect(summary.longestFreeGapHours == 2.5)
        #expect(summary.homePrompt.contains("Busy blocks after merging overlaps: 2"))
        #expect(summary.dayPrompt.contains("Return only the percentage."))

        let emptyAssessmentState = summary.makeBatteryState(
            from: ResourceBatteryAssessment(detail: " \n ", percentage: 140)
        )
        if case let .ready(snapshot) = emptyAssessmentState {
            #expect(snapshot.percentage == 100)
            #expect(snapshot.detail.isEmpty == false)
        } else {
            Issue.record("Expected ready battery snapshot")
        }

        let fallback = summary.fallbackBatteryState()
        if case let .ready(snapshot) = fallback {
            #expect((0...100).contains(snapshot.percentage ?? -1))
            #expect(snapshot.headline.hasSuffix("%"))
        } else {
            Issue.record("Expected ready fallback battery snapshot")
        }
    }

    @Test
    func calendarEditorPayloadTrimsFieldsAndDropsEndDateForReminder() {
        var editor = CalendarState.Editor(event: nil)
        editor.title = "  Inbox zero  "
        editor.description = "  \n  "
        editor.location = "  Desk  "
        editor.startDate = Fixture.referenceDate
        editor.endDate = Fixture.secondaryDate
        editor.allDay = false
        editor.type = .reminder

        let payload = editor.payload
        #expect(payload.title == "Inbox zero")
        #expect(payload.description == nil)
        #expect(payload.location == "Desk")
        #expect(payload.endAt == nil)
        #expect(payload.source == "user")

        let existing = CalendarState.Editor(event: Fixture.event())
        #expect(existing.payload.source == nil)
    }

    @Test
    func rebalanceSupportBuildsSortedDayItemsAndTrimsPrompt() {
        let today = Calendar.current.startOfDay(for: .now)
        let sameDayLater = today.addingTimeInterval(5 * 60 * 60)
        let sameDayEarlier = today.addingTimeInterval(2 * 60 * 60)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today

        let items = RebalanceFeature.makeDayItems(
            from: [
                Fixture.event(id: Fixture.secondEventID, startAt: sameDayLater, endAt: sameDayLater.addingTimeInterval(60 * 60)),
                Fixture.event(id: Fixture.eventID, startAt: sameDayEarlier, endAt: sameDayEarlier.addingTimeInterval(60 * 60)),
                Fixture.event(id: UUID(), startAt: nextDay.addingTimeInterval(60 * 60), endAt: nextDay.addingTimeInterval(2 * 60 * 60))
            ],
            today: today
        )

        let todayItem = items.first { $0.id == CalendarState.sectionID(for: today) }
        #expect(todayItem?.isToday == true)
        #expect(todayItem?.eventCount == 2)
        #expect(todayItem?.batteryRequest.entries.map(\.startDate) == [sameDayEarlier, sameDayLater])

        #expect(trimmedToNil("  ") == nil)
        #expect(trimmedToNil("  Focus  ") == "Focus")
    }

    @Test
    func achievementsReducerHandlesFailureThenRetrySuccess() async {
        let attempts = Box(0)
        let loadedGroups = [Fixture.achievementGroup(groupCode: "active_days", currentValue: 4)]

        let store = TestStore(
            initialState: AchievementsState(accessToken: "token")
        ) {
            AchievementsReducer()
        } withDependencies: {
            $0.achievementsClient.loadAchievements = { _ in
                attempts.value += 1
                if attempts.value == 1 {
                    throw APIError(code: "load_failed", message: "Try again", details: nil)
                }
                return loadedGroups
            }
        }

        await store.send(.onAppear) {
            $0.errorMessage = nil
            $0.isLoading = true
        }
        await store.receive(.achievementsFailed("Try again")) {
            $0.errorMessage = "Try again"
            $0.isLoading = false
        }

        await store.send(.retryTapped) {
            $0.errorMessage = nil
            $0.isLoading = true
        }
        await store.receive(.achievementsLoaded(loadedGroups)) {
            $0.errorMessage = nil
            $0.groups = loadedGroups
            $0.hasLoaded = true
            $0.isLoading = false
        }
    }

    @Test
    func profileFeatureLoadsSettingsAndPersistsTrimmedPrompt() async {
        let savedSettings = Box<[AppSettings]>([])
        let loadedSettings = AppSettings(
            defaultPromptTemplate: "Initial",
            lastActiveChatID: Fixture.chatID,
            lastActiveChatOpenedAt: Fixture.referenceDate,
            selectedEnvironment: .testing
        )

        var initialState = ProfileFeature.State()
        initialState.accessToken = "token"

        let store = TestStore(initialState: initialState) {
            ProfileFeature()
        } withDependencies: {
            $0.appSettingsClient.load = { await MainActor.run { loadedSettings } }
            $0.appSettingsClient.save = { settings in
                savedSettings.value.append(settings)
            }
        }
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(.loaded(loadedSettings)) {
            $0.defaultPromptTemplate = "Initial"
            $0.lastSavedDefaultPromptTemplate = "Initial"
            $0.selectedEnvironment = .testing
            $0.isLoading = false
            $0.isSavingPrompt = false
        }

        await store.send(.defaultPromptChanged("  Refined prompt  ")) {
            $0.defaultPromptTemplate = "  Refined prompt  "
        }
        await store.send(.promptEditingEnded) {
            $0.isSavingPrompt = true
        }
        await store.receive(.promptPersisted("Refined prompt")) {
            $0.lastSavedDefaultPromptTemplate = "Refined prompt"
            $0.defaultPromptTemplate = "Refined prompt"
            $0.isSavingPrompt = false
        }

        #expect(savedSettings.value.last?.defaultPromptTemplate == "Refined prompt")
        #expect(savedSettings.value.last?.selectedEnvironment == .testing)
    }

    @Test
    func profileFeatureDeleteAccountValidatesPasswordAndHandlesSuccess() async {
        var initialState = ProfileFeature.State()
        initialState.accessToken = "token"

        let store = TestStore(initialState: initialState) {
            ProfileFeature()
        } withDependencies: {
            $0.authClient.deleteAccount = { _, _ in }
            $0.sessionStorageClient.clear = {}
        }
        store.exhaustivity = .off

        await store.send(.deleteAccountTapped) {
            $0.errorMessage = L10n.Profile.deleteAccountPasswordRequired
        }

        await store.send(.deleteAccountPasswordChanged(" secret ")) {
            $0.deleteAccountPassword = " secret "
            $0.errorMessage = nil
        }
        await store.send(.deleteAccountTapped) {
            $0.errorMessage = nil
            $0.isDeletingAccount = true
        }
        await store.receive(.deleteAccountCompleted)
        await store.receive(.delegate(.sessionEnded))
    }

    @Test
    func chatListFeatureClearsStateOnLogoutAndRefreshesRecentSelection() async {
        let saveCalls = Box<[AppSettings]>([])
        let recentSettings = AppSettings(
            defaultPromptTemplate: "",
            lastActiveChatID: Fixture.secondUserID,
            lastActiveChatOpenedAt: .now,
            selectedEnvironment: .local
        )

        var initialState = ChatListFeature.State()
        initialState.accessToken = "token"
        initialState.activeChatID = Fixture.chatID
        initialState.chats = [ChatListItem(chat: Fixture.chat(id: Fixture.chatID, title: "Today"))]
        initialState.hasLoaded = true

        let store = TestStore(initialState: initialState) {
            ChatListFeature()
        } withDependencies: {
            $0.appSettingsClient.load = { await MainActor.run { recentSettings } }
            $0.appSettingsClient.save = { settings in
                saveCalls.value.append(settings)
            }
            $0.chatClient.listChats = { _ in [Fixture.chat(id: Fixture.secondUserID, title: "Inbox")] }
        }
        store.exhaustivity = .off

        await store.send(.sheetPresented)
        await store.receive(.recentChatResolved(Fixture.secondUserID)) {
            $0.activeChatID = Fixture.secondUserID
        }
        await store.receive(.delegate(.activeChatChanged(Fixture.secondUserID)))
        await store.receive(.reload(preferredActiveChatID: Fixture.secondUserID, forceNewChat: false)) {
            $0.errorMessage = nil
            $0.isLoading = true
        }
        await store.receive(.chatsLoaded([Fixture.chat(id: Fixture.secondUserID, title: "Inbox")], preferredActiveChatID: Fixture.secondUserID, forceNewChat: false, requestToken: "token")) {
            $0.chats = [ChatListItem(chat: Fixture.chat(id: Fixture.secondUserID, title: "Inbox"))]
            $0.errorMessage = nil
            $0.hasLoaded = true
            $0.isLoading = false
        }

        await store.send(.accessTokenChanged(nil)) {
            $0.accessToken = nil
            $0.activeChatID = nil
            $0.chats = []
            $0.errorMessage = nil
            $0.hasLoaded = false
            $0.isLoading = false
        }

        #expect(saveCalls.value.isEmpty == false)
        #expect(saveCalls.value.last?.lastActiveChatID == Fixture.secondUserID)
    }
}
