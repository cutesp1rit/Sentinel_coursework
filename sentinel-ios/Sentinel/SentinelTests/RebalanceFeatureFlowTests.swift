import SentinelUI
import SentinelPlatformiOS
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct RebalanceFeatureFlowTests {
    private static func makeDayItemsForTests(from events: [Event], today: Date) -> [RebalanceFeature.State.DayItem] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 14, to: start) ?? start
        var days: [Date] = []
        var cursor = start
        while cursor <= end {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        let grouped = Dictionary(grouping: events) { calendar.startOfDay(for: $0.startAt) }
        return days.map { date in
            let dayEvents = grouped[date, default: []]
            let startDate = calendar.startOfDay(for: date)
            let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
            let dayID = CalendarState.sectionID(for: date)
            return RebalanceFeature.State.DayItem(
                batteryRequest: BatteryDayRequest(
                    dayID: dayID,
                    endDate: endDate,
                    entries: dayEvents.sorted { $0.startAt < $1.startAt }.map(BatteryScheduleEntry.init(event:)),
                    startDate: startDate
                ),
                id: dayID,
                date: date,
                eventCount: dayEvents.count,
                isToday: calendar.isDate(date, inSameDayAs: today)
            )
        }
    }

    private func makeDayItem(
        id: String,
        date: Date,
        eventCount: Int = 1,
        isToday: Bool = false
    ) -> RebalanceFeature.State.DayItem {
        RebalanceFeature.State.DayItem(
            batteryRequest: BatteryDayRequest(
                dayID: id,
                endDate: Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date,
                entries: [],
                startDate: date
            ),
            id: id,
            date: date,
            eventCount: eventCount,
            isToday: isToday
        )
    }

    @Test
    func onAppearLoadsDefaultPromptAndDays() async {
        let today = Calendar.current.startOfDay(for: .now)
        let event = Fixture.event(startAt: today, endAt: Calendar.current.date(byAdding: .hour, value: 1, to: today))

        let store = TestStore(initialState: RebalanceFeature.State(accessToken: "token")) {
            RebalanceFeature()
        } withDependencies: {
            $0.appSettingsClient.load = {
                try? await Task.sleep(for: .milliseconds(10))
                return await MainActor.run {
                    AppSettings(
                        defaultPromptTemplate: "Prompt",
                        lastActiveChatID: nil,
                        lastActiveChatOpenedAt: nil,
                        selectedEnvironment: .local
                    )
                }
            }
            $0.eventsClient.listEvents = { _, _, token in
                #expect(token == "token")
                try? await Task.sleep(for: .milliseconds(20))
                return [event]
            }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(.defaultPromptLoaded(.init(
            defaultPromptTemplate: "Prompt",
            lastActiveChatID: nil,
            lastActiveChatOpenedAt: nil,
            selectedEnvironment: .local
        ))) {
            $0.defaultPrompt = "Prompt"
        }
        await store.receive(.daysLoaded(Self.makeDayItemsForTests(from: [event], today: .now))) {
            $0.activeDayBatteryID = nil
            $0.availableDays = Self.makeDayItemsForTests(from: [event], today: .now)
            $0.queuedDayBatteryIDs = []
            $0.selectedDayIDs = Set($0.availableDays.prefix(3).map(\.id))
            $0.isLoading = false
        }
    }

    @Test
    func selectionAndPreviewStateTransitionsWork() async {
        let dayID = "day-1"
        let day = makeDayItem(id: dayID, date: Fixture.referenceDate)
        var initialState = RebalanceFeature.State(accessToken: "token")
        initialState.availableDays = [day]
        initialState.selectedDayIDs = [dayID]
        initialState.preview = RebalancePreview(proposed: [], summary: "summary", changedCount: 0, unchangedCount: 1)
        initialState.isPreviewPresented = true
        initialState.errorMessage = "error"

        let store = TestStore(initialState: initialState) {
            RebalanceFeature()
        }

        await store.send(.selectedDayToggled(dayID)) {
            $0.selectedDayIDs = []
            $0.isPreviewPresented = false
            $0.preview = nil
            $0.errorMessage = nil
        }

        let preview = RebalancePreview(
            proposed: [
                RebalanceProposedEvent(
                    id: Fixture.eventID,
                    title: "Updated",
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

        await store.send(.previewLoaded(preview)) {
            $0.preview = preview
            $0.isLoading = false
            $0.isPreviewPresented = true
        }
    }

    @Test
    func dayBatteryFlowQueuesAndLoads() async {
        let dayID = "day-1"
        let day = makeDayItem(id: dayID, date: Fixture.referenceDate)
        var initialState = RebalanceFeature.State(accessToken: "token")
        initialState.availableDays = [day]

        let store = TestStore(initialState: initialState) {
            RebalanceFeature()
        } withDependencies: {
            $0.batteryClient.evaluateDay = { _ in .ready(61) }
        }

        await store.send(.dayBatteryRequested(dayID)) {
            $0.dayBatteryCache[dayID] = .init(signature: day.batteryRequest.signature, state: .loading)
            $0.activeDayBatteryID = dayID
        }

        await store.receive(.dayBatteryLoaded(dayID, day.batteryRequest.signature, .ready(61))) {
            $0.dayBatteryCache[dayID]?.state = .ready(61)
            $0.activeDayBatteryID = nil
        }
    }

    @Test
    func previewAndApplyFlowsWork() async {
        let dayID = "day-1"
        let today = Calendar.current.startOfDay(for: .now)
        let day = makeDayItem(id: dayID, date: today)
        let preview = RebalancePreview(
            proposed: [
                RebalanceProposedEvent(
                    id: Fixture.eventID,
                    title: "Updated",
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

        var initialState = RebalanceFeature.State(accessToken: "token")
        initialState.availableDays = [day]
        initialState.selectedDayIDs = [dayID]
        initialState.defaultPrompt = "Prompt"
        initialState.dayBatteryCache[dayID] = .init(signature: day.batteryRequest.signature, state: .ready(80))

        let store = TestStore(initialState: initialState) {
            RebalanceFeature()
        } withDependencies: {
            $0.rebalanceClient.propose = { timezone, days, prompt, token in
                #expect(timezone.isEmpty == false)
                #expect(days.count == 1)
                #expect(prompt == "Prompt")
                #expect(token == "token")
                return preview
            }
            $0.rebalanceClient.apply = { events, token in
                #expect(events.count == 1)
                #expect(token == "token")
            }
            $0.eventsClient.listEvents = { _, _, _ in [Fixture.event(id: Fixture.eventID, title: "Updated")] }
            $0.calendarSyncClient.sync = { _ in .init(syncedEventIDs: [Fixture.eventID]) }
        }

        await store.send(.previewTapped) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(.previewLoaded(preview)) {
            $0.preview = preview
            $0.isLoading = false
            $0.isPreviewPresented = true
        }

        await store.send(.applyTapped) {
            $0.isApplying = true
            $0.errorMessage = nil
        }
        await store.receive(.applyCompleted) {
            $0.isApplying = false
        }
        await store.receive(.delegate(.applied))
    }
}
