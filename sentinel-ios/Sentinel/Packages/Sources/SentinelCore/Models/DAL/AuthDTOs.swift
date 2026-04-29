import Foundation

public struct UserDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let email: String
    public let timezone: String
    public let locale: String
    public let isVerified: Bool
    public let createdAt: Date

    public init(id: UUID, email: String, timezone: String, locale: String, isVerified: Bool, createdAt: Date) {
        self.id = id
        self.email = email
        self.timezone = timezone
        self.locale = locale
        self.isVerified = isVerified
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case email
        case id
        case isVerified = "is_verified"
        case locale
        case timezone
    }
}

public struct RegisterRequestDTO: Encodable, Equatable, Sendable {
    public let email: String
    public let password: String
    public let timezone: String

    public init(email: String, password: String, timezone: String) {
        self.email = email
        self.password = password
        self.timezone = timezone
    }
}

public struct LoginRequestDTO: Encodable, Equatable, Sendable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

public struct TokenDTO: Codable, Equatable, Sendable {
    public let accessToken: String
    public let tokenType: String

    public init(accessToken: String, tokenType: String) {
        self.accessToken = accessToken
        self.tokenType = tokenType
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

public struct VerifyEmailRequestDTO: Encodable, Equatable, Sendable {
    public let token: String

    public init(token: String) {
        self.token = token
    }
}

public struct ResendVerificationRequestDTO: Encodable, Equatable, Sendable {
    public let email: String

    public init(email: String) {
        self.email = email
    }
}

public struct ForgotPasswordRequestDTO: Encodable, Equatable, Sendable {
    public let email: String

    public init(email: String) {
        self.email = email
    }
}

public struct ResetPasswordRequestDTO: Encodable, Equatable, Sendable {
    public let token: String
    public let newPassword: String

    public init(token: String, newPassword: String) {
        self.token = token
        self.newPassword = newPassword
    }

    enum CodingKeys: String, CodingKey {
        case newPassword = "new_password"
        case token
    }
}

public struct DeleteAccountRequestDTO: Encodable, Equatable, Sendable {
    public let password: String

    public init(password: String) {
        self.password = password
    }
}
