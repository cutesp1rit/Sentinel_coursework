import Foundation

public struct Session: Codable, Equatable, Sendable {
    public let accessToken: String
    public let tokenType: String

    public init(accessToken: String, tokenType: String) {
        self.accessToken = accessToken
        self.tokenType = tokenType
    }
}

public struct User: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let email: String
    public let timezone: String
    public let locale: String
    public let isVerified: Bool
    public let createdAt: Date

    public init(
        id: UUID,
        email: String,
        timezone: String,
        locale: String,
        isVerified: Bool,
        createdAt: Date
    ) {
        self.id = id
        self.email = email
        self.timezone = timezone
        self.locale = locale
        self.isVerified = isVerified
        self.createdAt = createdAt
    }
}
