import ComposableArchitecture
import SentinelCore
import Foundation

extension CalendarReducer {
    static func dequeueDayBatteryEffect(
        state: inout CalendarState,
        batteryClient: BatteryClient
    ) -> Effect<CalendarAction> {
        while !state.queuedDayBatterySectionIDs.isEmpty {
            let nextSectionID = state.queuedDayBatterySectionIDs.removeFirst()
            guard let request = state.batteryRequest(for: nextSectionID) else {
                continue
            }

            state.dayBatteryCache[nextSectionID] = .init(signature: request.signature, state: .loading)
            state.activeDayBatterySectionID = nextSectionID
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
    ) -> Effect<CalendarAction> {
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

    static func visibleRange(for selectedDate: Date) -> ClosedRange<Date> {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
        let rangeStart = calendar.date(byAdding: .day, value: -7, to: startOfMonth) ?? startOfMonth
        let rangeEndBase = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? selectedDate
        let rangeEnd = calendar.date(byAdding: .day, value: 14, to: rangeEndBase) ?? rangeEndBase
        return rangeStart ... rangeEnd
    }
}
