import ComposableArchitecture
import Foundation

struct AppSettings: Codable, Equatable, Sendable {
    var defaultPromptTemplate: String
    var notificationsEnabled: Bool

    nonisolated static let `default` = AppSettings(
        defaultPromptTemplate: "",
        notificationsEnabled: false
    )
}

enum AppSettingsStorage {
    nonisolated static let key = "sentinel.app-settings"
}

struct AppSettingsClient: Sendable {
    var load: @Sendable () async -> AppSettings
    var save: @Sendable (_ settings: AppSettings) async -> Void
}

extension AppSettingsClient: DependencyKey {
    static let liveValue = AppSettingsClient(
        load: {
            await MainActor.run {
                guard let data = UserDefaults.standard.data(forKey: AppSettingsStorage.key),
                      let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
                    return .default
                }
                return settings
            }
        },
        save: { settings in
            await MainActor.run {
                if let data = try? JSONEncoder().encode(settings) {
                    UserDefaults.standard.set(data, forKey: AppSettingsStorage.key)
                }
            }
        }
    )
}

extension DependencyValues {
    nonisolated var appSettingsClient: AppSettingsClient {
        get { self[AppSettingsClient.self] }
        set { self[AppSettingsClient.self] = newValue }
    }
}
