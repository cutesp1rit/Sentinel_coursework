import Foundation
import SentinelCore

struct HomeBatterySnapshot: Equatable, Sendable {
    var headline: String
    var detail: String
    var percentage: Int?
}

enum HomeBatterySetupState: Equatable, Sendable {
    case enableAppleIntelligence
    case downloadModel
}

enum HomeBatteryState: Equatable, Sendable {
    case hidden
    case placeholder
    case setupRequired(HomeBatterySetupState)
    case ready(HomeBatterySnapshot)

    var isActionable: Bool {
        switch self {
        case .setupRequired:
            return true
        case .hidden, .placeholder, .ready:
            return false
        }
    }

    var isVisible: Bool {
        self != .hidden
    }

    var displaySnapshot: HomeBatterySnapshot {
        switch self {
        case .hidden:
            return .init(
                headline: L10n.Home.batteryUnavailableTitle,
                detail: L10n.Home.batteryUnavailableBody,
                percentage: nil
            )
        case .placeholder:
            return .init(
                headline: L10n.Home.batteryPlaceholderTitle,
                detail: L10n.Home.batteryPlaceholderBody,
                percentage: nil
            )
        case .setupRequired(.enableAppleIntelligence):
            return .init(
                headline: L10n.Home.batteryEnableTitle,
                detail: L10n.Home.batteryEnableBody,
                percentage: nil
            )
        case .setupRequired(.downloadModel):
            return .init(
                headline: L10n.Home.batteryDownloadTitle,
                detail: L10n.Home.batteryDownloadBody,
                percentage: nil
            )
        case let .ready(snapshot):
            return snapshot
        }
    }
}
