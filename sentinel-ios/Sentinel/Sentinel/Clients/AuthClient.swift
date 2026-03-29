import ComposableArchitecture
import Foundation

struct AuthClient {
    var login: @Sendable (_ email: String, _ password: String) async throws -> Session
    var register: @Sendable (_ email: String, _ password: String) async throws -> User
}

extension AuthClient: DependencyKey {
    static let liveValue = AuthClient(
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
        register: { email, password in
            let body = try await MainActor.run {
                try AppConfiguration.jsonEncoder.encode(RegisterRequestDTO(email: email, password: password))
            }
            let data = try await liveAPISend(
                APIRequest(path: "auth/register", method: .post, body: body)
            )
            let dto = try await MainActor.run {
                try AppConfiguration.jsonDecoder.decode(UserDTO.self, from: data)
            }
            return APIModelConverter.convert(dto)
        }
    )
}

extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}
