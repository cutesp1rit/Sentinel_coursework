import ComposableArchitecture

public struct CalendarSyncClient: Sendable {
    public var detectConflicts: @Sendable (_ drafts: [Draft]) async -> [Draft.ID: Bool]
    public var loadUpcoming: @Sendable () async -> UpcomingSnapshot
    public var sync: @Sendable (_ request: SyncRequest) async throws -> SyncResult

    public init(
        detectConflicts: @escaping @Sendable (_ drafts: [Draft]) async -> [Draft.ID: Bool],
        loadUpcoming: @escaping @Sendable () async -> UpcomingSnapshot,
        sync: @escaping @Sendable (_ request: SyncRequest) async throws -> SyncResult
    ) {
        self.detectConflicts = detectConflicts
        self.loadUpcoming = loadUpcoming
        self.sync = sync
    }
}

extension CalendarSyncClient: DependencyKey {
    public static let liveValue = CalendarSyncClient(
        detectConflicts: { drafts in
            await CalendarSyncClientLive.detectConflictsOnMain(drafts)
        },
        loadUpcoming: {
            await CalendarSyncClientLive.loadUpcomingOnMain()
        },
        sync: { request in
            try await CalendarSyncClientLive.syncOnMain(request)
        }
    )
}

public extension DependencyValues {
    nonisolated var calendarSyncClient: CalendarSyncClient {
        get { self[CalendarSyncClient.self] }
        set { self[CalendarSyncClient.self] = newValue }
    }
}
