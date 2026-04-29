import ComposableArchitecture
import SentinelCore
import Foundation

extension RebalanceFeature {
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

func trimmedToNil(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
