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

    @Test
    func authSupportHelpersValidateAndResetFields() {
        #expect(validateEmail("") == L10n.Profile.emailRequired)
        #expect(validateEmail("invalid") == L10n.Profile.emailInvalid)
        #expect(validateEmail("jane@example.com") == nil)

        #expect(validateLogin(email: "invalid", password: "secret") == L10n.Profile.emailInvalid)
        #expect(validateLogin(email: "jane@example.com", password: "") == L10n.Profile.passwordRequired)
        #expect(validateLogin(email: "jane@example.com", password: "secret") == nil)

        #expect(validateRegistration(email: "jane@example.com", password: "", confirmPassword: "") == L10n.Profile.passwordTooShort)
        #expect(validateRegistration(email: "jane@example.com", password: "short", confirmPassword: "short") == L10n.Profile.passwordTooShort)
        #expect(validateRegistration(email: "jane@example.com", password: "longenough", confirmPassword: "") == L10n.Profile.confirmPasswordRequired)
        #expect(validateRegistration(email: "jane@example.com", password: "longenough", confirmPassword: "different") == L10n.Profile.passwordsDoNotMatch)
        #expect(validateRegistration(email: "jane@example.com", password: "longenough", confirmPassword: "longenough") == nil)

        #expect(validateResetPassword(token: "", password: "longenough", confirmPassword: "longenough") == L10n.Profile.resetTokenRequired)
        #expect(validateResetPassword(token: "token", password: "short", confirmPassword: "short") == L10n.Profile.passwordTooShort)
        #expect(validateResetPassword(token: "token", password: "longenough", confirmPassword: "") == L10n.Profile.confirmPasswordRequired)
        #expect(validateResetPassword(token: "token", password: "longenough", confirmPassword: "different") == L10n.Profile.passwordsDoNotMatch)
        #expect(validateResetPassword(token: "token", password: "longenough", confirmPassword: "longenough") == nil)

        #expect(isVerificationRequiredError(.init(code: "FORBIDDEN", message: "Please verify your email", details: nil)))
        #expect(isVerificationRequiredError(.init(code: "HTTP_403", message: "verify account first", details: nil)))
        #expect(isVerificationRequiredError(.init(code: "FORBIDDEN", message: "Access denied", details: nil)) == false)

        struct SampleError: LocalizedError {
            var errorDescription: String? { "Fallback auth error" }
        }
        #expect(errorMessage(for: SampleError()) == "Fallback auth error")

        var state = AuthState()
        state.registerStep = .credentials
        state.password = "secret"
        state.confirmPassword = "secret"
        state.resetToken = "token"
        state.verificationToken = "verify"
        state.errorMessage = "boom"
        state.statusMessage = "done"

        let reducer = AuthReducer()
        reducer.resetMessages(state: &state)
        #expect(state.errorMessage == nil)
        #expect(state.statusMessage == nil)

        reducer.resetAuthFlowState(state: &state)
        #expect(state.registerStep == .email)
        #expect(state.password.isEmpty)
        #expect(state.confirmPassword.isEmpty)
        #expect(state.resetToken.isEmpty)
        #expect(state.verificationToken.isEmpty)
    }

    @Test
    func chatStateHelpersCoverFallbackBranchesAndTitles() {
        var threadState = ChatThreadFeature.State()
        #expect(threadState.hasComposerContent == false)
        #expect(threadState.isSignedIn == false)

        threadState.draft = "   "
        #expect(threadState.hasComposerContent == false)

        threadState.composerAttachments = [
            ChatComposerAttachment(
                data: Data([0x01]),
                previewData: nil,
                filename: "note.png",
                mimeType: "image/png"
            )
        ]
        #expect(threadState.hasComposerContent)

        threadState.accessToken = "token"
        #expect(threadState.isSignedIn)

        let emptyAssistant = ChatThreadMessage(
            chatMessage: ChatMessage(
                id: UUID(),
                chatId: Fixture.chatID,
                role: .assistant,
                content: .init(markdownText: nil, eventActions: nil, images: []),
                aiModel: nil,
                createdAt: Fixture.referenceDate
            )
        )
        #expect(emptyAssistant.hasBubbleContent == false)
        #expect(emptyAssistant.failedComposerAttachments.isEmpty)

        var payload = ChatThreadMessage.SuggestionsPayload(
            isApplying: true,
            suggestions: [ChatSuggestion(actionIndex: 0, action: Fixture.eventAction(kind: .create, eventId: nil, title: "Plan"))]
        )
        #expect(payload.addToCalendarTitle == L10n.ChatSheet.syncingToCalendar)
        #expect(payload.canAddToCalendar == false)

        payload.isApplying = false
        payload.selectedSuggestionIDs = []
        #expect(payload.isSingleSuggestion)
        #expect(payload.selectedPendingCount == 0)
        #expect(payload.addToCalendarTitle == L10n.ChatSheet.addToCalendar)
        #expect(payload.canAddToCalendar)

        let listState = ChatListFeature.State(accessToken: "token", activeChatID: nil, chats: [], errorMessage: nil, hasLoaded: false, isLoading: false)
        var sheetState = ChatSheetState.initial
        sheetState.list = listState
        sheetState.thread = threadState
        #expect(sheetState.activeChatTitle == L10n.ChatSheet.newChat)
        #expect(sheetState.isSignedIn)

        let item = ChatListItem(chat: Chat(
            id: Fixture.chatID,
            userId: Fixture.userID,
            title: "Inbox",
            lastMessageAt: nil,
            createdAt: Fixture.referenceDate,
            updatedAt: Fixture.referenceDate
        ))
        #expect(item.subtitle == nil)
    }

    @Test
    func chatThreadMergingOlderMessagesPreservesOrderAndPreviewData() {
        let existing = ChatThreadMessage(
            id: Fixture.messageID,
            role: .user,
            text: "Hello",
            images: [
                ChatImageAttachment(
                    url: "https://example.com/hello.png",
                    filename: "hello.png",
                    localData: nil,
                    mimeType: "image/png",
                    previewData: Data([0xAA])
                )
            ]
        )
        let older = ChatThreadMessage(role: .assistant, text: "Earlier")
        let loadedDuplicate = ChatThreadMessage(
            id: UUID(),
            role: .user,
            text: "Hello",
            images: [
                ChatImageAttachment(
                    url: "https://example.com/hello.png",
                    filename: "hello.png",
                    localData: nil,
                    mimeType: "image/png",
                    previewData: nil
                )
            ]
        )

        let merged = ChatThreadFeature.mergingOlderMessages(existing: [existing], olderMessages: [older, loadedDuplicate])
        #expect(merged.count == 3)
        #expect(merged[0].markdownText == "Earlier")
        #expect(merged[1].images.first?.previewData == Data([0xAA]))
        #expect(merged[2].id == Fixture.messageID)
    }

    @Test
    func homeScheduleFallbacksAndMarkersCoverAdditionalBranches() {
        var schedule = HomeScheduleState()
        #expect(schedule.emptyStateCopy.title == L10n.Home.connectCalendarTitle)

        schedule.isLoading = true
        #expect(schedule.emptyStateCopy.title == L10n.Home.loadingTitle)

        schedule.isLoading = false
        schedule.errorMessage = "boom"
        #expect(schedule.emptyStateCopy.title == L10n.Home.calendarErrorTitle)

        schedule.errorMessage = nil
        schedule.access = .denied
        #expect(schedule.emptyStateCopy.title == L10n.Home.calendarDeniedTitle)

        schedule.access = .granted
        #expect(schedule.emptyStateCopy.title == L10n.Home.noEventsTitle)

        #expect(HomeDayMarker.previewWeek.count == 5)
        #expect(HomeDayMarker.previewWeek.first?.isToday == true)
        #expect(HomeDayMarker.previewWeek.first?.isSelected == true)

        let section = HomeEventDaySection(
            id: "today",
            date: Fixture.referenceDate,
            items: [Fixture.homeItem(title: "Planning", startDate: Fixture.referenceDate)]
        )
        #expect(section.titleText.isEmpty == false)

        var state = HomeState()
        state.accessToken = "token"
        state.dayStrip = [
            .init(id: 1, title: "Mon", dayNumber: "1", isToday: false),
            .init(id: 2, title: "Tue", dayNumber: "2", isToday: true)
        ]
        state.selectedDayID = 2
        #expect(state.displayDayStrip.map(\.isSelected) == [false, true])
        #expect(state.scheduleMetricCard.value == L10n.Home.noEventsToday)
        #expect(state.scheduleSummaryRowModel.title == L10n.Home.eventsRowTitle)
    }

    @Test
    func homeScheduleSummaryBranchesCoverInProgressAndFallbackItems() {
        var state = HomeState()
        let today = Calendar.current.startOfDay(for: .now)
        let inProgressStart = today.addingTimeInterval(60 * 60)
        let inProgressEnd = Date().addingTimeInterval(60 * 60)
        state.schedule.upcomingItems = [
            Fixture.homeItem(title: "Focus", startDate: inProgressStart, endDate: inProgressEnd)
        ]
        #expect(state.scheduleSummaryRowModel.detail.contains(L10n.Home.inProgress))

        state.schedule.upcomingItems = [
            Fixture.homeItem(
                title: "Tomorrow",
                startDate: Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
            )
        ]
        #expect(state.scheduleSummaryRowModel.detail.contains("Tomorrow"))
        #expect(state.todayTitle == L10n.Home.noEventsToday)
    }

    @Test
    func rebalanceStateDerivedHelpersCoverSelectionPreviewAndBatteryCache() {
        let firstRequest = BatteryDayRequest(
            dayID: "day-1",
            endDate: Fixture.secondaryDate,
            entries: [],
            startDate: Fixture.referenceDate
        )
        let secondRequest = BatteryDayRequest(
            dayID: "day-2",
            endDate: Fixture.tertiaryDate,
            entries: [],
            startDate: Fixture.secondaryDate
        )
        let first = RebalanceFeature.State.DayItem(
            batteryRequest: firstRequest,
            id: "day-1",
            date: Fixture.referenceDate,
            eventCount: 1,
            isToday: true
        )
        let second = RebalanceFeature.State.DayItem(
            batteryRequest: secondRequest,
            id: "day-2",
            date: Fixture.secondaryDate,
            eventCount: 0,
            isToday: false
        )

        var state = RebalanceFeature.State(accessToken: "token")
        state.availableDays = [first, second]
        state.selectedDayIDs = ["day-2", "day-1"]
        #expect(state.canPreview)
        #expect(state.canApply == false)
        #expect(state.selectedDays.map(\.id) == ["day-1", "day-2"])
        #expect(state.batteryRequest(for: "day-1")?.dayID == "day-1")
        #expect(state.dayBatteryState(for: "missing") == .hidden)
        #expect(state.batteryScore(for: "day-1") == nil)

        state.dayBatteryCache["day-1"] = .init(signature: "sig", state: .ready(64))
        #expect(state.batteryScore(for: "day-1") == 0.64)

        state.preview = .init(proposed: [], summary: "Ready", changedCount: 2, unchangedCount: 0)
        #expect(state.canApply)
        state.isApplying = true
        #expect(state.canApply == false)
        #expect(state.canPreview == false)

        #expect(first.dayNumber.isEmpty == false)
        #expect(first.monthText.isEmpty == false)
        #expect(first.weekdayText.isEmpty == false)
    }

    @Test
    func calendarPresentationHelpersCoverNegativeOffsetsAndCacheState() {
        var state = CalendarState(accessToken: "token")
        state.selectedDate = Fixture.referenceDate
        state.events = [
            Fixture.event(id: Fixture.eventID, title: "Later", startAt: Fixture.secondaryDate, endAt: Fixture.tertiaryDate),
            Fixture.event(id: Fixture.secondEventID, title: "Earlier", startAt: Fixture.referenceDate, endAt: Fixture.secondaryDate)
        ]

        let sectionID = state.selectedSectionID
        state.dayBatteryCache[sectionID] = .init(signature: "sig", state: .ready(88))
        #expect(state.dayBatteryState(for: sectionID) == .ready(88))
        #expect(state.selectedDayRows.map(\.title) == ["Earlier", "Later"])
        #expect(state.visibleSectionDate(for: [sectionID: -5]) == Calendar.current.startOfDay(for: Fixture.referenceDate))
        #expect(state.hasSection(for: Fixture.referenceDate.addingTimeInterval(60 * 60 * 24 * 90)) == false)

        let visibleRange = CalendarReducer.visibleRange(for: Fixture.referenceDate)
        #expect(visibleRange.lowerBound < visibleRange.upperBound)
    }

    @Test
    func chatSheetReducerHandlesDetentsPresentationAndDelegates() async {
        let store = TestStore(initialState: ChatSheetState.initial) {
            ChatSheetReducer()
        } withDependencies: {
            $0.appSettingsClient.load = { await MainActor.run { .defaultValue } }
            $0.appSettingsClient.save = { _ in }
            $0.chatClient.listChats = { _ in [] }
        }
        store.exhaustivity = .off

        await store.send(.sheetPresented)
        #expect(store.state.isChatListPresented == false)

        await store.send(.accessTokenChanged("token"))
        await store.receive(.list(.accessTokenChanged("token"))) {
            $0.list.accessToken = "token"
            $0.list.hasLoaded = false
        }
        await store.receive(.thread(.accessTokenChanged("token"))) {
            $0.thread.accessToken = "token"
        }

        await store.send(.chatListButtonTapped) {
            $0.isChatListPresented = true
        }

        await store.send(.detentChanged(.collapsed)) {
            $0.detent = .collapsed
            $0.isChatListPresented = false
        }

        await store.send(.thread(.delegate(.expandRequested))) {
            $0.detent = .large
        }

        await store.send(.detentChanged(.collapsed)) {
            $0.detent = .collapsed
            $0.isChatListPresented = false
        }

        await store.send(.thread(.delegate(.attachmentFlowRequested))) {
            $0.detent = .medium
        }

        await store.send(.list(.delegate(.activeChatChanged(Fixture.chatID)))) {
            $0.isChatListPresented = false
        }
        await store.receive(.thread(.activeChatChanged(Fixture.chatID))) {
            $0.thread.activeChatID = Fixture.chatID
        }
        await store.receive(.list(.activeChatChanged(Fixture.chatID))) {
            $0.list.activeChatID = Fixture.chatID
        }

        await store.send(.thread(.delegate(.chatActivated(nil))))
        await store.receive(.list(.activeChatChanged(nil))) {
            $0.list.activeChatID = nil
        }

        await store.send(.thread(.delegate(.chatListShouldReload(Fixture.secondUserID))))
        await store.receive(.list(.reload(preferredActiveChatID: Fixture.secondUserID, forceNewChat: false))) {
            $0.list.errorMessage = nil
            $0.list.isLoading = true
        }

        await store.send(.thread(.delegate(.suggestionsApplied)))
        await store.receive(.delegate(.suggestionApplyCompleted))
    }

    @Test
    func chatThreadSendSupportGuardBranchesMutateStateSafely() {
        let feature = ChatThreadFeature()

        var noAuth = ChatThreadFeature.State()
        noAuth.draft = "Hello"
        let noAuthEffect = feature.sendMessage(state: &noAuth)
        #expect(noAuth.errorMessage == L10n.ChatSheet.authRequiredBody)
        #expect(String(describing: noAuthEffect).contains("Operation.none"))

        var alreadySending = ChatThreadFeature.State()
        alreadySending.accessToken = "token"
        alreadySending.draft = "Hello"
        alreadySending.isSending = true
        let alreadySendingEffect = feature.sendMessage(state: &alreadySending)
        #expect(alreadySending.errorMessage == nil)
        #expect(String(describing: alreadySendingEffect).contains("Operation.none"))

        var emptyComposer = ChatThreadFeature.State()
        emptyComposer.accessToken = "token"
        emptyComposer.draft = "   "
        let emptyComposerEffect = feature.sendMessage(state: &emptyComposer)
        #expect(emptyComposer.messages.isEmpty)
        #expect(String(describing: emptyComposerEffect).contains("Operation.none"))

        var deliveredMessageState = ChatThreadFeature.State()
        deliveredMessageState.accessToken = "token"
        deliveredMessageState.messages = [ChatThreadMessage(role: .user, text: "Done")]
        let retryEffect = feature.retryFailedMessage(state: &deliveredMessageState, messageID: deliveredMessageState.messages[0].id)
        #expect(deliveredMessageState.messages[0].deliveryState == .delivered)
        #expect(String(describing: retryEffect).contains("Operation.none"))
    }

    @Test
    func homeReducerSupportHelpersCoverTimedAndUntimedEffects() async {
        let effect = HomeReducer.evaluateBatteryEffect(
            batteryClient: BatteryClient(
                evaluate: { items, access in
                    #expect(items.count == 1)
                    switch access {
                    case .granted:
                        break
                    case .denied, .notRequested:
                        Issue.record("Expected granted access")
                    }
                    return .ready(.init(headline: "55%", detail: "Steady", percentage: 55))
                },
                evaluateDay: { _ in .hidden }
            ),
            items: [Fixture.homeItem(title: "Planning", startDate: Fixture.referenceDate, endDate: Fixture.secondaryDate)],
            access: .granted
        )
        #expect(String(describing: effect).isEmpty == false)

        let untimed = HomeReducer.timeText(startAt: Fixture.referenceDate, endAt: nil)
        #expect(untimed.isEmpty == false)
        #expect(untimed.contains("-") == false)
    }
}
