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
            let query = sessionStorageQuery()
            let status = SecItemDelete(query as CFDictionary)
            if shouldUseSimulatorFallback(for: status) {
                removeSimulatorSessionFallback()
                return
            }
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw SessionStorageError.unexpectedStatus(status)
            }
            removeSimulatorSessionFallback()
        },
        load: {
            var query = sessionStorageQuery()
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne

            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)

            if status == errSecItemNotFound {
                return nil
            }

            if shouldUseSimulatorFallback(for: status) {
                do {
                    return try await decodeSession(from: simulatorSessionFallback())
                } catch {
                    removeSimulatorSessionFallback()
                    return nil
                }
            }

            guard status == errSecSuccess else {
                throw SessionStorageError.unexpectedStatus(status)
            }

            return try await decodeSession(from: item as? Data)
        },
        save: { session in
            let data = try await MainActor.run {
                try AppConfiguration.jsonEncoder.encode(session)
            }
            let query = sessionStorageQuery()

            let deleteStatus = SecItemDelete(query as CFDictionary)
            if shouldUseSimulatorFallback(for: deleteStatus) {
                writeSimulatorSessionFallback(data)
                return
            }
            guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
                throw SessionStorageError.unexpectedStatus(deleteStatus)
            }

            var attributes = query
            attributes[kSecValueData as String] = data

            let addStatus = SecItemAdd(attributes as CFDictionary, nil)
            if shouldUseSimulatorFallback(for: addStatus) {
                writeSimulatorSessionFallback(data)
                return
            }
            guard addStatus == errSecSuccess else {
                throw SessionStorageError.unexpectedStatus(addStatus)
            }
            removeSimulatorSessionFallback()
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

private nonisolated func sessionStorageQuery() -> [String: Any] {
    [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: Bundle.main.bundleIdentifier ?? "Sentinel",
        kSecAttrAccount as String: "auth-session"
    ]
}

private nonisolated func decodeSession(from data: Data?) async throws -> AuthenticatedSession? {
    guard let data else {
        throw SessionStorageError.invalidPayload
    }

    return try await MainActor.run {
        try AppConfiguration.jsonDecoder.decode(AuthenticatedSession.self, from: data)
    }
}

private nonisolated func shouldUseSimulatorFallback(for status: OSStatus) -> Bool {
#if targetEnvironment(simulator)
    status == errSecMissingEntitlement
#else
    false
#endif
}

private nonisolated func simulatorSessionFallbackKey() -> String {
    "\(Bundle.main.bundleIdentifier ?? "Sentinel").auth-session.fallback"
}

private nonisolated func simulatorSessionFallback() -> Data? {
    UserDefaults.standard.data(forKey: simulatorSessionFallbackKey())
}

private nonisolated func writeSimulatorSessionFallback(_ data: Data) {
    UserDefaults.standard.set(data, forKey: simulatorSessionFallbackKey())
}

private nonisolated func removeSimulatorSessionFallback() {
    UserDefaults.standard.removeObject(forKey: simulatorSessionFallbackKey())
}
