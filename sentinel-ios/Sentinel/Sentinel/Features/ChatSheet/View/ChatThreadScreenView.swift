import ComposableArchitecture
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ChatThreadScreenView: View {
    private enum ScrollAnchor {
        static let bottom = "chat-bottom"
    }

    let activeChatTitle: String
    let detent: ChatSheetState.Detent
    let onDetentChanged: (ChatSheetState.Detent) -> Void
    let onOpenChatList: () -> Void
    let store: StoreOf<ChatThreadFeature>

    @AppStorage("chat.attachments.processingConsentAccepted") private var hasAttachmentProcessingConsent = false
    @FocusState private var isComposerFocused: Bool
    @State private var isAttachmentConsentAlertPresented = false
    @State private var isAttachmentPickerPresented = false
    @State private var isCameraPickerPresented = false
    @State private var isFileImporterPresented = false
    @State private var isLoadingRecentLibraryPhotos = false
    @State private var recentLibraryPhotos: [RecentLibraryPhoto] = []
    @State private var isPhotosPickerPresented = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isImportingAttachments = false
    @State private var transcriptOpacity: CGFloat = 1

    var body: some View {
        ScrollViewReader { scrollProxy in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: AppSpacing.medium) {
                        if store.hasMoreHistory && store.isSignedIn {
                            ChatHistoryPagingControlView(
                                isLoading: store.isLoadingMoreHistory,
                                onTap: { store.send(.loadMoreHistoryTapped) }
                            )
                        }

                        transcriptContent
                    }
                    .opacity(transcriptOpacity)
                    .padding(.bottom, AppSpacing.large)
                }
                .defaultScrollAnchor(.bottom)
                .defaultScrollAnchor(.bottom, for: .alignment)
                .scrollIndicators(.hidden)
                .scrollDisabled(detent == .collapsed)
                .scrollDismissesKeyboard(.interactively)
                .allowsHitTesting(detent != .collapsed)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composerDock
            }
            .presentationDetents([.chatCollapsed, .chatMedium, .large], selection: detentBinding)
            .presentationBackgroundInteraction(.enabled(upThrough: .chatMedium))
            .presentationContentInteraction(.scrolls)
            .presentationDragIndicator(.visible)
            .navigationBarBackButtonHidden(true)
            .sentinelInlineNavigationTitle()
            .sentinelNavigationBarToolbarVisibility(detent == .collapsed ? .hidden : .visible)
            .toolbar {
                ToolbarItem(placement: sentinelToolbarLeadingPlacement) {
                    Button(action: onOpenChatList) {
                        Image(systemName: "line.3.horizontal")
                            .font(.body.weight(.semibold))
                    }
                    .disabled(!store.isSignedIn)
                    .opacity(store.isSignedIn ? 1 : AppOpacity.disabled)
                }

                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text(L10n.ChatSheet.chatTitle)
                            .font(.headline.weight(.semibold))
                        Text(activeChatTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .photosPicker(
                isPresented: $isPhotosPickerPresented,
                selection: $selectedPhotoItems,
                maxSelectionCount: max(1, ChatThreadFeature.Constants.attachmentLimit - store.composerAttachments.count),
                matching: .images
            )
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.image],
                allowsMultipleSelection: true
            ) { result in
                importSelectedFiles(result)
            }
            #if os(iOS)
            .sheet(isPresented: $isAttachmentPickerPresented) {
                ChatAttachmentPickerSheetView(
                    canOpenCamera: UIImagePickerController.isSourceTypeAvailable(.camera),
                    isLoadingRecentPhotos: isLoadingRecentLibraryPhotos,
                    recentPhotos: recentLibraryPhotos,
                    onAddFilesTap: {
                        isAttachmentPickerPresented = false
                        isFileImporterPresented = true
                    },
                    onAllPhotosTap: {
                        isAttachmentPickerPresented = false
                        isPhotosPickerPresented = true
                    },
                    onCameraTap: {
                        isAttachmentPickerPresented = false
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            isCameraPickerPresented = true
                        }
                    },
                    onRecentPhotoTap: { recentPhoto in
                        importRecentPhoto(recentPhoto)
                    }
                )
            }
            .sheet(isPresented: $isCameraPickerPresented) {
                CameraImagePicker { image in
                    importCapturedCameraImage(image)
                }
            }
            .alert(
                L10n.ChatSheet.attachmentConsentTitle,
                isPresented: $isAttachmentConsentAlertPresented
            ) {
                Button(L10n.ChatSheet.attachmentConsentConfirm) {
                    hasAttachmentProcessingConsent = true
                    isAttachmentPickerPresented = true
                    refreshRecentLibraryPhotos()
                }
                Button(L10n.Profile.cancelButton, role: .cancel) {}
            } message: {
                Text(L10n.ChatSheet.attachmentConsentBody)
            }
            #endif
            .onAppear {
                store.send(.onAppear)
                transcriptOpacity = detent == .collapsed ? 0 : 1
            }
            .background(AppPlatformColor.systemBackground)
            .onChange(of: detent) { _, newValue in
                withAnimation(.easeOut(duration: AppAnimationDuration.quick)) {
                    transcriptOpacity = newValue == .collapsed ? 0 : 1
                }
            }
            .onChange(of: store.messages.count) { _, _ in
                if store.shouldAutoScrollToBottom {
                    scrollToBottom(scrollProxy)
                    store.send(.autoScrollCompleted)
                }
            }
            .onChange(of: isComposerFocused) { _, focused in
                if focused {
                    store.send(.composerFocusChanged)
                    scrollToBottom(scrollProxy)
                }
            }
            .onChange(of: isPhotosPickerPresented) { _, isPresented in
                guard !isPresented else { return }
                importSelectedPhotoItemsIfNeeded()
            }
        }
    }

    private var detentBinding: Binding<PresentationDetent> {
        Binding(
            get: { detent.presentationDetent },
            set: { onDetentChanged(.init($0)) }
        )
    }

    private var draftBinding: Binding<String> {
        Binding(
            get: { store.draft },
            set: { store.send(.draftChanged($0)) }
        )
    }

    @ViewBuilder
    private var transcriptContent: some View {
        if !store.isSignedIn {
            EmptyStateCard(title: L10n.ChatSheet.authRequiredTitle, bodyText: L10n.ChatSheet.authRequiredBody)
        } else if store.isLoadingMessages && store.messages.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.xLarge)
        } else if let errorMessage = store.errorMessage, store.messages.isEmpty {
            VStack(spacing: AppSpacing.medium) {
                EmptyStateCard(title: L10n.ChatSheet.errorTitle, bodyText: errorMessage)
                PrimaryButton(L10n.ChatSheet.retry) {
                    store.send(.retryTapped)
                }
            }
        } else if store.messages.isEmpty {
            EmptyStateCard(
                title: L10n.ChatSheet.noMessagesTitle,
                bodyText: store.activeChatID == nil ? L10n.ChatSheet.noChatsBody : L10n.ChatSheet.noMessagesBody
            )
        } else {
            VStack(spacing: AppSpacing.medium) {
                if let errorMessage = store.errorMessage {
                    inlineErrorBanner(errorMessage)
                }

                ChatSheetTranscriptView(
                    detent: detent,
                    messages: store.messages,
                    onRemoveFailedMessage: { store.send(.failedMessageRemoveTapped($0)) },
                    onRetryFailedMessage: { store.send(.failedMessageRetryTapped($0)) },
                    onToggleSuggestionExpansion: { store.send(.toggleSuggestionExpansion($0)) },
                    onToggleSuggestionSelection: { store.send(.toggleSuggestionSelection(messageID: $0, suggestionID: $1)) },
                    onAddSelectedSuggestions: { store.send(.addSelectedSuggestionsTapped($0)) }
                )

                Color.clear
                    .frame(height: 1)
                    .id(ScrollAnchor.bottom)
            }
        }
    }

    private func inlineErrorBanner(_ message: String) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(L10n.ChatSheet.retry) {
                store.send(.retryTapped)
            }
            .buttonStyle(.plain)
            .font(.footnote.weight(.semibold))
        }
        .padding(AppSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.red.opacity(0.10))
        )
    }

    private var composerDock: some View {
        ChatSheetComposerView(
            draft: draftBinding,
            attachments: store.composerAttachments,
            isCollapsed: detent == .collapsed,
            isComposerEnabled: store.isSignedIn,
            isSendEnabled: store.isSignedIn && !store.isSending && store.hasComposerContent,
            composerFocus: $isComposerFocused,
            onAttachmentTap: {
                if detent == .collapsed {
                    onDetentChanged(.medium)
                }
                if store.isSignedIn {
                    if hasAttachmentProcessingConsent {
                        isAttachmentPickerPresented = true
                        refreshRecentLibraryPhotos()
                    } else {
                        isAttachmentConsentAlertPresented = true
                    }
                }
            },
            onRemoveAttachment: { store.send(.attachmentRemoved($0)) },
            onComposerTap: {
                if detent == .collapsed {
                    onDetentChanged(.medium)
                }
            },
            onSendTap: { store.send(.sendButtonTapped) }
        )
        .padding(.horizontal, detent == .collapsed ? 16 : 24)
        .padding(.bottom, detent == .collapsed ? 16 : -8)
    }
}

