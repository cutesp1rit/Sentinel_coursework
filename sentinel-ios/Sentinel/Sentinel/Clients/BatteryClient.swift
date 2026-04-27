import ComposableArchitecture
import Foundation
import FoundationModels

enum DayBatteryBadgeState: Equatable, Sendable {
    case hidden
    case loading
    case ready(Int)
}

struct DayBatteryCacheEntry: Equatable, Sendable {
    let signature: String
    var state: DayBatteryBadgeState
}

struct BatteryScheduleEntry: Equatable, Sendable {
    let endDate: Date?
    let startDate: Date

    init(endDate: Date? = nil, startDate: Date) {
        self.endDate = endDate
        self.startDate = startDate
    }

    init(event: Event) {
        self.init(endDate: event.endAt, startDate: event.startAt)
    }

}

struct BatteryDayRequest: Equatable, Sendable {
    let dayID: String
    let endDate: Date
    let entries: [BatteryScheduleEntry]
    let startDate: Date

    nonisolated var signature: String {
        let itemSignature = entries
            .map { entry in
                let end = entry.endDate?.timeIntervalSince1970 ?? -1
                return "\(entry.startDate.timeIntervalSince1970)|\(end)"
            }
            .joined(separator: ",")
        return "\(startDate.timeIntervalSince1970)|\(endDate.timeIntervalSince1970)|\(itemSignature)"
    }
}

struct BatteryClient: Sendable {
    var evaluate: @Sendable (_ scheduleItems: [HomeScheduleItem], _ access: HomeScheduleAccess) async -> HomeBatteryState
    var evaluateDay: @Sendable (_ request: BatteryDayRequest) async -> DayBatteryBadgeState
}

extension BatteryClient: DependencyKey {
    static let liveValue = BatteryClient(
        evaluate: { scheduleItems, access in
            switch Self.modelAvailability() {
            case let .available(model):
                switch access {
                case .granted:
                    break
                case .notRequested, .denied:
                    return .placeholder
                }

                let now = Date.now
                let entries = await MainActor.run {
                    scheduleItems.map { item in
                        BatteryScheduleEntry(
                            endDate: item.endDate,
                            startDate: item.startDate
                        )
                    }
                }
                let summary = BatteryScheduleSummary.make(
                    from: entries,
                    windowStart: now,
                    windowEnd: now.addingTimeInterval(24 * 60 * 60)
                )

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
                        to: summary.homePrompt,
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

            case let .setupRequired(setupState):
                return .setupRequired(setupState)

            case .hidden:
                return .hidden
            }
        },
        evaluateDay: { request in
            switch Self.modelAvailability() {
            case let .available(model):
                let summary = BatteryScheduleSummary.make(
                    from: request.entries,
                    windowStart: request.startDate,
                    windowEnd: request.endDate
                )

                do {
                    let session = LanguageModelSession(
                        model: model,
                        instructions: """
                        You estimate a daily resource battery percentage from calendar load.
                        Use only the schedule facts provided by the app.
                        Treat 100 as a very light day and 0 as an overloaded day.
                        Return a stable integer percentage only.
                        """
                    )
                    let response = try await session.respond(
                        to: summary.dayPrompt,
                        generating: DayResourceBatteryAssessment.self,
                        options: GenerationOptions(
                            sampling: .greedy,
                            maximumResponseTokens: 40
                        )
                    )
                    return .ready(summary.normalizedPercentage(response.content.percentage))
                } catch {
                    return .ready(summary.fallbackPercentage())
                }

            case .setupRequired, .hidden:
                return .hidden
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

private enum BatteryModelAvailability: Sendable {
    case available(SystemLanguageModel)
    case hidden
    case setupRequired(HomeBatterySetupState)
}

@Generable
private struct ResourceBatteryAssessment {
    let detail: String
    let percentage: Int
}

@Generable
private struct DayResourceBatteryAssessment {
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

private extension BatteryClient {
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
