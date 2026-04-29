import Foundation
import SentinelCore
import FoundationModels

struct BatteryScheduleSummary: Sendable {
    struct BusyBlock: Sendable {
        let end: Date
        let itemCount: Int
        let start: Date
    }

    let busyBlocks: [BusyBlock]
    let eventCount: Int
    let longestFreeGapHours: Double
    let totalBusyHours: Double
    let windowEnd: Date
    let windowStart: Date

    nonisolated var dayPrompt: String {
        """
        Estimate a resource battery percentage for this single day schedule summary.

        \(basePromptBody)

        Return only the percentage.
        """
    }

    nonisolated var homePrompt: String {
        """
        Estimate a resource battery score for the next 24 hours from this schedule summary.

        \(basePromptBody)

        Return a percentage and a single short sentence for a home screen card.
        """
    }

    private nonisolated var basePromptBody: String {
        let blockLines: String
        if busyBlocks.isEmpty {
            blockLines = "- No busy blocks in this window."
        } else {
            blockLines = busyBlocks.enumerated().map { index, block in
                let durationHours = block.end.timeIntervalSince(block.start) / 3600
                return "- Block \(index + 1): \(Self.isoFormatter.string(from: block.start)) to \(Self.isoFormatter.string(from: block.end)) | \(String(format: "%.1f", durationHours))h | \(block.itemCount) item(s)"
            }
            .joined(separator: "\n")
        }

        return """
        Window start: \(Self.isoFormatter.string(from: windowStart))
        Window end: \(Self.isoFormatter.string(from: windowEnd))
        Calendar items in the window: \(eventCount)
        Busy blocks after merging overlaps: \(busyBlocks.count)
        Total busy hours: \(String(format: "%.1f", totalBusyHours))
        Longest free gap hours: \(String(format: "%.1f", longestFreeGapHours))
        Busy blocks:
        \(blockLines)
        """
    }

    nonisolated func fallbackBatteryState() -> HomeBatteryState {
        let percentage = fallbackPercentage()

        return .ready(
            .init(
                headline: "\(percentage)%",
                detail: fallbackDetail(for: percentage),
                percentage: percentage
            )
        )
    }

    nonisolated func fallbackPercentage() -> Int {
        let pressure = min(max((totalBusyHours / 10) + (Double(eventCount) / 12), 0), 1)
        return normalizedPercentage(Int((max(0.18, 0.95 - pressure) * 100).rounded()))
    }

    nonisolated func makeBatteryState(from assessment: ResourceBatteryAssessment) -> HomeBatteryState {
        let percentage = normalizedPercentage(assessment.percentage)
        let detail = assessment.detail
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")

        return .ready(
            .init(
                headline: "\(percentage)%",
                detail: detail.isEmpty ? fallbackDetail(for: percentage) : detail,
                percentage: percentage
            )
        )
    }

    nonisolated func normalizedPercentage(_ rawValue: Int) -> Int {
        min(max(rawValue, 0), 100)
    }

    nonisolated static func make(
        from entries: [BatteryScheduleEntry],
        windowStart: Date,
        windowEnd: Date
    ) -> Self {
        let relevantItems = entries
            .map { entry in
                let end = entry.endDate ?? entry.startDate.addingTimeInterval(30 * 60)
                return DateInterval(start: entry.startDate, end: end)
            }
            .filter { interval in
                interval.end > windowStart && interval.start < windowEnd
            }
            .sorted { $0.start < $1.start }

        var blocks: [BusyBlock] = []

        for interval in relevantItems {
            let start = max(interval.start, windowStart)
            let end = min(interval.end, windowEnd)

            guard end > start else { continue }

            if let last = blocks.last, start <= last.end {
                blocks[blocks.count - 1] = BusyBlock(
                    end: max(last.end, end),
                    itemCount: last.itemCount + 1,
                    start: last.start
                )
            } else {
                blocks.append(
                    BusyBlock(
                        end: end,
                        itemCount: 1,
                        start: start
                    )
                )
            }
        }

        let totalBusyHours = blocks.reduce(0.0) { partial, block in
            partial + block.end.timeIntervalSince(block.start) / 3600
        }

        var cursor = windowStart
        var longestFreeGapHours = 0.0

        for block in blocks {
            longestFreeGapHours = max(longestFreeGapHours, block.start.timeIntervalSince(cursor) / 3600)
            cursor = max(cursor, block.end)
        }

        longestFreeGapHours = max(longestFreeGapHours, windowEnd.timeIntervalSince(cursor) / 3600)

        return Self(
            busyBlocks: blocks,
            eventCount: relevantItems.count,
            longestFreeGapHours: max(longestFreeGapHours, 0),
            totalBusyHours: totalBusyHours,
            windowEnd: windowEnd,
            windowStart: windowStart
        )
    }

    private nonisolated func fallbackDetail(for percentage: Int) -> String {
        switch percentage {
        case 75...:
            return "Light load ahead. Good room for focused work."
        case 45..<75:
            return "Moderate load ahead. Protect your next focus block."
        default:
            return "Heavy load ahead. Expect tighter recovery windows."
        }
    }

    private nonisolated(unsafe) static let isoFormatter = ISO8601DateFormatter()
}

extension BatteryClientLive {
    nonisolated static func modelAvailability() -> BatteryModelAvailability {
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            return .available(model)
        case .unavailable(.deviceNotEligible):
            return .hidden
        case .unavailable(.appleIntelligenceNotEnabled):
            return .setupRequired(.enableAppleIntelligence)
        case .unavailable(.modelNotReady):
            return .setupRequired(.downloadModel)
        @unknown default:
            return .hidden
        }
    }
}
