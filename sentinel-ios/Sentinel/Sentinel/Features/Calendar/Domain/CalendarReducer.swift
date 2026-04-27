import ComposableArchitecture
import Foundation

@Reducer
struct CalendarReducer {
    @Dependency(\.calendarSyncClient) var calendarSyncClient
    @Dependency(\.eventsClient) var eventsClient
    @Dependency(\.localNotificationsClient) var localNotificationsClient

    var body: some Reducer<CalendarState, CalendarAction> {
        Reduce { state, action in
            switch action {
            case .addTapped:
                state.editor = .init()
                return .none

            case let .deleteFailed(message), let .eventsFailed(message), let .saveFailed(message):
                state.errorMessage = message
                state.isLoading = false
                return .none

            case let .deleteTapped(eventID):
                state.errorMessage = nil
                state.isLoading = true
                let range = Self.visibleRange(for: state.selectedDate)
                let accessToken = state.accessToken
                return .run { [calendarSyncClient, eventsClient, localNotificationsClient] send in
                    do {
                        try await eventsClient.deleteEvent(eventID, accessToken)
                        let events = try await eventsClient.listEvents(range.lowerBound, range.upperBound, accessToken)
                        _ = try await calendarSyncClient.sync(.init(deletedEventIDs: [eventID], events: events))
                        await localNotificationsClient.syncReminderNotifications(events, [eventID])
                        await send(.eventsLoaded(events))
                    } catch {
                        await send(.deleteFailed(Self.errorMessage(for: error)))
                    }
                }

            case let .editorAllDayChanged(value):
                state.editor?.allDay = value
                return .none

            case let .editorDescriptionChanged(value):
                state.editor?.description = value
                return .none

            case let .editorFixedChanged(value):
                state.editor?.isFixed = value
                return .none

            case .editorDismissed:
                state.editor = nil
                return .none

            case let .editorEndDateChanged(value):
                state.editor?.endDate = value
                return .none

            case let .editorLocationChanged(value):
                state.editor?.location = value
                return .none

            case let .editorStartDateChanged(value):
                state.editor?.startDate = value
                if let endDate = state.editor?.endDate, endDate <= value {
                    state.editor?.endDate = value.addingTimeInterval(60 * 60)
                }
                return .none

            case let .editorTitleChanged(value):
                state.editor?.title = value
                return .none

            case let .editorTypeChanged(value):
                state.editor?.type = value
                return .none

            case let .editTapped(eventID):
                guard let event = state.events.first(where: { $0.id == eventID }) else {
                    return .none
                }
                state.editor = .init(event: event)
                return .none

            case let .eventsLoaded(events):
                state.events = events
                state.errorMessage = nil
                state.isLoading = false
                if state.pendingScrollSectionID == nil, state.hasSection(for: state.selectedDate) {
                    state.pendingScrollSectionID = state.selectedSectionID
                }
                return .none

            case let .inlineMonthPickerVisibilityChanged(isPresented):
                state.isInlineMonthPickerVisible = isPresented
                return .none

            case .onAppear:
                if state.events.isEmpty && !state.isLoading {
                    return .send(.reloadRequested)
                }
                return .none

            case .reloadRequested:
                guard !state.isLoading else { return .none }
                state.errorMessage = nil
                state.isLoading = true
                let range = Self.visibleRange(for: state.selectedDate)
                let accessToken = state.accessToken
                return .run { [eventsClient] send in
                    do {
                        let events = try await eventsClient.listEvents(range.lowerBound, range.upperBound, accessToken)
                        await send(.eventsLoaded(events))
                    } catch {
                        await send(.eventsFailed(Self.errorMessage(for: error)))
                    }
                }

            case .saveSucceeded:
                state.editor = nil
                return .none

            case .saveTapped:
                guard let editor = state.editor else { return .none }
                guard !editor.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    state.errorMessage = L10n.Calendar.titleRequired
                    return .none
                }
                state.errorMessage = nil
                state.isLoading = true
                let editorEventID = editor.eventID
                let payload = editor.payload
                let range = Self.visibleRange(for: state.selectedDate)
                let accessToken = state.accessToken
                return .run { [calendarSyncClient, eventsClient, localNotificationsClient] send in
                    do {
                        if let eventID = editorEventID {
                            _ = try await eventsClient.updateEvent(eventID, payload, accessToken)
                        } else {
                            _ = try await eventsClient.createEvent(payload, accessToken)
                        }
                        let events = try await eventsClient.listEvents(range.lowerBound, range.upperBound, accessToken)
                        _ = try await calendarSyncClient.sync(.init(events: events))
                        await localNotificationsClient.syncReminderNotifications(events, [])
                        await send(.eventsLoaded(events))
                        await send(.saveSucceeded)
                    } catch {
                        await send(.saveFailed(Self.errorMessage(for: error)))
                    }
                }

            case let .selectedDateChanged(date):
                let previousMonth = Calendar.current.component(.month, from: state.selectedDate)
                let nextMonth = Calendar.current.component(.month, from: date)
                state.selectedDate = date
                state.isInlineMonthPickerVisible = false
                state.pendingScrollSectionID = CalendarState.sectionID(for: date)
                return previousMonth == nextMonth ? .none : .send(.reloadRequested)

            case let .visibleDateChanged(date):
                let visibleSectionID = CalendarState.sectionID(for: date)
                if let pendingScrollSectionID = state.pendingScrollSectionID {
                    if pendingScrollSectionID == visibleSectionID {
                        state.pendingScrollSectionID = nil
                    } else {
                        return .none
                    }
                }
                state.selectedDate = date
                return .none

            case let .weekAdvanced(direction):
                let calendar = Calendar.current
                state.selectedDate = calendar.date(byAdding: .day, value: direction * 7, to: state.selectedDate) ?? state.selectedDate
                state.pendingScrollSectionID = state.selectedSectionID
                return .send(.reloadRequested)
            }
        }
    }
}

private extension CalendarReducer {
    static func errorMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        return error.localizedDescription
    }

    static func visibleRange(for selectedDate: Date) -> ClosedRange<Date> {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
        let rangeStart = calendar.date(byAdding: .day, value: -7, to: startOfMonth) ?? startOfMonth
        let rangeEndBase = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? selectedDate
        let rangeEnd = calendar.date(byAdding: .day, value: 14, to: rangeEndBase) ?? rangeEndBase
        return rangeStart ... rangeEnd
    }
}
