import ComposableArchitecture
import Foundation
import UserNotifications

struct LocalNotificationsClient: Sendable {
    var removeAllSentinelRequests: @Sendable () async -> Void
    var requestAuthorization: @Sendable () async -> Bool
    var syncReminderNotifications: @Sendable (_ events: [Event], _ deletedEventIDs: Set<UUID>) async -> Void
}

extension LocalNotificationsClient: DependencyKey {
    static let liveValue = LocalNotificationsClient(
        removeAllSentinelRequests: {
            await LocalNotificationsCoordinator.removeAllSentinelRequests()
        },
        requestAuthorization: {
            await LocalNotificationsCoordinator.requestAuthorization()
        },
        syncReminderNotifications: { events, deletedEventIDs in
            await LocalNotificationsCoordinator.syncReminderNotifications(events: events, deletedEventIDs: deletedEventIDs)
        }
    )
}

extension DependencyValues {
    nonisolated var localNotificationsClient: LocalNotificationsClient {
        get { self[LocalNotificationsClient.self] }
        set { self[LocalNotificationsClient.self] = newValue }
    }
}

@MainActor
private enum LocalNotificationsCoordinator {
    static func removeAllSentinelRequests() async {
        let center = UNUserNotificationCenter.current()
        let ids = await pendingSentinelIdentifiers(center: center)
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    static func syncReminderNotifications(events: [Event], deletedEventIDs: Set<UUID>) async {
        let center = UNUserNotificationCenter.current()
        let appSettings = loadSettings()

        center.removePendingNotificationRequests(withIdentifiers: deletedEventIDs.map(identifier(for:)))

        guard appSettings.notificationsEnabled else {
            let ids = await pendingSentinelIdentifiers(center: center)
            center.removePendingNotificationRequests(withIdentifiers: ids)
            return
        }

        for event in events where event.type == .reminder {
            let requestID = identifier(for: event.id)
            center.removePendingNotificationRequests(withIdentifiers: [requestID])

            guard event.startAt > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = event.title
            content.body = event.description ?? "Reminder from Sentinel"
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: event.startAt
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
            try? await add(request, center: center)
        }
    }

    static func add(_ request: UNNotificationRequest, center: UNUserNotificationCenter) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    static func identifier(for eventID: UUID) -> String {
        "sentinel-reminder-\(eventID.uuidString)"
    }

    static func loadSettings() -> AppSettings {
        let settingsData = UserDefaults.standard.data(forKey: AppSettingsStorage.key)
        return settingsData.flatMap { try? JSONDecoder().decode(AppSettings.self, from: $0) } ?? .default
    }

    static func pendingSentinelIdentifiers(center: UNUserNotificationCenter) async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                let identifiers = requests
                    .map(\.identifier)
                    .filter { $0.hasPrefix("sentinel-reminder-") }
                continuation.resume(returning: identifiers)
            }
        }
    }
}
