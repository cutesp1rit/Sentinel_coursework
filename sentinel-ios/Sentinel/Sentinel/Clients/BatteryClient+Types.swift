import Foundation
import SentinelCore
import FoundationModels

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

enum BatteryModelAvailability: Sendable {
    case available(SystemLanguageModel)
    case hidden
    case setupRequired(HomeBatterySetupState)
}

@Generable
struct ResourceBatteryAssessment {
    let detail: String
    let percentage: Int
}

@Generable
struct DayResourceBatteryAssessment {
    let percentage: Int
}
