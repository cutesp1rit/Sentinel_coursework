import ComposableArchitecture
import Foundation

struct AppSettings: Codable, Equatable, Sendable {
    var defaultPromptTemplate: String
    var lastActiveChatID: UUID?
    var lastActiveChatOpenedAt: Date?
    var selectedEnvironment: AppEnvironment

    nonisolated static let `default` = AppSettings(
        defaultPromptTemplate: "",
        lastActiveChatID: nil,
        lastActiveChatOpenedAt: nil,
        selectedEnvironment: .local
    )

    func recentActiveChatID(referenceDate: Date = .now) -> UUID? {
        guard let lastActiveChatID,
              let lastActiveChatOpenedAt,
              referenceDate.timeIntervalSince(lastActiveChatOpenedAt) < 10 * 60 else {
            return nil
        }
        return lastActiveChatID
    }

    mutating func markActiveChat(_ chatID: UUID?, at date: Date = .now) {
        lastActiveChatID = chatID
        lastActiveChatOpenedAt = chatID == nil ? nil : date
    }

    init(
        defaultPromptTemplate: String,
        lastActiveChatID: UUID?,
        lastActiveChatOpenedAt: Date?,
        selectedEnvironment: AppEnvironment
    ) {
        self.defaultPromptTemplate = defaultPromptTemplate
        self.lastActiveChatID = lastActiveChatID
        self.lastActiveChatOpenedAt = lastActiveChatOpenedAt
        self.selectedEnvironment = selectedEnvironment
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultPromptTemplate = try container.decodeIfPresent(String.self, forKey: .defaultPromptTemplate) ?? ""
        lastActiveChatID = try container.decodeIfPresent(UUID.self, forKey: .lastActiveChatID)
        lastActiveChatOpenedAt = try container.decodeIfPresent(Date.self, forKey: .lastActiveChatOpenedAt)
        selectedEnvironment = try container.decodeIfPresent(AppEnvironment.self, forKey: .selectedEnvironment) ?? .local
    }
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
