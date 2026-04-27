import ComposableArchitecture
import Foundation
import FoundationModels

struct BatteryClient: Sendable {
    var evaluate: @Sendable (_ scheduleItems: [HomeScheduleItem], _ access: HomeScheduleAccess) async -> HomeBatteryState
}

extension BatteryClient: DependencyKey {
    static let liveValue = BatteryClient(
        evaluate: { scheduleItems, access in
            let model = SystemLanguageModel.default

            switch model.availability {
            case .available:
                break
            case .unavailable(.deviceNotEligible):
                return .hidden
            case .unavailable(.appleIntelligenceNotEnabled):
                return .setupRequired(.enableAppleIntelligence)
            case .unavailable(.modelNotReady):
                return .setupRequired(.downloadModel)
            @unknown default:
                return .hidden
            }

            switch access {
            case .granted:
                break
            case .notRequested, .denied:
                return .placeholder
            }

            let summary = BatteryScheduleSummary.make(from: scheduleItems, now: .now)

            do {
                let session = LanguageModelSession(
                    model: model,
                    instructions: """
                    You estimate a compact resource battery score from calendar load.
                    Use only the schedule facts provided by the app.
                    Treat 100 as very light schedule pressure and 0 as overloaded.
                    Be conservative and consistent.
                    Write the detail sentence in English, keep it under 90 characters, and do not mention health, sleep, or emotions.
                    """
                )
                let response = try await session.respond(
                    to: summary.prompt,
                    generating: ResourceBatteryAssessment.self,
                    options: GenerationOptions(
                        sampling: .greedy,
                        maximumResponseTokens: 120
                    )
                )
                return summary.makeBatteryState(from: response.content)
            } catch {
                return summary.fallbackBatteryState()
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

@Generable
private struct ResourceBatteryAssessment {
    let detail: String
    let percentage: Int
}

private struct BatteryScheduleSummary: Sendable {
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

    nonisolated var prompt: String {
        let blockLines: String
        if busyBlocks.isEmpty {
            blockLines = "- No busy blocks in the next 24 hours."
        } else {
            blockLines = busyBlocks.enumerated().map { index, block in
                let durationHours = block.end.timeIntervalSince(block.start) / 3600
                return "- Block \(index + 1): \(Self.isoFormatter.string(from: block.start)) to \(Self.isoFormatter.string(from: block.end)) | \(String(format: "%.1f", durationHours))h | \(block.itemCount) item(s)"
            }
            .joined(separator: "\n")
        }

        return """
        Estimate a resource battery score for the next 24 hours from this schedule summary.

        Window start: \(Self.isoFormatter.string(from: windowStart))
        Window end: \(Self.isoFormatter.string(from: windowEnd))
        Calendar items in the window: \(eventCount)
        Busy blocks after merging overlaps: \(busyBlocks.count)
        Total busy hours: \(String(format: "%.1f", totalBusyHours))
        Longest free gap hours: \(String(format: "%.1f", longestFreeGapHours))
        Busy blocks:
        \(blockLines)

        Return a percentage and a single short sentence for a home screen card.
        """
    }

    nonisolated func fallbackBatteryState() -> HomeBatteryState {
        let pressure = min(max((totalBusyHours / 10) + (Double(eventCount) / 12), 0), 1)
        let percentage = Int((max(0.18, 0.95 - pressure) * 100).rounded())

        let detail: String
        switch percentage {
        case 75...:
            detail = "Light load ahead. Good room for focused work."
        case 45..<75:
            detail = "Moderate load ahead. Protect your next focus block."
        default:
            detail = "Heavy load ahead. Expect tighter recovery windows."
        }

        return .ready(
            .init(
                headline: "\(percentage)%",
                detail: detail,
                percentage: percentage
            )
        )
    }

    nonisolated func makeBatteryState(from assessment: ResourceBatteryAssessment) -> HomeBatteryState {
        let percentage = min(max(assessment.percentage, 0), 100)
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

    nonisolated static func make(from scheduleItems: [HomeScheduleItem], now: Date) -> Self {
        let windowEnd = now.addingTimeInterval(24 * 60 * 60)
        let relevantItems = scheduleItems
            .map { item in
                let end = item.endDate ?? item.startDate.addingTimeInterval(30 * 60)
                return DateInterval(start: item.startDate, end: end)
            }
            .filter { interval in
                interval.end > now && interval.start < windowEnd
            }
            .sorted { $0.start < $1.start }

        var blocks: [BusyBlock] = []

        for interval in relevantItems {
            let start = max(interval.start, now)
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

        var cursor = now
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
            windowStart: now
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
