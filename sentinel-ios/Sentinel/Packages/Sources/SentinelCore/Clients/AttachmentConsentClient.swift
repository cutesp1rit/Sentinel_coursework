import ComposableArchitecture
import Foundation

enum AttachmentConsentStorage {
    nonisolated static let key = "chat.attachments.processingConsentAccepted"
}

public struct AttachmentConsentClient: Sendable {
    public var load: @Sendable () async -> Bool
    public var save: @Sendable (_ isAccepted: Bool) async -> Void

    public init(
        load: @escaping @Sendable () async -> Bool,
        save: @escaping @Sendable (_ isAccepted: Bool) async -> Void
    ) {
        self.load = load
        self.save = save
    }
}

extension AttachmentConsentClient: DependencyKey {
    public static let liveValue = Self(
        load: {
            await MainActor.run {
                UserDefaults.standard.bool(forKey: AttachmentConsentStorage.key)
            }
        },
        save: { isAccepted in
            await MainActor.run {
                UserDefaults.standard.set(isAccepted, forKey: AttachmentConsentStorage.key)
            }
        }
    )
}

public extension DependencyValues {
    nonisolated var attachmentConsentClient: AttachmentConsentClient {
        get { self[AttachmentConsentClient.self] }
        set { self[AttachmentConsentClient.self] = newValue }
    }
}
