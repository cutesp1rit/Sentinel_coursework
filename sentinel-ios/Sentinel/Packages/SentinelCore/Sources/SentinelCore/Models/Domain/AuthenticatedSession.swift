import Foundation

public struct AuthenticatedSession: Codable, Equatable, Sendable {
    public let accessToken: String
    public let tokenType: String
    public let email: String

    public nonisolated init(session: Session, email: String) {
        self.accessToken = session.accessToken
        self.tokenType = session.tokenType
        self.email = email
    }

    public nonisolated var session: Session {
        Session(accessToken: accessToken, tokenType: tokenType)
    }
}
