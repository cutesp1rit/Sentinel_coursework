import Foundation
import SentinelCore
import FoundationModels

enum BatteryClientLive {
    static func evaluate(
        scheduleItems: [HomeScheduleItem],
        access: HomeScheduleAccess
    ) async -> HomeBatteryState {
        switch modelAvailability() {
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
    }

    static func evaluateDay(request: BatteryDayRequest) async -> DayBatteryBadgeState {
        switch modelAvailability() {
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
}
