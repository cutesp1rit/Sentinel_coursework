import ComposableArchitecture
import Foundation

@Reducer
struct RebalanceFeature {
    @Dependency(\.appSettingsClient) var appSettingsClient
    @Dependency(\.batteryClient) var batteryClient
    @Dependency(\.calendarSyncClient) var calendarSyncClient
    @Dependency(\.eventsClient) var eventsClient
    @Dependency(\.localNotificationsClient) var localNotificationsClient
    @Dependency(\.rebalanceClient) var rebalanceClient

    @ObservableState
    struct State: Equatable {
        struct DayItem: Equatable, Identifiable {
            let batteryRequest: BatteryDayRequest
            let id: String
            let date: Date
            let eventCount: Int
            let isToday: Bool

            var dayNumber: String {
                date.formatted(.dateTime.day())
            }

            var monthText: String {
                date.formatted(.dateTime.month(.abbreviated))
            }

            var weekdayText: String {
                date.formatted(.dateTime.weekday(.abbreviated))
            }
        }

        var accessToken: String
        var activeDayBatteryID: DayItem.ID?
        var availableDays: [DayItem] = []
        var dayBatteryCache: [DayItem.ID: DayBatteryCacheEntry] = [:]
        var defaultPrompt = ""
        var errorMessage: String?
        var isApplying = false
        var isLoading = false
        var isPreviewPresented = false
        var preview: RebalancePreview?
        var queuedDayBatteryIDs: [DayItem.ID] = []
        var selectedDayIDs: Set<DayItem.ID> = []

        var canApply: Bool {
            preview?.changedCount ?? 0 > 0 && !isApplying
        }

        var canPreview: Bool {
            !selectedDayIDs.isEmpty && !isLoading && !isApplying
        }

        var selectedDays: [DayItem] {
            availableDays.filter { selectedDayIDs.contains($0.id) }
        }

        func batteryScore(for dayID: DayItem.ID) -> Double? {
            guard case let .ready(percentage) = dayBatteryState(for: dayID) else {
                return nil
            }
            return Double(percentage) / 100
        }

        func batteryRequest(for dayID: DayItem.ID) -> BatteryDayRequest? {
            availableDays.first(where: { $0.id == dayID })?.batteryRequest
        }

        func dayBatteryState(for dayID: DayItem.ID) -> DayBatteryBadgeState {
            dayBatteryCache[dayID]?.state ?? .hidden
        }
    }

    enum Action: Equatable {
        case applyCompleted
        case applyFailed(String)
        case applyTapped
        case dayBatteryLoaded(State.DayItem.ID, String, DayBatteryBadgeState)
        case dayBatteryRequested(State.DayItem.ID)
        case defaultPromptLoaded(AppSettings)
        case delegate(Delegate)
        case daysLoaded([State.DayItem])
        case eventsFailed(String)
        case onAppear
        case previewLoaded(RebalancePreview)
        case previewPresentationChanged(Bool)
        case previewTapped
        case proposeFailed(String)
        case selectedDayToggled(State.DayItem.ID)
    }

    enum Delegate: Equatable {
        case applied
        case close
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.availableDays.isEmpty, !state.isLoading else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                let accessToken = state.accessToken
                let range = Self.visibleRange()
                return .merge(
                    .run { [appSettingsClient] send in
                        let settings = await appSettingsClient.load()
                        await send(.defaultPromptLoaded(settings))
                    },
                    .run { [eventsClient] send in
                        do {
                            let events = try await eventsClient.listEvents(range.lowerBound, range.upperBound, accessToken)
                            await send(.daysLoaded(Self.makeDayItems(from: events, today: .now)))
                        } catch {
                            await send(.eventsFailed(Self.errorMessage(for: error)))
                        }
                    }
                )

            case let .defaultPromptLoaded(settings):
                state.defaultPrompt = settings.defaultPromptTemplate
                return .none

            case let .daysLoaded(days):
                state.activeDayBatteryID = nil
                state.availableDays = days
                state.queuedDayBatteryIDs = []
                state.selectedDayIDs = Set(days.prefix(3).map(\.id))
                state.isLoading = false
                return .none

            case let .dayBatteryRequested(dayID):
                guard let request = state.batteryRequest(for: dayID) else {
                    return .none
                }

                let signature = request.signature
                if let cache = state.dayBatteryCache[dayID], cache.signature == signature {
                    switch cache.state {
                    case .loading, .ready:
                        return .none
                    case .hidden:
                        break
                    }
                }

                state.dayBatteryCache[dayID] = .init(signature: signature, state: .loading)

                if state.activeDayBatteryID == nil {
                    state.activeDayBatteryID = dayID
                    return Self.evaluateDayBatteryEffect(
                        batteryClient: batteryClient,
                        request: request
                    )
                }

                if !state.queuedDayBatteryIDs.contains(dayID) {
                    state.queuedDayBatteryIDs.append(dayID)
                }
                return .none

