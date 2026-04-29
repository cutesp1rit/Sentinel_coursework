import SentinelUI
import SentinelCore
import Foundation
import Testing
@testable import Sentinel

@MainActor
@Suite(.serialized)
struct AppConfigurationAndSettingsTests {
    private func clearAppSettingsStorage() {
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        }
        UserDefaults.standard.removeObject(forKey: AppSettingsStorage.key)
        UserDefaults.standard.synchronize()
    }

    @Test
    func appEnvironmentURLsAndSelectability() {
        #expect(AppEnvironment.local.apiBaseURL?.absoluteString == "http://localhost:8000/api/v1")
        #expect(AppEnvironment.local.docsURL?.absoluteString == "http://localhost:8000/docs")
        #expect(AppEnvironment.testing.apiBaseURL?.absoluteString == "http://localhost:8000/api/v1")
        #expect(AppEnvironment.testing.docsURL?.absoluteString == "http://localhost:8000/docs")
        #expect(AppEnvironment.production.apiBaseURL?.absoluteString == "https://sentinel-ai.tech/api/v1")
        #expect(AppEnvironment.production.docsURL?.absoluteString == "https://sentinel-ai.tech/docs")
        #expect(AppEnvironment.local.isSelectable)
        #expect(AppEnvironment.testing.isSelectable)
        #expect(AppEnvironment.production.isSelectable)
    }

    @Test
    func appConfigurationReadsStoredSelectableEnvironment() throws {
        clearAppSettingsStorage()
        defer { clearAppSettingsStorage() }

        #expect(AppConfiguration.currentEnvironment == .local)

        let testing = AppSettings(
            defaultPromptTemplate: "",
            lastActiveChatID: nil,
            lastActiveChatOpenedAt: nil,
            selectedEnvironment: .testing
        )
        UserDefaults.standard.set(
            try AppConfiguration.jsonEncoder.encode(testing),
            forKey: AppSettingsStorage.key
        )
        #expect(AppConfiguration.currentEnvironment == .testing)
    }

    @Test
    func appConfigurationLegalDocumentsAndCodersAreConfigured() throws {
        let links = AppConfiguration.legalDocuments
        #expect(links.count == 5)
        #expect(links.map(\.kind) == [
            .privacyPolicy,
            .termsOfUse,
            .personalDataConsent,
            .attachmentProcessingNotice,
            .privacyChoicesAndAccountDeletion
        ])
        #expect(links.allSatisfy { $0.url.absoluteString.hasPrefix("https://sentinel-ai.tech/") })
        #expect(AppConfiguration.legalDocument(kind: .privacyPolicy)?.url == links[0].url)
        #expect(AppConfiguration.legalDocument(kind: .termsOfUse)?.url == links[1].url)

        let encoded = try AppConfiguration.jsonEncoder.encode(Fixture.session())
        let decoded = try AppConfiguration.jsonDecoder.decode(Session.self, from: encoded)
        #expect(decoded == Fixture.session())
    }

    @Test
    func appSettingsTracksRecentChatAndLoadsDefaults() throws {
        var settings = AppSettings.defaultValue
        #expect(settings.recentActiveChatID(referenceDate: Fixture.referenceDate) == nil)

        settings.markActiveChat(Fixture.chatID, at: Fixture.referenceDate)
        #expect(settings.lastActiveChatID == Fixture.chatID)
        #expect(settings.lastActiveChatOpenedAt == Fixture.referenceDate)
        #expect(settings.recentActiveChatID(referenceDate: Fixture.referenceDate.addingTimeInterval(9 * 60)) == Fixture.chatID)
        #expect(settings.recentActiveChatID(referenceDate: Fixture.referenceDate.addingTimeInterval(11 * 60)) == nil)

        settings.markActiveChat(nil as UUID?, at: Fixture.secondaryDate)
        #expect(settings.lastActiveChatID == nil)
        #expect(settings.lastActiveChatOpenedAt == nil)

        let decoded = try AppConfiguration.jsonDecoder.decode(AppSettings.self, from: Data("{}".utf8))
        #expect(decoded == .defaultValue)
    }

    @Test
    func appSettingsClientLiveValueSavesAndLoads() async {
        clearAppSettingsStorage()
        defer { clearAppSettingsStorage() }

        let saved = AppSettings(
            defaultPromptTemplate: "Deep work",
            lastActiveChatID: Fixture.chatID,
            lastActiveChatOpenedAt: Fixture.referenceDate,
            selectedEnvironment: .production
        )
        await AppSettingsClient.liveValue.save(saved)
        let loaded = await AppSettingsClient.liveValue.load()
        #expect(loaded == saved)
    }
}
