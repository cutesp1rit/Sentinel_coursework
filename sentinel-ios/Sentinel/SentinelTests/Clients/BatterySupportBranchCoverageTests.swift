import SentinelUI
import SentinelCore
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct BatterySupportBranchCoverageTests {
    @Test
    func batteryDayRequestSignatureAndFallbackBranchesCoverEmptyAndClampedCases() {
        let event = Fixture.event(startAt: Fixture.referenceDate, endAt: nil)
        let entry = BatteryScheduleEntry(event: event)
        #expect(entry.startDate == Fixture.referenceDate)
        #expect(entry.endDate == nil)

        let request = BatteryDayRequest(
            dayID: "day",
            endDate: Fixture.secondaryDate,
            entries: [entry],
            startDate: Fixture.referenceDate
        )
        let changedRequest = BatteryDayRequest(
            dayID: "day",
            endDate: Fixture.tertiaryDate,
            entries: [entry],
            startDate: Fixture.referenceDate
        )
        #expect(request.signature != changedRequest.signature)

        let emptySummary = BatteryScheduleSummary.make(
            from: [],
            windowStart: Fixture.referenceDate,
            windowEnd: Fixture.secondaryDate
        )
        #expect(emptySummary.busyBlocks.isEmpty)
        #expect(emptySummary.eventCount == 0)
        #expect(emptySummary.longestFreeGapHours == 1)
        #expect(emptySummary.homePrompt.contains("No busy blocks"))
        #expect(emptySummary.fallbackPercentage() >= 0)

        let overcommitted = BatteryScheduleSummary.make(
            from: [
                BatteryScheduleEntry(endDate: Fixture.referenceDate.addingTimeInterval(20 * 60 * 60), startDate: Fixture.referenceDate)
            ],
            windowStart: Fixture.referenceDate,
            windowEnd: Fixture.referenceDate.addingTimeInterval(24 * 60 * 60)
        )
        #expect(overcommitted.fallbackPercentage() <= 100)
        #expect(overcommitted.makeBatteryState(from: ResourceBatteryAssessment(detail: "Busy\nDay", percentage: -10)).displaySnapshot.percentage == 0)
    }
}
