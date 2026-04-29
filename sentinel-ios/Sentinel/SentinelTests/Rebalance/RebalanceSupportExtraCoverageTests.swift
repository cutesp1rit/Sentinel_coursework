import SentinelUI
import SentinelCore
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct RebalanceSupportExtraCoverageTests {
    @Test
    func rebalanceSupportVisibleRangesAndErrorsCoverFallbackBranches() {
        let fallback = RebalanceFeature.visibleRange(for: [])
        #expect(fallback.lowerBound <= fallback.upperBound)

        let custom = RebalanceFeature.visibleRange(for: [Fixture.referenceDate, Fixture.tertiaryDate])
        #expect(custom.lowerBound <= Fixture.referenceDate)
        #expect(custom.upperBound >= Fixture.tertiaryDate)

        let apiError = APIError(code: "BAD", message: "Readable", details: nil)
        #expect(RebalanceFeature.errorMessage(for: apiError) == "Readable")

        struct SampleError: LocalizedError {
            var errorDescription: String? { "Fallback" }
        }
        #expect(RebalanceFeature.errorMessage(for: SampleError()) == "Fallback")
    }
}
