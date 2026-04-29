import SentinelUI
import SentinelPlatformiOS
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct ChatSheetReducerAndPickerCoverageTests {
    @Test
    func attachmentPickerCoversConsentSatisfiedPresentationAndToggleBranches() async {
        let photo = RecentLibraryPhoto(assetIdentifier: "asset-1", thumbnailData: Data([0x01]))

        var initialState = ChatAttachmentPickerFeature.State()
        initialState.hasProcessingConsent = true
        initialState.selectedRecentPhotoIDs = ["asset-1"]

        let store = TestStore(initialState: initialState) {
            ChatAttachmentPickerFeature()
        } withDependencies: {
            $0.chatAttachmentLibraryClient.loadRecentPhotos = { _ in [photo] }
        }

        await store.send(.presenterTapped) {
            $0.isAttachmentPickerPresented = true
        }
        await store.receive(.recentPhotosRefreshRequested) {
            $0.isLoadingRecentPhotos = true
        }
        await store.receive(.recentPhotosLoaded([photo])) {
            $0.recentPhotos = [photo]
            $0.isLoadingRecentPhotos = false
        }

        await store.send(.attachmentPickerPresentationChanged(false)) {
            $0.isAttachmentPickerPresented = false
            $0.selectedRecentPhotoIDs = []
        }

        await store.send(.cameraTapped) {
            $0.isAttachmentPickerPresented = false
            $0.isCameraPickerPresented = true
        }

        await store.send(.fileImporterPresentationChanged(true)) {
            $0.isFileImporterPresented = true
        }

        await store.send(.cameraPickerPresentationChanged(false)) {
            $0.isCameraPickerPresented = false
        }

        await store.send(.photosPickerPresentationChanged(true)) {
            $0.isPhotosPickerPresented = true
        }

        await store.send(.attachmentImportStarted) {
            $0.isImportingAttachments = true
        }

        await store.send(.attachmentImportFinished) {
            $0.isImportingAttachments = false
        }

        await store.send(.recentPhotoTapped("asset-1")) {
            $0.selectedRecentPhotoIDs = ["asset-1"]
        }
        await store.receive(.delegate(.recentPhotoSelected("asset-1")))

        await store.send(.recentPhotoTapped("asset-1")) {
            $0.selectedRecentPhotoIDs = []
        }
        await store.receive(.delegate(.recentPhotoDeselected("asset-1")))
    }

    @Test
    func attachmentPickerRefreshGuardSkipsWhileAlreadyLoading() async {
        var initialState = ChatAttachmentPickerFeature.State()
        initialState.isLoadingRecentPhotos = true

        let store = TestStore(initialState: initialState) {
            ChatAttachmentPickerFeature()
        }

        await store.send(.recentPhotosRefreshRequested)
        #expect(store.state.isLoadingRecentPhotos)
    }

    @Test
    func chatSheetStateAndReducerCoverSignedOutAndManualPresentationBranches() async {
        var initial = ChatSheetState.initial
        #expect(initial.activeChatTitle == L10n.ChatSheet.newChat)
        #expect(initial.isSignedIn == false)

        let store = TestStore(initialState: initial) {
            ChatSheetReducer()
        }

        await store.send(.chatListButtonTapped)
        #expect(store.state.isChatListPresented == false)

        await store.send(.chatListPresentationChanged(true)) {
            $0.isChatListPresented = true
        }

        await store.send(.detentChanged(.medium)) {
            $0.detent = .medium
        }
    }

    @Test
    func consentStateAndPresentationFlagsCoverRemainingPickerBranches() async {
        let store = TestStore(initialState: ChatAttachmentPickerFeature.State()) {
            ChatAttachmentPickerFeature()
        }

        await store.send(.consentLoaded(true)) {
            $0.hasProcessingConsent = true
        }

        await store.send(.consentAlertPresentationChanged(true)) {
            $0.isConsentAlertPresented = true
        }

        await store.send(.attachmentPickerPresentationChanged(true)) {
            $0.isAttachmentPickerPresented = true
        }

        await store.send(.addFilesTapped) {
            $0.isAttachmentPickerPresented = false
            $0.isFileImporterPresented = true
        }

        await store.send(.allPhotosTapped) {
            $0.isAttachmentPickerPresented = false
            $0.isPhotosPickerPresented = true
        }
    }
}
