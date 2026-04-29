import SentinelUI
import SentinelPlatformiOS
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct ChatAttachmentPickerFeatureTests {
    @Test
    func consentAndPresentationFlowStaysInsideFeatureState() async {
        let photo = RecentLibraryPhoto(assetIdentifier: "asset-1", thumbnailData: Data([0x01]))

        let store = TestStore(initialState: ChatAttachmentPickerFeature.State()) {
            ChatAttachmentPickerFeature()
        } withDependencies: {
            $0.attachmentConsentClient.load = { false }
            $0.attachmentConsentClient.save = { _ in }
            $0.chatAttachmentLibraryClient.loadRecentPhotos = { _ in [photo] }
            $0.chatAttachmentLibraryClient.makeAttachmentFromRecentPhoto = { _, _ in nil }
        }

        await store.send(.task)
        await store.receive(.consentLoaded(false))

        await store.send(.presenterTapped) {
            $0.isConsentAlertPresented = true
        }

        await store.send(.consentConfirmed) {
            $0.hasProcessingConsent = true
            $0.isConsentAlertPresented = false
            $0.isAttachmentPickerPresented = true
        }
        await store.receive(.recentPhotosRefreshRequested) {
            $0.isLoadingRecentPhotos = true
        }
        await store.receive(.recentPhotosLoaded([photo])) {
            $0.isLoadingRecentPhotos = false
            $0.recentPhotos = [photo]
        }

        await store.send(.recentPhotoTapped("asset-1")) {
            $0.selectedRecentPhotoIDs = ["asset-1"]
        }
        await store.receive(.delegate(.recentPhotoSelected("asset-1")))

        await store.send(.allPhotosTapped) {
            $0.isAttachmentPickerPresented = false
            $0.isPhotosPickerPresented = true
        }
    }

    @Test
    func parentReducerLoadsRecentPhotoIntoComposerAttachments() async {
        let photo = RecentLibraryPhoto(assetIdentifier: "asset-1", thumbnailData: Data([0x01]))
        let attachment = ChatComposerAttachment(
            data: Data([0x01, 0x02]),
            previewData: Data([0x03]),
            filename: "recent.jpg",
            mimeType: "image/jpeg"
        )

        var initialState = ChatThreadFeature.State()
        initialState.accessToken = "token"
        initialState.attachmentPicker.hasProcessingConsent = true

        let store = TestStore(initialState: initialState) {
            ChatThreadFeature()
        } withDependencies: {
            $0.chatAttachmentLibraryClient.loadRecentPhotos = { _ in [photo] }
            $0.chatAttachmentLibraryClient.makeAttachmentFromRecentPhoto = { assetIdentifier, index in
                #expect(assetIdentifier == "asset-1")
                #expect(index == 0)
                return attachment
            }
        }
        store.exhaustivity = .off

        await store.send(.attachmentButtonTapped)
        await store.receive(.delegate(.attachmentFlowRequested))
        await store.receive(.attachmentPicker(.presenterTapped)) {
            $0.attachmentPicker.isAttachmentPickerPresented = true
        }
        await store.receive(.attachmentPicker(.recentPhotosRefreshRequested)) {
            $0.attachmentPicker.isLoadingRecentPhotos = true
        }
        await store.receive(.attachmentPicker(.recentPhotosLoaded([photo]))) {
            $0.attachmentPicker.isLoadingRecentPhotos = false
            $0.attachmentPicker.recentPhotos = [photo]
        }

        await store.send(.attachmentPicker(.recentPhotoTapped("asset-1"))) {
            $0.attachmentPicker.selectedRecentPhotoIDs = ["asset-1"]
        }
        await store.receive(.attachmentPicker(.delegate(.recentPhotoSelected("asset-1"))))
        await store.receive(.recentPhotoAttachmentLoaded("asset-1", attachment))
        await store.receive(.attachmentsAdded([attachment])) {
            $0.composerAttachments = [attachment]
        }
    }
}
