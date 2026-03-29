import Foundation

struct UserDTO: Codable, Equatable {
    let id: UUID
    let email: String
    let timezone: String
    let locale: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case email
        case id
        case locale
        case timezone
    }
}

struct RegisterRequestDTO: Encodable, Equatable {
    let email: String
    let password: String
}

struct LoginRequestDTO: Encodable, Equatable {
    let email: String
    let password: String
}

struct TokenDTO: Codable, Equatable {
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}
