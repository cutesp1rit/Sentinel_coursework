import Foundation
import SentinelCore

struct HomeDayMarker: Equatable, Identifiable, Sendable {
    let id: Int
    let title: String
    let dayNumber: String
    let isToday: Bool
    var isSelected = false

    static let previewWeek: [Self] = {
        let calendar = Calendar.current
        let today = Date()

        return (0..<5).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else {
                return nil
            }

            return Self(
                id: offset,
                title: date.formatted(.dateTime.weekday(.abbreviated)),
                dayNumber: date.formatted(.dateTime.day()),
                isToday: offset == 0,
                isSelected: offset == 0
            )
        }
    }()
}
