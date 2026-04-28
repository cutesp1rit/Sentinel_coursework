import Foundation

enum AppEnvironment: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case local
    case testing
    case production

    var id: Self { self }

    var apiBaseURL: URL? {
        switch self {
        case .local:
            URL(string: "http://localhost:8000/api/v1")
        case .testing:
            URL(string: "http://localhost:8000/api/v1")
        case .production:
            URL(string: "https://sentinel-ai.tech/api/v1")
        }
    }

    var docsURL: URL? {
        switch self {
        case .local:
            URL(string: "http://localhost:8000/docs")
        case .testing:
            URL(string: "http://localhost:8000/docs")
        case .production:
            URL(string: "https://sentinel-ai.tech/docs")
        }
    }

    var isSelectable: Bool { true }
}

struct LegalDocumentLink: Equatable, Identifiable, Sendable {
    enum Kind: String, CaseIterable, Equatable, Sendable {
        case privacyPolicy
        case termsOfUse
        case personalDataConsent
        case attachmentProcessingNotice
    }

    let kind: Kind
    let url: URL

    var id: Kind { kind }
}
