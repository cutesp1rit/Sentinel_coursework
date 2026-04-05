import Foundation

struct AuthenticatedSession: Codable, Equatable, Sendable {
    let accessToken: String
    let tokenType: String
    let email: String

    nonisolated init(session: Session, email: String) {
        self.accessToken = session.accessToken
        self.tokenType = session.tokenType
        self.email = email
    }

    nonisolated var session: Session {
        Session(accessToken: accessToken, tokenType: tokenType)
    }
}
