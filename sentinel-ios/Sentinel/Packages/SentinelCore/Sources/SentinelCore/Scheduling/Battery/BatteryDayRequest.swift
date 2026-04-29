import Foundation

public struct BatteryScheduleEntry: Equatable, Sendable {
    public let endDate: Date?
    public let startDate: Date

    public init(endDate: Date? = nil, startDate: Date) {
        self.endDate = endDate
        self.startDate = startDate
    }

    public init(event: Event) {
        self.init(endDate: event.endAt, startDate: event.startAt)
    }
}

public struct BatteryDayRequest: Equatable, Sendable {
    public let dayID: String
    public let endDate: Date
    public let entries: [BatteryScheduleEntry]
    public let startDate: Date

    public init(
        dayID: String,
        endDate: Date,
        entries: [BatteryScheduleEntry],
        startDate: Date
    ) {
        self.dayID = dayID
        self.endDate = endDate
        self.entries = entries
        self.startDate = startDate
    }

    public var signature: String {
        let itemSignature = entries
            .map { entry in
                let end = entry.endDate?.timeIntervalSince1970 ?? -1
                return "\(entry.startDate.timeIntervalSince1970)|\(end)"
            }
            .joined(separator: ",")
        return "\(startDate.timeIntervalSince1970)|\(endDate.timeIntervalSince1970)|\(itemSignature)"
    }
}
