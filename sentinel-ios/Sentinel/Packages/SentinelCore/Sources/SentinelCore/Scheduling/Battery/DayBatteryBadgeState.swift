import Foundation

public enum DayBatteryBadgeState: Equatable, Sendable {
    case hidden
    case loading
    case ready(Int)
}

public struct DayBatteryCacheEntry: Equatable, Sendable {
    public let signature: String
    public var state: DayBatteryBadgeState

    public init(signature: String, state: DayBatteryBadgeState) {
        self.signature = signature
        self.state = state
    }
}
