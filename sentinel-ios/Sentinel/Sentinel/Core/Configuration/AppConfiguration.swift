import Foundation

enum AppConfiguration: Sendable {
    private static let legalWebsiteBaseURL = URL(string: "https://sentinel-ai.tech")!

    static var apiBaseURL: URL {
        currentEnvironment.apiBaseURL ?? URL(string: "http://localhost:8000/api/v1")!
    }

    static var currentEnvironment: AppEnvironment {
        #if DEBUG
        let data = UserDefaults.standard.data(forKey: AppSettingsStorage.key)
        if let data,
           let settings = try? JSONDecoder().decode(AppSettings.self, from: data),
           settings.selectedEnvironment.isSelectable {
            return settings.selectedEnvironment
        }
        return .local
        #else
        return .production
        #endif
    }

    static var legalDocuments: [LegalDocumentLink] {
        [
            .init(
                kind: .privacyPolicy,
                url: legalWebsiteBaseURL.appending(path: "privacy-policy")
            ),
            .init(
                kind: .termsOfUse,
                url: legalWebsiteBaseURL.appending(path: "terms-of-use")
            ),
            .init(
                kind: .personalDataConsent,
                url: legalWebsiteBaseURL.appending(path: "consent-to-personal-data-processing")
            ),
            .init(
                kind: .attachmentProcessingNotice,
                url: legalWebsiteBaseURL.appending(path: "attachment-processing-notice")
            )
        ]
    }

    static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
