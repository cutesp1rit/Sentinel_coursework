import Foundation

public enum AppConfiguration: Sendable {
    private static let legalWebsiteBaseURL = URL(string: "https://sentinel-ai.tech")!

    public static var apiBaseURL: URL {
        currentEnvironment.apiBaseURL ?? URL(string: "http://localhost:8000/api/v1")!
    }

    public static var currentEnvironment: AppEnvironment {
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

    public static var legalDocuments: [LegalDocumentLink] {
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

    public static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
