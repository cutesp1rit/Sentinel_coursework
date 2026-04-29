import SwiftUI
import SentinelCore

extension HomeState {
    var batterySummaryRowModel: SummaryRowModel? {
        guard showsBatteryMetricCard else { return nil }
        return SummaryRowModel(
            detail: resourceBatteryDetailText,
            leading: .icon(resourceBatterySymbolName ?? "battery.100percent", resourceBatteryTint),
            title: L10n.Home.batteryTitle(resourceBatteryValueText),
            titleTint: resourceBatteryTint
        )
    }

    var resourceBatteryProgress: Double {
        switch battery {
        case .hidden, .placeholder, .setupRequired:
            return 0.0
        case let .ready(snapshot):
            if let value = snapshot.percentage.map(Double.init) {
                return min(max(value / 100, 0), 1)
            }
            return 0.0
        }
    }

    var resourceBatteryDetailText: String {
        battery.displaySnapshot.detail
    }

    var resourceBatteryValueText: String {
        switch battery {
        case .hidden:
            return L10n.Home.batteryUnavailableValue
        case .placeholder:
            return L10n.Home.batteryPendingValue
        case .setupRequired(.downloadModel):
            return L10n.Home.batteryDownloadValue
        case .setupRequired(.enableAppleIntelligence):
            return L10n.Home.batteryEnableValue
        case let .ready(snapshot):
            return "\(snapshot.percentage ?? Int(resourceBatteryProgress * 100))%"
        }
    }

    var resourceBatterySymbolName: String? {
        switch resourceBatteryProgress {
        case _ where battery == .placeholder:
            return "calendar.badge.clock"
        case _ where battery == .setupRequired(.downloadModel):
            return "arrow.down.circle.fill"
        case _ where battery == .setupRequired(.enableAppleIntelligence):
            return "sparkles"
        case _ where battery == .hidden:
            return nil
        case ..<0.125:
            return "battery.0percent"
        case ..<0.375:
            return "battery.25percent"
        case ..<0.625:
            return "battery.50percent"
        case ..<0.875:
            return "battery.75percent"
        default:
            return "battery.100percent"
        }
    }

    var showsBatteryMetricCard: Bool {
        isAuthenticated
    }

    var isBatteryMetricActionable: Bool {
        battery.isActionable
    }

    var resourceBatteryTint: Color {
        switch battery {
        case .hidden:
            return .clear
        case .placeholder:
            return .indigo
        case .setupRequired:
            return .orange
        case let .ready(snapshot):
            let percentage = snapshot.percentage ?? Int(resourceBatteryProgress * 100)
            switch percentage {
            case ..<20:
                return .red
            case ..<40:
                return .orange
            default:
                return .green
            }
        }
    }

    var batteryMetricCard: MetricCardModel? {
        guard showsBatteryMetricCard else { return nil }
        return MetricCardModel(
            detail: resourceBatteryDetailText,
            systemImage: resourceBatterySymbolName,
            tint: resourceBatteryTint,
            title: L10n.Home.metricBatteryTitle,
            value: resourceBatteryValueText
        )
    }
}
