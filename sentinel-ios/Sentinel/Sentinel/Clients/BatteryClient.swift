import ComposableArchitecture
import Foundation

struct BatteryClient: Sendable {
    var evaluate: @Sendable (_ scheduleItems: [HomeScheduleItem], _ access: HomeScheduleAccess) async -> HomeBatteryState
}

extension BatteryClient: DependencyKey {
    static let liveValue = BatteryClient(
        evaluate: { scheduleItems, access in
            await MainActor.run {
                guard access == .granted else {
                    return access == .denied ? .unavailable : .placeholder
                }

                let now = Date()
                let next24hItems = scheduleItems.filter {
                    $0.startDate >= now && $0.startDate <= now.addingTimeInterval(24 * 60 * 60)
                }

                guard !next24hItems.isEmpty else {
                    return .ready(.init(headline: "92%", detail: "Light day ahead. Plenty of room for focused work."))
                }

                let busyHours = next24hItems.reduce(0.0) { partial, item in
                    let endDate = item.endDate ?? item.startDate.addingTimeInterval(60 * 30)
                    return partial + max(endDate.timeIntervalSince(item.startDate), 0) / 3600
                }

                let pressure = min(max((busyHours / 10) + (Double(next24hItems.count) / 12), 0), 1)
                let battery = max(0.18, 0.95 - pressure)
                let percentage = Int((battery * 100).rounded())

                let detail: String
                switch battery {
                case 0.75...:
                    detail = "Low schedule pressure. Good capacity for deep work."
                case 0.45..<0.75:
                    detail = "Moderate load. Protect your next focused block."
                default:
                    detail = "Heavy day. Expect interruptions and tighter recovery windows."
                }

                return .ready(.init(headline: "\(percentage)%", detail: detail))
            }
        }
    )
}

extension DependencyValues {
    nonisolated var batteryClient: BatteryClient {
        get { self[BatteryClient.self] }
        set { self[BatteryClient.self] = newValue }
    }
}
