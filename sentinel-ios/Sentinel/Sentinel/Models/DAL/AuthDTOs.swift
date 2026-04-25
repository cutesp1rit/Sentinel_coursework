import Foundation

struct UserDTO: Codable, Equatable {
    let id: UUID
    let email: String
    let timezone: String
    let locale: String
    let isVerified: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case email
        case id
        case isVerified = "is_verified"
        case locale
        case timezone
    }
}

struct RegisterRequestDTO: Encodable, Equatable {
    let email: String
    let password: String
    let timezone: String
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

struct VerifyEmailRequestDTO: Encodable, Equatable {
    let token: String
}

struct ResendVerificationRequestDTO: Encodable, Equatable {
    let email: String
}

struct ForgotPasswordRequestDTO: Encodable, Equatable {
    let email: String
}

struct ResetPasswordRequestDTO: Encodable, Equatable {
    let token: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case newPassword = "new_password"
        case token
    }
}

struct DeleteAccountRequestDTO: Encodable, Equatable {
    let password: String
}
