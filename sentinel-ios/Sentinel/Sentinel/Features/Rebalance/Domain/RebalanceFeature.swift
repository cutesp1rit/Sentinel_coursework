import ComposableArchitecture
import SentinelPlatformiOS
import SentinelCore
import Foundation

@Reducer
struct RebalanceFeature {
    @Dependency(\.appSettingsClient) var appSettingsClient
    @Dependency(\.batteryClient) var batteryClient
    @Dependency(\.calendarSyncClient) var calendarSyncClient
    @Dependency(\.eventsClient) var eventsClient
    @Dependency(\.rebalanceClient) var rebalanceClient

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
                let prompt = trimmedToNil(state.defaultPrompt)
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
                return .run { [calendarSyncClient, eventsClient, rebalanceClient] send in
                    do {
                        try await rebalanceClient.apply(changedEvents, accessToken)
                        let refreshedEvents = try await eventsClient.listEvents(range.lowerBound, range.upperBound, accessToken)
                        _ = try await calendarSyncClient.sync(.init(events: refreshedEvents))
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
