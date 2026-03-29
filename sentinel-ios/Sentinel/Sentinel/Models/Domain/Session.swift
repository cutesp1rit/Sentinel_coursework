import Foundation

struct Session: Equatable {
    let accessToken: String
    let tokenType: String
}

struct User: Equatable, Identifiable {
    let id: UUID
    let email: String
    let timezone: String
    let locale: String
    let createdAt: Date
}
