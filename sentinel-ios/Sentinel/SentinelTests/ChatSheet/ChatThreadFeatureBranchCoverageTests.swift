import SentinelUI
import SentinelPlatformiOS
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct ChatThreadFeatureBranchCoverageTests {
    @Test
    func chatThreadGuardsAndSimpleStateTransitionsCoverNoopBranches() async {
        var initialState = ChatThreadFeature.State()
        initialState.shouldAutoScrollToBottom = true

        let store = TestStore(initialState: initialState) {
            ChatThreadFeature()
        }
        store.exhaustivity = .off

        await store.send(.attachmentButtonTapped)
        await store.send(.loadMessagesRequested(reset: true))
        await store.send(.loadMoreHistoryTapped)
        await store.send(.onAppear)
        await store.send(.refreshSuggestionConflictsRequested(UUID()))
        await store.send(.retryTapped)

        await store.send(.draftChanged("Hello")) {
            $0.draft = "Hello"
        }

        await store.send(.autoScrollCompleted) {
            $0.shouldAutoScrollToBottom = false
        }

        await store.send(.composerFocusChanged)
        await store.receive(.delegate(.expandRequested))
    }

    @Test
    func attachmentAndMessageMutationBranchesHandleLimitsRemovalAndFailures() async {
        var initialState = ChatThreadFeature.State()
        initialState.accessToken = "token"
        initialState.messages = [ChatThreadMessage(id: Fixture.messageID, role: .user, text: "Draft")]
        initialState.recentPhotoAttachmentIDs = ["asset-1": UUID()]

        let tooLargeStore = TestStore(initialState: initialState) {
            ChatThreadFeature()
        }
        tooLargeStore.exhaustivity = .off

        let tooLarge = ChatComposerAttachment(
            data: Data(count: ChatThreadFeature.Constants.maxAttachmentSize + 1),
            previewData: nil,
            filename: "large.png",
            mimeType: "image/png"
        )
        await tooLargeStore.send(.attachmentsAdded([tooLarge])) {
            $0.errorMessage = L10n.ChatSheet.attachmentTooLarge
        }

        var fullState = initialState
        fullState.composerAttachments = (0..<ChatThreadFeature.Constants.attachmentLimit).map { index in
            ChatComposerAttachment(
                data: Data([UInt8(index)]),
                previewData: nil,
                filename: "file\(index).png",
                mimeType: "image/png"
            )
        }
        let fullStore = TestStore(initialState: fullState) {
            ChatThreadFeature()
        }
        fullStore.exhaustivity = .off
        let extra = ChatComposerAttachment(data: Data([0x09]), previewData: nil, filename: "extra.png", mimeType: "image/png")
        await fullStore.send(.attachmentsAdded([extra])) {
            $0.errorMessage = L10n.ChatSheet.attachmentLimitReached
        }

        let removable = fullState.composerAttachments[0]
        fullState.recentPhotoAttachmentIDs = ["asset-x": removable.id]
        let removalStore = TestStore(initialState: fullState) {
            ChatThreadFeature()
        }
        removalStore.exhaustivity = .off
        await removalStore.send(.attachmentRemoved(removable.id)) {
            $0.composerAttachments.removeAll { $0.id == removable.id }
            $0.recentPhotoAttachmentIDs = [:]
        }

        let failedMessageStore = TestStore(initialState: initialState) {
            ChatThreadFeature()
        }
        failedMessageStore.exhaustivity = .off
        await failedMessageStore.send(.failedMessageRemoveTapped(Fixture.messageID)) {
            $0.messages = []
        }
    }

    @Test
    func activeChatAndRecentPhotoBranchesHandleResetAndDeselection() async {
        let attachment = ChatComposerAttachment(
            data: Data([0x01]),
            previewData: nil,
            filename: "recent.png",
            mimeType: "image/png"
        )

        var initialState = ChatThreadFeature.State()
        initialState.accessToken = "token"
        initialState.activeChatID = Fixture.chatID
        initialState.messages = [ChatThreadMessage(role: .assistant, text: "Old")]
        initialState.hasMoreHistory = true
        initialState.errorMessage = "boom"
        initialState.isLoadingMessages = true
        initialState.isLoadingMoreHistory = true
        initialState.recentPhotoAttachmentIDs = ["asset-1": attachment.id]
        initialState.composerAttachments = [attachment]

        let store = TestStore(initialState: initialState) {
            ChatThreadFeature()
        }
        store.exhaustivity = .off

        await store.send(.activeChatChanged(Fixture.chatID))

        await store.send(.activeChatChanged(nil)) {
            $0.activeChatID = nil
            $0.messages = []
            $0.errorMessage = nil
            $0.hasMoreHistory = false
            $0.isLoadingMessages = false
            $0.isLoadingMoreHistory = false
        }

        await store.send(.recentPhotoAttachmentLoaded("asset-2", nil)) {
            $0.attachmentPicker.selectedRecentPhotoIDs.removeAll { $0 == "asset-2" }
        }

        await store.send(.attachmentPicker(.delegate(.recentPhotoDeselected("asset-1")))) {
            $0.recentPhotoAttachmentIDs = [:]
            $0.composerAttachments = []
        }
    }
}
