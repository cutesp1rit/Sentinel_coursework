import ComposableArchitecture
import Foundation

@Reducer
struct RebalanceFeature {
    @Dependency(\.appSettingsClient) var appSettingsClient
    @Dependency(\.calendarSyncClient) var calendarSyncClient
    @Dependency(\.eventsClient) var eventsClient
    @Dependency(\.localNotificationsClient) var localNotificationsClient
    @Dependency(\.rebalanceClient) var rebalanceClient

    @ObservableState
    struct State: Equatable {
        struct DayItem: Equatable, Identifiable {
            let id: String
            let date: Date
            let eventCount: Int
            let isToday: Bool
            let batteryScore: Double?

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
        var availableDays: [DayItem] = []
        var defaultPrompt = ""
        var errorMessage: String?
        var isApplying = false
        var isLoading = false
        var isPreviewPresented = false
        var preview: RebalancePreview?
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
    }

    enum Action: Equatable {
        case applyCompleted
        case applyFailed(String)
        case applyTapped
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
                state.availableDays = days
                state.selectedDayIDs = Set(days.prefix(3).map(\.id))
                state.isLoading = false
                return .none

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
                        resourceBattery: $0.batteryScore
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
            let busyHours = dayEvents.reduce(0.0) { partial, event in
                let endDate = event.endAt ?? event.startAt.addingTimeInterval(30 * 60)
                return partial + max(endDate.timeIntervalSince(event.startAt), 0) / 3600
            }
            let pressure = min(max((busyHours / 10) + (Double(dayEvents.count) / 12), 0), 1)
            let battery = max(0.18, 0.95 - pressure)
            return State.DayItem(
                id: CalendarState.sectionID(for: date),
                date: date,
                eventCount: dayEvents.count,
                isToday: calendar.isDate(date, inSameDayAs: today),
                batteryScore: dayEvents.isEmpty ? nil : battery
            )
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
