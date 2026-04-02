import ComposableArchitecture
import Foundation
import Security

struct SessionStorageClient: Sendable {
    var clear: @Sendable () throws -> Void
    var load: @Sendable () async throws -> AuthenticatedSession?
    var save: @Sendable (_ session: AuthenticatedSession) async throws -> Void
}

extension SessionStorageClient: DependencyKey {
    static let liveValue = SessionStorageClient(
        clear: {
            let query = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Bundle.main.bundleIdentifier ?? "Sentinel",
                kSecAttrAccount as String: "auth-session"
            ]
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw SessionStorageError.unexpectedStatus(status)
            }
        },
        load: {
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Bundle.main.bundleIdentifier ?? "Sentinel",
                kSecAttrAccount as String: "auth-session"
            ]
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne

            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)

            if status == errSecItemNotFound {
                return nil
            }

            guard status == errSecSuccess else {
                throw SessionStorageError.unexpectedStatus(status)
            }

            guard let data = item as? Data else {
                throw SessionStorageError.invalidPayload
            }

            return try await MainActor.run {
                try AppConfiguration.jsonDecoder.decode(AuthenticatedSession.self, from: data)
            }
        },
        save: { session in
            let data = try await MainActor.run {
                try AppConfiguration.jsonEncoder.encode(session)
            }
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Bundle.main.bundleIdentifier ?? "Sentinel",
                kSecAttrAccount as String: "auth-session"
            ]

            let deleteStatus = SecItemDelete(query as CFDictionary)
            guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
                throw SessionStorageError.unexpectedStatus(deleteStatus)
            }

            var attributes = query
            attributes[kSecValueData as String] = data

            let addStatus = SecItemAdd(attributes as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw SessionStorageError.unexpectedStatus(addStatus)
            }
        }
    )
}

extension DependencyValues {
    nonisolated var sessionStorageClient: SessionStorageClient {
        get { self[SessionStorageClient.self] }
        set { self[SessionStorageClient.self] = newValue }
    }
}

private enum SessionStorageError: LocalizedError, Sendable {
    case invalidPayload
    case unexpectedStatus(OSStatus)

    nonisolated var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "Stored session payload is invalid."
        case let .unexpectedStatus(status):
            return "Keychain request failed with status \(status)."
        }
    }
}
