import Foundation

public enum AppEnvironment: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case local
    case testing
    case production

    public var id: Self { self }

    public var apiBaseURL: URL? {
        switch self {
        case .local:
            URL(string: "http://localhost:8000/api/v1")
        case .testing:
            URL(string: "http://localhost:8000/api/v1")
        case .production:
            URL(string: "https://sentinel-ai.tech/api/v1")
        }
    }

    public var docsURL: URL? {
        switch self {
        case .local:
            URL(string: "http://localhost:8000/docs")
        case .testing:
            URL(string: "http://localhost:8000/docs")
        case .production:
            URL(string: "https://sentinel-ai.tech/docs")
        }
    }

    public var isSelectable: Bool { true }
}

public struct LegalDocumentLink: Equatable, Identifiable, Sendable {
    public enum Kind: String, CaseIterable, Equatable, Sendable {
        case privacyPolicy
        case termsOfUse
        case personalDataConsent
        case attachmentProcessingNotice
        case privacyChoicesAndAccountDeletion
    }

    public let kind: Kind
    public let url: URL

    public var id: Kind { kind }

    public init(kind: Kind, url: URL) {
        self.kind = kind
        self.url = url
    }
}
