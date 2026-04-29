import Foundation
import SentinelCore
import FoundationModels

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
