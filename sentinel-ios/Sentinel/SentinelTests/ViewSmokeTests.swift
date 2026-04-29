import SentinelUI
import SentinelPlatformiOS
import SentinelCore
import ComposableArchitecture
import SwiftUI
import Testing
@testable import Sentinel

@MainActor
struct ViewSmokeTests {
    @Test
    func homeViewRendersSignedOutAndSignedInStates() {
        let signedOutStore = Store(initialState: HomeState()) {
            HomeReducer()
        } withDependencies: {
            $0.batteryClient.evaluate = { _, _ in .hidden }
            $0.calendarSyncClient.loadUpcoming = { .init(access: .notRequested, items: []) }
            $0.achievementsClient.loadAchievements = { _ in [] }
        }

        render(
            HomeView(
                bottomOverlayInset: 0,
                store: signedOutStore
            )
        )

        var signedInState = HomeState()
        signedInState.accessToken = "token"
        signedInState.userEmail = "jane@example.com"
        signedInState.schedule.upcomingItems = [
            Fixture.homeItem(
                title: "Planning",
                startDate: Calendar.current.date(byAdding: .hour, value: 9, to: Calendar.current.startOfDay(for: .now)) ?? .now,
                endDate: Calendar.current.date(byAdding: .hour, value: 10, to: Calendar.current.startOfDay(for: .now)) ?? .now
            )
        ]
        signedInState.battery = .ready(.init(headline: "80%", detail: "Balanced", percentage: 80))

        let signedInStore = Store(initialState: signedInState) {
            HomeReducer()
        } withDependencies: {
            $0.batteryClient.evaluate = { _, _ in .ready(.init(headline: "80%", detail: "Balanced", percentage: 80)) }
            $0.calendarSyncClient.loadUpcoming = { .init(access: .granted, items: []) }
            $0.achievementsClient.loadAchievements = { _ in [] }
        }

        render(
            HomeView(
                bottomOverlayInset: 24,
                store: signedInStore
            )
        )
    }

    @Test
    func chatSheetComposerViewRendersExpandedAndWithAttachmentPreview() {
        let harness = ComposerHarness(
            attachments: [
                ChatComposerAttachment(
                    data: Data([0x00, 0x01]),
                    previewData: nil,
                    filename: "image.png",
                    mimeType: "image/png"
                )
            ],
            isCollapsed: false,
            draft: "Hello"
        )
        render(harness.body)
        render(
            ComposerHarness(
                attachments: [],
                isCollapsed: true,
                draft: ""
            )
        )
    }

