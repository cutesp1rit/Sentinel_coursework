import Foundation
import SentinelCore

extension CalendarState {
    func batteryRequest(for sectionID: AgendaSection.ID) -> BatteryDayRequest? {
        guard let section = agendaSections.first(where: { $0.id == sectionID }) else {
            return nil
        }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: section.date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        let entries = events
            .filter { calendar.isDate($0.startAt, inSameDayAs: startDate) }
            .sorted { $0.startAt < $1.startAt }
            .map(BatteryScheduleEntry.init(event:))

        return BatteryDayRequest(
            dayID: sectionID,
            endDate: endDate,
            entries: entries,
            startDate: startDate
        )
    }
}
