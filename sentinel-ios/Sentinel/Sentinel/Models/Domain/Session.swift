import Foundation

struct Session: Codable, Equatable, Sendable {
    let accessToken: String
    let tokenType: String
}

struct User: Equatable, Identifiable, Sendable {
    let id: UUID
    let email: String
    let timezone: String
    let locale: String
    let createdAt: Date
}
