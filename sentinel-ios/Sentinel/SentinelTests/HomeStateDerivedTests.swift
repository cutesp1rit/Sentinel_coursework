import Foundation
import Testing
@testable import Sentinel

@MainActor
struct HomeStateDerivedTests {
    @Test
    func identityDerivedValuesUseAuthenticationAndEmail() {
        var state = HomeState()
        #expect(state.displayName == "Sentinel")
        #expect(state.isAuthenticated == false)

        state.accessToken = "token"
        state.userEmail = "jane_doe.smith@example.com"
        #expect(state.isAuthenticated)
        #expect(state.displayName == "Jane Doe Smith")
        #expect(!state.currentDateText.isEmpty)
    }

    @Test
    func batteryDerivedValuesReflectState() {
        var state = HomeState()
        #expect(state.batteryMetricCard == nil)

        state.accessToken = "token"
        state.battery = .placeholder
        #expect(state.showsBatteryMetricCard)
        #expect(state.resourceBatteryProgress == 0)
        #expect(state.resourceBatteryValueText == L10n.Home.batteryPendingValue)
        #expect(state.resourceBatterySymbolName == "calendar.badge.clock")
        #expect(state.isBatteryMetricActionable == false)

        state.battery = .setupRequired(.downloadModel)
        #expect(state.resourceBatteryValueText == L10n.Home.batteryDownloadValue)
        #expect(state.resourceBatterySymbolName == "arrow.down.circle.fill")
        #expect(state.isBatteryMetricActionable)

        state.battery = .ready(.init(headline: "78%", detail: "Plenty of room", percentage: 78))
        #expect(state.resourceBatteryProgress == 0.78)
        #expect(state.resourceBatteryValueText == "78%")
        #expect(state.resourceBatterySymbolName == "battery.75percent")
        #expect(state.resourceBatteryTint != .clear)
        #expect(state.batteryMetricCard?.value == "78%")

        state.battery = .hidden
        #expect(state.resourceBatteryValueText == L10n.Home.batteryUnavailableValue)
        #expect(state.resourceBatterySymbolName == nil)
    }

    @Test
    func scheduleDerivedValuesBuildSectionsRowsAndMetricCard() {
        var state = HomeState()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let todayMorning = calendar.date(byAdding: .hour, value: 9, to: today) ?? .now
        let todayNoon = calendar.date(byAdding: .hour, value: 12, to: today) ?? .now
        let todayEvening = calendar.date(byAdding: .hour, value: 18, to: today) ?? .now
        let tomorrowMorning = calendar.date(byAdding: .day, value: 1, to: todayMorning) ?? .now
        state.schedule.upcomingItems = [
            Fixture.homeItem(title: "Today A", startDate: todayMorning, endDate: todayNoon),
            Fixture.homeItem(title: "Today B", startDate: todayNoon, endDate: todayEvening, subtitle: "Office"),
            Fixture.homeItem(title: "Tomorrow", startDate: tomorrowMorning)
        ]

        #expect(state.todayItems.count == 2)
        #expect(state.todayPreviewItems.count == 2)
        #expect(state.todayPreviewRows.count == 2)
        #expect(state.todayPreviewRows[0].location == nil)
        #expect(state.todayTitle == L10n.Home.todayCount(2))
        #expect(state.scheduleMetricDetail.contains("Next:"))
        #expect(state.scheduleMetricValue == L10n.Home.metricNextValue)
        #expect(state.allEventSections.count == 2)
        #expect(state.scheduleMetricCard.title == L10n.Home.metricTodayTitle)
        #expect(state.scheduleMetricCard.systemImage == "calendar.badge.clock")
        #expect(state.displayDayStrip.first?.isSelected == true)
    }

    @Test
    func todaySnapshotReflectsAuthLoadingErrorsAndEvents() {
        var state = HomeState()
        #expect(state.todaySnapshot.title == L10n.Home.signedOutHeroTitle)

        state.accessToken = "token"
        state.schedule.isLoading = true
        #expect(state.todaySnapshot.title == L10n.Home.loadingTitle)

        state.schedule.isLoading = false
        state.schedule.errorMessage = "boom"
        #expect(state.todaySnapshot.title == L10n.Home.calendarErrorTitle)

        state.schedule.errorMessage = nil
        state.schedule.access = .notRequested
        #expect(state.todaySnapshot.detail == L10n.Home.todaySummaryBody)

        state.schedule.access = .denied
        #expect(state.todaySnapshot.title == L10n.Home.calendarDeniedTitle)

        state.schedule.access = .granted
        state.schedule.upcomingItems = []
        #expect(state.todaySnapshot.detail == L10n.Home.noEventsTodayBody)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let todayMorning = calendar.date(byAdding: .hour, value: 9, to: today) ?? .now
        let todayNoon = calendar.date(byAdding: .hour, value: 10, to: today) ?? .now
        state.schedule.upcomingItems = [
            Fixture.homeItem(title: "Planning", startDate: todayMorning, endDate: todayNoon)
        ]
        #expect(state.todaySnapshot.title == "1 events planned")
        #expect(state.todaySnapshot.detail.contains("Planning"))
    }
}