    @Test
    func achievementsCalendarProfileRebalanceAndChatBubbleViewsRender() {
        render(
            AuthFlowView(
                onClose: {},
                store: Store(initialState: AuthState()) {
                    AuthReducer()
                }
            )
        )

        let achievementGroups = [Fixture.achievementGroup()]
        let achievementsStore = Store(
            initialState: AchievementsState(
                accessToken: "token",
                groups: achievementGroups,
                hasLoaded: true
            )
        ) {
            AchievementsReducer()
        } withDependencies: {
            $0.achievementsClient.loadAchievements = { _ in achievementGroups }
        }
        render(AchievementsView(store: achievementsStore))
        render(
            AchievementsView(
                store: Store(
                    initialState: AchievementsState(
                        accessToken: "token",
                        isLoading: true
                    )
                ) {
                    AchievementsReducer()
                } withDependencies: {
                    $0.achievementsClient.loadAchievements = { _ in [] }
                }
            )
        )
        render(
            AchievementsView(
                store: Store(
                    initialState: AchievementsState(
                        accessToken: "token",
                        groups: [
                            Fixture.achievementGroup(levels: [
                                Fixture.achievementLevel(unlocked: true, earnedAt: Fixture.referenceDate),
                                Fixture.achievementLevel(
                                    id: Fixture.secondLevelID,
                                    level: 2,
                                    targetValue: 10,
                                    title: "Builder",
                                    unlocked: true,
                                    earnedAt: Fixture.secondaryDate
                                )
                            ]),
                            Fixture.achievementGroup(groupCode: "reminders", currentValue: 0)
                        ],
                        hasLoaded: true
                    )
                ) {
                    AchievementsReducer()
                } withDependencies: {
                    $0.achievementsClient.loadAchievements = { _ in [] }
                }
            )
        )
        render(
            AchievementsView(
                store: Store(
                    initialState: AchievementsState(
                        accessToken: "token",
                        errorMessage: "Boom",
                        hasLoaded: true
                    )
                ) {
                    AchievementsReducer()
                } withDependencies: {
                    $0.achievementsClient.loadAchievements = { _ in [] }
                }
            )
        )
        render(
            AchievementsView(
                store: Store(
                    initialState: AchievementsState(
                        accessToken: "token",
                        hasLoaded: true
                    )
                ) {
                    AchievementsReducer()
                } withDependencies: {
                    $0.achievementsClient.loadAchievements = { _ in [] }
                }
            )
        )

        var calendarState = CalendarState(accessToken: "token")
        calendarState.events = [Fixture.event(), Fixture.event(id: Fixture.secondEventID, title: "Review", startAt: Fixture.secondaryDate, endAt: Fixture.tertiaryDate)]
        calendarState.selectedDate = Fixture.referenceDate
        let calendarEvents = calendarState.events
        let calendarStore = Store(initialState: calendarState) {
            CalendarReducer()
        } withDependencies: {
            $0.eventsClient.listEvents = { _, _, _ in calendarEvents }
            $0.batteryClient.evaluateDay = { _ in .ready(70) }
            $0.calendarSyncClient.sync = { _ in .init() }
        }
        render(CalendarView(store: calendarStore))
        var pickerCalendarState = calendarState
        pickerCalendarState.isInlineMonthPickerVisible = true
        pickerCalendarState.editor = .init(event: Fixture.event())
        render(
            CalendarView(
                store: Store(initialState: pickerCalendarState) {
                    CalendarReducer()
                } withDependencies: {
                    $0.eventsClient.listEvents = { _, _, _ in calendarEvents }
                    $0.batteryClient.evaluateDay = { _ in .ready(70) }
                    $0.calendarSyncClient.sync = { _ in .init() }
                }
            )
        )
        var loadingCalendarState = CalendarState(accessToken: "token")
        loadingCalendarState.isLoading = true
        loadingCalendarState.errorMessage = "Calendar error"
        render(
            CalendarView(
                store: Store(initialState: loadingCalendarState) {
                    CalendarReducer()
                } withDependencies: {
                    $0.eventsClient.listEvents = { _, _, _ in [] }
                    $0.batteryClient.evaluateDay = { _ in .hidden }
                    $0.calendarSyncClient.sync = { _ in .init() }
                }
            )
        )
        var emptyCalendarState = CalendarState(accessToken: "token")
        emptyCalendarState.selectedDate = Fixture.referenceDate
        render(
            CalendarView(
                store: Store(initialState: emptyCalendarState) {
                    CalendarReducer()
                } withDependencies: {
                    $0.eventsClient.listEvents = { _, _, _ in [] }
                    $0.batteryClient.evaluateDay = { _ in .hidden }
                    $0.calendarSyncClient.sync = { _ in .init() }
                }
            )
        )
        var errorCalendarState = CalendarState(accessToken: "token")
        errorCalendarState.errorMessage = "Calendar error"
        errorCalendarState.selectedDate = Fixture.referenceDate
        render(
            CalendarView(
                store: Store(initialState: errorCalendarState) {
                    CalendarReducer()
                } withDependencies: {
                    $0.eventsClient.listEvents = { _, _, _ in [] }
                    $0.batteryClient.evaluateDay = { _ in .hidden }
                    $0.calendarSyncClient.sync = { _ in .init() }
                }
            )
        )

        var profileState = ProfileFeature.State()
        profileState.accessToken = "token"
        profileState.userEmail = "jane@example.com"
        profileState.defaultPromptTemplate = "Prompt"
        profileState.selectedEnvironment = .production
        profileState.errorMessage = "Profile error"
        profileState.isDeletePromptVisible = true
        let profileStore = Store(initialState: profileState) {
            ProfileFeature()
        } withDependencies: {
            $0.appSettingsClient.load = { await MainActor.run { .defaultValue } }
            $0.appSettingsClient.save = { _ in }
            $0.sessionStorageClient.clear = {}
            $0.authClient.deleteAccount = { _, _ in }
        }
        render(ProfileSheetView(onClose: {}, store: profileStore))

        let today = Calendar.current.startOfDay(for: .now)
        let dayID = CalendarState.sectionID(for: today)
        let rebalanceDay = RebalanceFeature.State.DayItem(
            batteryRequest: BatteryDayRequest(
                dayID: dayID,
                endDate: Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today,
                entries: [],
                startDate: today
            ),
            id: dayID,
            date: today,
            eventCount: 2,
            isToday: true
        )
        var rebalanceState = RebalanceFeature.State(accessToken: "token")
        rebalanceState.availableDays = [rebalanceDay]
        rebalanceState.selectedDayIDs = [dayID]
        let rebalanceStore = Store(initialState: rebalanceState) {
            RebalanceFeature()
        }
        render(RebalanceSheetView(onClose: {}, store: rebalanceStore))
        var previewState = rebalanceState
        previewState.preview = RebalancePreview(
            proposed: [
                RebalanceProposedEvent(
                    id: Fixture.eventID,
                    title: "Planning",
                    startAt: Fixture.secondaryDate,
                    endAt: Fixture.tertiaryDate,
                    originalStartAt: Fixture.referenceDate,
                    originalEndAt: Fixture.secondaryDate,
                    changed: true
                )
            ],
            summary: "1 change",
            changedCount: 1,
            unchangedCount: 0
        )
        previewState.isPreviewPresented = true
        render(RebalanceSheetView(onClose: {}, store: Store(initialState: previewState) { RebalanceFeature() }))
        var noChangesState = previewState
        noChangesState.errorMessage = "Preview error"
        noChangesState.preview = RebalancePreview(
            proposed: [],
            summary: "No changes",
            changedCount: 0,
            unchangedCount: 1
        )
        render(RebalanceSheetView(onClose: {}, store: Store(initialState: noChangesState) { RebalanceFeature() }))

        let failedMessage = ChatThreadMessage(
            role: .user,
            text: "Hello",
            images: [
                ChatImageAttachment(
                    url: "",
                    filename: "local.png",
                    localData: Data([0x01]),
                    mimeType: "image/png",
                    previewData: nil
                )
            ],
            deliveryState: .failed
        )
        render(
            ChatBubbleRow(
                message: failedMessage,
                onRemoveFailedMessage: { _ in },
                onRetryFailedMessage: { _ in }
            )
        )
        render(
            ChatBubbleRow(
                message: ChatThreadMessage(
                    role: .assistant,
                    text: "Assistant **markdown**",
                    images: [
                        ChatImageAttachment(
                            url: "https://example.com/image.png",
                            filename: "remote.png",
                            localData: nil,
                            mimeType: "image/png",
                            previewData: nil
                        )
                    ]
                ),
                onRemoveFailedMessage: { _ in },
                onRetryFailedMessage: { _ in }
            )
        )
        render(
            ChatBubbleRow(
                message: ChatThreadMessage(
                    role: .assistant,
                    text: "Fallback",
                    images: [
                        ChatImageAttachment(
                            url: "not-a-url",
                            filename: "broken",
                            localData: nil,
                            mimeType: "image/png",
                            previewData: nil
                        )
                    ]
                ),
                onRemoveFailedMessage: { _ in },
                onRetryFailedMessage: { _ in }
            )
        )

        var chatSheetState = ChatSheetState.initial
        chatSheetState.thread.accessToken = "token"
        render(
            ChatSheetView(
                store: Store(initialState: chatSheetState) {
                    ChatSheetReducer()
                } withDependencies: {
                    $0.appSettingsClient.load = { await MainActor.run { .defaultValue } }
                    $0.appSettingsClient.save = { _ in }
                    $0.chatClient.listMessages = { _, _, _, _ in ([], false) }
                    $0.chatClient.listChats = { _ in [] }
                    $0.calendarSyncClient.detectConflicts = { _ in [:] }
                }
            )
        )

        chatSheetState.isChatListPresented = true
        render(
            ChatSheetView(
                store: Store(initialState: chatSheetState) {
                    ChatSheetReducer()
                } withDependencies: {
                    $0.appSettingsClient.load = { await MainActor.run { .defaultValue } }
                    $0.appSettingsClient.save = { _ in }
                    $0.chatClient.listMessages = { _, _, _, _ in ([], false) }
                    $0.chatClient.listChats = { _ in [] }
                    $0.calendarSyncClient.detectConflicts = { _ in [:] }
                }
            )
        )
    }
}

@MainActor
private struct ComposerHarness: View {
    let attachments: [ChatComposerAttachment]
    let isCollapsed: Bool
    let draft: String

    @FocusState private var isFocused: Bool
    @State private var localDraft: String = ""

    var body: some View {
        ChatSheetComposerView(
            draft: .constant(draft),
            attachments: attachments,
            isCollapsed: isCollapsed,
            isComposerEnabled: true,
            isSendEnabled: true,
            composerFocus: $isFocused,
            onAttachmentTap: {},
            onRemoveAttachment: { _ in },
            onComposerTap: {},
            onSendTap: {}
        )
    }
}
