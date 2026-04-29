import SentinelUI
import SentinelCore
import SwiftUI

struct ResourceBatteryInlineBadge: View {
    let state: DayBatteryBadgeState

    var body: some View {
        switch state {
        case .hidden:
            EmptyView()

        case .loading:
            ProgressView()
                .controlSize(.small)
                .tint(.green)
                .frame(width: 18, height: 18)
                .padding(.horizontal, AppSpacing.small)
                .padding(.vertical, AppSpacing.xSmall)
                .background(Color.green.opacity(0.10), in: Capsule())

        case let .ready(percentage):
            HStack(spacing: AppSpacing.xSmall) {
                Image(systemName: Self.symbolName(for: percentage))
                    .font(.caption2.weight(.semibold))

                Text("\(percentage)%")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Self.tint(for: percentage))
            .padding(.horizontal, AppSpacing.small)
            .padding(.vertical, AppSpacing.xSmall)
            .background(Self.tint(for: percentage).opacity(0.10), in: Capsule())
        }
    }

    private static func symbolName(for percentage: Int) -> String {
        switch percentage {
        case ..<13:
            return "battery.0percent"
        case ..<38:
            return "battery.25percent"
        case ..<63:
            return "battery.50percent"
        case ..<88:
            return "battery.75percent"
        default:
            return "battery.100percent"
        }
    }

    private static func tint(for percentage: Int) -> Color {
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
