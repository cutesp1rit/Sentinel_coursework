import ComposableArchitecture
import Foundation

public struct AuthClient: Sendable {
    public var deleteAccount: @Sendable (_ password: String, _ bearerToken: String) async throws -> Void
    public var forgotPassword: @Sendable (_ email: String) async throws -> Void
    public var getMe: @Sendable (_ bearerToken: String) async throws -> User
    public var login: @Sendable (_ email: String, _ password: String) async throws -> Session
    public var register: @Sendable (_ email: String, _ password: String, _ timezone: String) async throws -> User
    public var resendVerification: @Sendable (_ email: String) async throws -> Void
    public var resetPassword: @Sendable (_ token: String, _ newPassword: String) async throws -> Void
    public var verifyEmail: @Sendable (_ token: String) async throws -> Void

    public init(
        deleteAccount: @escaping @Sendable (_ password: String, _ bearerToken: String) async throws -> Void,
        forgotPassword: @escaping @Sendable (_ email: String) async throws -> Void,
        getMe: @escaping @Sendable (_ bearerToken: String) async throws -> User,
        login: @escaping @Sendable (_ email: String, _ password: String) async throws -> Session,
        register: @escaping @Sendable (_ email: String, _ password: String, _ timezone: String) async throws -> User,
        resendVerification: @escaping @Sendable (_ email: String) async throws -> Void,
        resetPassword: @escaping @Sendable (_ token: String, _ newPassword: String) async throws -> Void,
        verifyEmail: @escaping @Sendable (_ token: String) async throws -> Void
    ) {
        self.deleteAccount = deleteAccount
        self.forgotPassword = forgotPassword
        self.getMe = getMe
        self.login = login
        self.register = register
        self.resendVerification = resendVerification
        self.resetPassword = resetPassword
        self.verifyEmail = verifyEmail
    }
}

extension AuthClient: DependencyKey {
    public static let liveValue = AuthClient(
        deleteAccount: { password, bearerToken in
            let body = try await MainActor.run {
                try AppConfiguration.jsonEncoder.encode(DeleteAccountRequestDTO(password: password))
            }
            _ = try await liveAPISend(
                APIRequest(path: "auth/me", method: .delete, body: body, bearerToken: bearerToken)
            )
        },
        forgotPassword: { email in
            let body = try await MainActor.run {
                try AppConfiguration.jsonEncoder.encode(ForgotPasswordRequestDTO(email: email))
            }
            _ = try await liveAPISend(
                APIRequest(path: "auth/forgot-password", method: .post, body: body)
            )
        },
        getMe: { bearerToken in
            let data = try await liveAPISend(
                APIRequest(path: "auth/me", method: .get, bearerToken: bearerToken)
            )
            let dto = try await MainActor.run {
                try AppConfiguration.jsonDecoder.decode(UserDTO.self, from: data)
            }
            return APIModelConverter.convert(dto)
        },
        login: { email, password in
            let body = try await MainActor.run {
                try AppConfiguration.jsonEncoder.encode(LoginRequestDTO(email: email, password: password))
            }
            let data = try await liveAPISend(
                APIRequest(path: "auth/login", method: .post, body: body)
            )
            let dto = try await MainActor.run {
                try AppConfiguration.jsonDecoder.decode(TokenDTO.self, from: data)
            }
            return APIModelConverter.convert(dto)
        },
        register: { email, password, timezone in
            let body = try await MainActor.run {
                try AppConfiguration.jsonEncoder.encode(
                    RegisterRequestDTO(email: email, password: password, timezone: timezone)
                )
            }
            let data = try await liveAPISend(
                APIRequest(path: "auth/register", method: .post, body: body)
            )
            let dto = try await MainActor.run {
                try AppConfiguration.jsonDecoder.decode(UserDTO.self, from: data)
            }
            return APIModelConverter.convert(dto)
        },
        resendVerification: { email in
            let body = try await MainActor.run {
                try AppConfiguration.jsonEncoder.encode(ResendVerificationRequestDTO(email: email))
            }
            _ = try await liveAPISend(
                APIRequest(path: "auth/resend-verification", method: .post, body: body)
            )
        },
        resetPassword: { token, newPassword in
            let body = try await MainActor.run {
                try AppConfiguration.jsonEncoder.encode(
                    ResetPasswordRequestDTO(token: token, newPassword: newPassword)
                )
            }
            _ = try await liveAPISend(
                APIRequest(path: "auth/reset-password", method: .post, body: body)
            )
        },
        verifyEmail: { token in
            let body = try await MainActor.run {
                try AppConfiguration.jsonEncoder.encode(VerifyEmailRequestDTO(token: token))
            }
            _ = try await liveAPISend(
                APIRequest(path: "auth/verify-email", method: .post, body: body)
            )
        }
    )
}

public extension DependencyValues {
    nonisolated var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}