private extension ChatThreadScreenView {
    func importCapturedCameraImage(_ image: UIImage) {
        guard let attachment = makeComposerAttachment(from: image, index: store.composerAttachments.count) else { return }
        store.send(.attachmentsAdded([attachment]))
    }

    func importRecentPhoto(_ recentPhoto: RecentLibraryPhoto) {
        let index = store.composerAttachments.count
        isAttachmentPickerPresented = false
        Task {
            guard let attachment = await makeComposerAttachment(from: recentPhoto, index: index) else { return }
            await MainActor.run {
                store.send(.attachmentsAdded([attachment]))
            }
        }
    }

    func importSelectedPhotoItemsIfNeeded() {
        let items = selectedPhotoItems
        guard !isImportingAttachments, !items.isEmpty else { return }
        selectedPhotoItems = []
        isImportingAttachments = true
        Task {
            for (index, item) in items.enumerated() {
                if let attachment = await makeComposerAttachment(from: item, index: index) {
                    await MainActor.run {
                        _ = store.send(.attachmentsAdded([attachment]))
                    }
                }
            }

            await MainActor.run {
                isImportingAttachments = false
            }
        }
    }

    func importSelectedFiles(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result else { return }

        let attachments = urls.enumerated().compactMap { offset, url in
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            return makeComposerAttachment(from: url, index: store.composerAttachments.count + offset)
        }

        guard !attachments.isEmpty else { return }
        store.send(.attachmentsAdded(attachments))
    }

    func refreshRecentLibraryPhotos() {
        guard !isLoadingRecentLibraryPhotos else { return }

        isLoadingRecentLibraryPhotos = true
        Task {
            let photos = await loadRecentLibraryPhotos(limit: 20)
            await MainActor.run {
                recentLibraryPhotos = photos
                isLoadingRecentLibraryPhotos = false
            }
        }
    }
}

#if os(iOS)
private struct CameraImagePicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImagePicked: (UIImage) -> Void

        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }
    }
}
#endif