            case let .dayBatteryLoaded(dayID, signature, badgeState):
                if state.dayBatteryCache[dayID]?.signature == signature {
                    state.dayBatteryCache[dayID]?.state = badgeState
                }
                if state.activeDayBatteryID == dayID {
                    state.activeDayBatteryID = nil
                }
                return Self.dequeueDayBatteryEffect(
                    state: &state,
                    batteryClient: batteryClient
                )

            case let .eventsFailed(message), let .proposeFailed(message), let .applyFailed(message):
                state.errorMessage = message
                state.isLoading = false
                state.isApplying = false
                return .none

            case let .selectedDayToggled(dayID):
                if state.selectedDayIDs.contains(dayID) {
                    state.selectedDayIDs.remove(dayID)
                } else {
                    state.selectedDayIDs.insert(dayID)
                }
                state.isPreviewPresented = false
                state.preview = nil
                state.errorMessage = nil
                return .none

            case .previewTapped:
                guard state.canPreview else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                let accessToken = state.accessToken
                let timezone = TimeZone.current.identifier
                let selectedDays = state.selectedDays.map {
                    RebalanceDayInput(
                        date: $0.date,
                        resourceBattery: state.batteryScore(for: $0.id)
                    )
                }
                let prompt = state.defaultPrompt.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                return .run { [rebalanceClient] send in
                    do {
                        let preview = try await rebalanceClient.propose(timezone, selectedDays, prompt, accessToken)
                        await send(.previewLoaded(preview))
                    } catch {
                        await send(.proposeFailed(Self.errorMessage(for: error)))
                    }
                }

            case let .previewLoaded(preview):
                state.preview = preview
                state.isLoading = false
                state.isPreviewPresented = true
                return .none

            case let .previewPresentationChanged(isPresented):
                state.isPreviewPresented = isPresented
                return .none

            case .applyTapped:
                guard let preview = state.preview, state.canApply else { return .none }
                state.isApplying = true
                state.errorMessage = nil
                let changedEvents = preview.proposed.filter(\.changed).map {
                    RebalanceApplyEvent(id: $0.id, startAt: $0.startAt, endAt: $0.endAt)
                }
                let selectedDates = state.selectedDays.map(\.date)
                let accessToken = state.accessToken
                let range = Self.visibleRange(for: selectedDates)
                return .run { [calendarSyncClient, eventsClient, localNotificationsClient, rebalanceClient] send in
                    do {
                        try await rebalanceClient.apply(changedEvents, accessToken)
                        let refreshedEvents = try await eventsClient.listEvents(range.lowerBound, range.upperBound, accessToken)
                        _ = try await calendarSyncClient.sync(.init(events: refreshedEvents))
                        await localNotificationsClient.syncReminderNotifications(refreshedEvents, [])
                        await send(.applyCompleted)
                    } catch {
                        await send(.applyFailed(Self.errorMessage(for: error)))
                    }
                }

            case .applyCompleted:
                state.isApplying = false
                return .send(.delegate(.applied))

            case .delegate:
                return .none
            }
        }
    }
}

private extension RebalanceFeature {
    static func dequeueDayBatteryEffect(
        state: inout State,
        batteryClient: BatteryClient
    ) -> Effect<Action> {
        while !state.queuedDayBatteryIDs.isEmpty {
            let nextDayID = state.queuedDayBatteryIDs.removeFirst()
            guard let request = state.batteryRequest(for: nextDayID) else {
                continue
            }

            state.dayBatteryCache[nextDayID] = .init(signature: request.signature, state: .loading)
            state.activeDayBatteryID = nextDayID
            return evaluateDayBatteryEffect(
                batteryClient: batteryClient,
                request: request
            )
        }

        return .none
    }

    static func evaluateDayBatteryEffect(
        batteryClient: BatteryClient,
        request: BatteryDayRequest
    ) -> Effect<Action> {
        .run { send in
            let state = await batteryClient.evaluateDay(request)
            await send(.dayBatteryLoaded(request.dayID, request.signature, state))
        }
    }

    static func errorMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        return error.localizedDescription
    }

    static func visibleRange() -> ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 14, to: start) ?? start
        return start ... end
    }

    static func visibleRange(for dates: [Date]) -> ClosedRange<Date> {
        let calendar = Calendar.current
        let fallback = visibleRange()
        guard let minDate = dates.min(), let maxDate = dates.max() else { return fallback }
        let start = calendar.startOfDay(for: minDate)
        let endDay = calendar.startOfDay(for: maxDate)
        let end = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        return start ... end
    }

    static func makeDayItems(from events: [Event], today: Date) -> [State.DayItem] {
        let calendar = Calendar.current
        let range = visibleRange()
        var days: [Date] = []
        var cursor = calendar.startOfDay(for: range.lowerBound)
        let end = calendar.startOfDay(for: range.upperBound)
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
            return State.DayItem(
                batteryRequest: BatteryDayRequest(
                    dayID: dayID,
                    endDate: endDate,
                    entries: dayEvents
                        .sorted { $0.startAt < $1.startAt }
                        .map(BatteryScheduleEntry.init(event:)),
                    startDate: startDate
                ),
                id: dayID,
                date: date,
                eventCount: dayEvents.count,
                isToday: calendar.isDate(date, inSameDayAs: today)
            )
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
