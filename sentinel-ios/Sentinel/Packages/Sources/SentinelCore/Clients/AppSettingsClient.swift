import ComposableArchitecture
import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var defaultPromptTemplate: String
    public var lastActiveChatID: UUID?
    public var lastActiveChatOpenedAt: Date?
    public var selectedEnvironment: AppEnvironment

    public static var defaultValue: Self {
        Self(
            defaultPromptTemplate: "",
            lastActiveChatID: nil,
            lastActiveChatOpenedAt: nil,
            selectedEnvironment: .local
        )
    }

    public nonisolated func recentActiveChatID(referenceDate: Date = .now) -> UUID? {
        guard let lastActiveChatID,
              let lastActiveChatOpenedAt,
              referenceDate.timeIntervalSince(lastActiveChatOpenedAt) < 10 * 60 else {
            return nil
        }
        return lastActiveChatID
    }

    public nonisolated mutating func markActiveChat(_ chatID: UUID?, at date: Date = .now) {
        lastActiveChatID = chatID
        lastActiveChatOpenedAt = chatID == nil ? nil : date
    }

    public init(
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultPromptTemplate = try container.decodeIfPresent(String.self, forKey: .defaultPromptTemplate) ?? ""
        lastActiveChatID = try container.decodeIfPresent(UUID.self, forKey: .lastActiveChatID)
        lastActiveChatOpenedAt = try container.decodeIfPresent(Date.self, forKey: .lastActiveChatOpenedAt)
        selectedEnvironment = try container.decodeIfPresent(AppEnvironment.self, forKey: .selectedEnvironment) ?? .local
    }
}

public enum AppSettingsStorage {
    public nonisolated static let key = "sentinel.app-settings"
}

public struct AppSettingsClient: Sendable {
    public var load: @Sendable () async -> AppSettings
    public var save: @Sendable (_ settings: AppSettings) async -> Void

    public init(
        load: @escaping @Sendable () async -> AppSettings,
        save: @escaping @Sendable (_ settings: AppSettings) async -> Void
    ) {
        self.load = load
        self.save = save
    }
}

extension AppSettingsClient: DependencyKey {
    public static let liveValue = AppSettingsClient(
        load: {
            await MainActor.run {
                guard let data = UserDefaults.standard.data(forKey: AppSettingsStorage.key),
                      let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
                    return .defaultValue
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

public extension DependencyValues {
    nonisolated var appSettingsClient: AppSettingsClient {
        get { self[AppSettingsClient.self] }
        set { self[AppSettingsClient.self] = newValue }
    }
}
