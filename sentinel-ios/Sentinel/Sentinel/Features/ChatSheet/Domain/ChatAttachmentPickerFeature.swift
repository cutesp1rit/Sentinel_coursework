import ComposableArchitecture
import SentinelPlatformiOS
import SentinelCore
import Foundation

@Reducer
struct ChatAttachmentPickerFeature {
    @Dependency(\.attachmentConsentClient) var attachmentConsentClient
    @Dependency(\.chatAttachmentLibraryClient) var chatAttachmentLibraryClient

    @ObservableState
    struct State: Equatable {
        var hasProcessingConsent = false
        var isConsentAlertPresented = false
        var isAttachmentPickerPresented = false
        var isCameraPickerPresented = false
        var isFileImporterPresented = false
        var isImportingAttachments = false
        var isLoadingRecentPhotos = false
        var isPhotosPickerPresented = false
        var recentPhotos: [RecentLibraryPhoto] = []
        var selectedRecentPhotoIDs: [RecentLibraryPhoto.ID] = []
    }

    @CasePathable
    enum Action: Equatable {
        case addFilesTapped
        case allPhotosTapped
        case attachmentImportFinished
        case attachmentImportStarted
        case attachmentPickerPresentationChanged(Bool)
        case cameraPickerPresentationChanged(Bool)
        case cameraTapped
        case consentAlertPresentationChanged(Bool)
        case consentConfirmed
        case consentLoaded(Bool)
        case fileImporterPresentationChanged(Bool)
        case photosPickerPresentationChanged(Bool)
        case presenterTapped
        case recentPhotoTapped(RecentLibraryPhoto.ID)
        case recentPhotosLoaded([RecentLibraryPhoto])
        case recentPhotosRefreshRequested
        case task
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case recentPhotoDeselected(RecentLibraryPhoto.ID)
        case recentPhotoSelected(RecentLibraryPhoto.ID)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { [attachmentConsentClient] send in
                    await send(.consentLoaded(await attachmentConsentClient.load()))
                }

            case let .consentLoaded(isAccepted):
                state.hasProcessingConsent = isAccepted
                return .none

            case .presenterTapped:
                guard state.hasProcessingConsent else {
                    state.isConsentAlertPresented = true
                    return .none
                }
                state.isAttachmentPickerPresented = true
                return .send(.recentPhotosRefreshRequested)

            case let .consentAlertPresentationChanged(isPresented):
                state.isConsentAlertPresented = isPresented
                return .none

            case .consentConfirmed:
                state.hasProcessingConsent = true
                state.isConsentAlertPresented = false
                state.isAttachmentPickerPresented = true
                return .merge(
                    .run { [attachmentConsentClient] _ in
                        await attachmentConsentClient.save(true)
                    },
                    .send(.recentPhotosRefreshRequested)
                )

            case let .attachmentPickerPresentationChanged(isPresented):
                state.isAttachmentPickerPresented = isPresented
                if !isPresented {
                    state.selectedRecentPhotoIDs = []
                }
                return .none

            case let .cameraPickerPresentationChanged(isPresented):
                state.isCameraPickerPresented = isPresented
                return .none

            case let .fileImporterPresentationChanged(isPresented):
                state.isFileImporterPresented = isPresented
                return .none

            case let .photosPickerPresentationChanged(isPresented):
                state.isPhotosPickerPresented = isPresented
                return .none

            case .recentPhotosRefreshRequested:
                guard !state.isLoadingRecentPhotos else { return .none }
                state.isLoadingRecentPhotos = true
                return .run { [chatAttachmentLibraryClient] send in
                    await send(.recentPhotosLoaded(await chatAttachmentLibraryClient.loadRecentPhotos(20)))
                }

            case let .recentPhotosLoaded(photos):
                state.recentPhotos = photos
                state.isLoadingRecentPhotos = false
                return .none

            case .addFilesTapped:
                state.isAttachmentPickerPresented = false
                state.isFileImporterPresented = true
                return .none

            case .allPhotosTapped:
                state.isAttachmentPickerPresented = false
                state.isPhotosPickerPresented = true
                return .none

            case .cameraTapped:
                state.isAttachmentPickerPresented = false
                state.isCameraPickerPresented = true
                return .none

            case let .recentPhotoTapped(photoID):
                if state.selectedRecentPhotoIDs.contains(photoID) {
                    state.selectedRecentPhotoIDs.removeAll { $0 == photoID }
                    return .send(.delegate(.recentPhotoDeselected(photoID)))
                } else {
                    state.selectedRecentPhotoIDs.append(photoID)
                    return .send(.delegate(.recentPhotoSelected(photoID)))
                }

            case .attachmentImportStarted:
                state.isImportingAttachments = true
                return .none

            case .attachmentImportFinished:
                state.isImportingAttachments = false
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
