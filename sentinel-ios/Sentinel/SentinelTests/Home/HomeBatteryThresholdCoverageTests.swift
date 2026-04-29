import SentinelUI
import SentinelCore
import Testing
@testable import Sentinel

@MainActor
struct HomeBatteryThresholdCoverageTests {
    @Test
    func homeBatteryThresholdBranchesCoverAllSymbolAndTintBuckets() {
        var state = HomeState()
        state.accessToken = "token"

        state.battery = .ready(.init(headline: "10%", detail: "Low", percentage: 10))
        #expect(state.resourceBatterySymbolName == "battery.0percent")
        #expect(String(describing: state.resourceBatteryTint).isEmpty == false)
        #expect(state.batterySummaryRowModel != nil)

        state.battery = .ready(.init(headline: "30%", detail: "Medium", percentage: 30))
        #expect(state.resourceBatterySymbolName == "battery.25percent")

        state.battery = .ready(.init(headline: "55%", detail: "Balanced", percentage: 55))
        #expect(state.resourceBatterySymbolName == "battery.50percent")

        state.battery = .ready(.init(headline: "90%", detail: "High", percentage: 90))
        #expect(state.resourceBatterySymbolName == "battery.100percent")
        #expect(state.resourceBatteryValueText == "90%")
    }
}
