import ComposableArchitecture
import SentinelCore
import Foundation

extension HomeReducer {
    static func evaluateBatteryEffect(
        batteryClient: BatteryClient,
        items: [HomeScheduleItem],
        access: HomeScheduleAccess
    ) -> Effect<Action> {
        .run { send in
            let battery = await batteryClient.evaluate(items, access)
            await send(.batteryUpdated(battery))
        }
    }

    static func timeText(startAt: Date, endAt: Date?) -> String {
        if let endAt {
            return "\(startAt.formatted(date: .omitted, time: .shortened)) - \(endAt.formatted(date: .omitted, time: .shortened))"
        }
        return startAt.formatted(date: .abbreviated, time: .shortened)
    }
}
