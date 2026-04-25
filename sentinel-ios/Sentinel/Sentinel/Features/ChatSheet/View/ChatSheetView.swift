import ComposableArchitecture
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ChatSheetView: View {
    private enum Route: Hashable {
        case chat
    }

    private enum ScrollAnchor {
        static let bottom = "chat-bottom"
    }

    private let detentTransitionAnimation = Animation.snappy(duration: AppAnimationDuration.standard)
    private let detentSettleDelay = AppAnimationDuration.settle
    private let transcriptFadeOutAnimation = Animation.easeOut(duration: AppAnimationDuration.fast)
    private let transcriptFadeInAnimation = Animation.easeOut(duration: AppAnimationDuration.quick)

    let store: StoreOf<ChatSheetReducer>

    @FocusState private var isComposerFocused: Bool
    @State private var isPhotosPickerPresented = false
    @State private var path: [Route] = [.chat]
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var transcriptOpacity: CGFloat = 1

    private var isCollapsed: Bool {
        store.detent == .collapsed
    }

    var body: some View {
        NavigationStack {
            NavigationStack(path: $path) {
                ChatHistoryPickerView(
                    chats: store.chatSummaries,
                    activeChatID: store.activeChatID,
                    onCreateNewChat: {
                        store.send(.chatSelected(nil))
                        if path.isEmpty {
                            path.append(.chat)
                        }
                    },
                    onDeleteChat: { chatID in
                        store.send(.chatDeleteRequested(chatID))
                    },
                    onSelectChat: { chatID in
                        store.send(.chatSelected(chatID))
                        if path.isEmpty {
                            path.append(.chat)
                        }
                    }
                )
                .navigationDestination(for: Route.self) { _ in
                    chatDetailScene
                }
                .onAppear {
                    _ = store.send(.onAppear)
                    syncPathWithPresentationState(animated: false)
                }
                .onChange(of: store.isChatListPresented) { _, _ in
                    syncPathWithPresentationState(animated: true)
                }
            }
        }
        .photosPicker(
            isPresented: $isPhotosPickerPresented,
            selection: $selectedPhotoItems,
            maxSelectionCount: max(1, remainingAttachmentSlots),
            matching: .images
        )
        .onChange(of: selectedPhotoItems.count) { _, _ in
            let newItems = selectedPhotoItems
            guard !newItems.isEmpty else { return }
            Task {
                let attachments = await makeComposerAttachments(from: newItems)
                if !attachments.isEmpty {
                    store.send(.attachmentsAdded(attachments), animation: detentTransitionAnimation)
                }
                selectedPhotoItems = []
            }
        }
    }

    private var detentBinding: Binding<PresentationDetent> {
        Binding(
            get: { store.detent.presentationDetent },
            set: { _ = store.send(.detentChanged(.init($0)), animation: detentTransitionAnimation) }
        )
    }

    private var draftBinding: Binding<String> {
        Binding(
            get: { store.draft },
            set: { _ = store.send(.draftChanged($0)) }
        )
    }

    private var chatListBinding: Binding<Bool> {
        Binding(
            get: { store.isChatListPresented },
            set: { _ = store.send(.chatListPresentationChanged($0)) }
        )
    }

    private var chatDetailScene: some View {
        ScrollViewReader { scrollProxy in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: AppSpacing.medium) {
                        if store.hasMoreHistory && store.isSignedIn {
                            historyPagingControl
                        }

                        transcriptContent
                    }
                    .opacity(transcriptOpacity)
                    .padding(.bottom, AppSpacing.large)
                }
                .defaultScrollAnchor(.bottom)
                .defaultScrollAnchor(.bottom, for: .alignment)
                .scrollIndicators(.hidden)
                .scrollDisabled(isCollapsed)
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
                .allowsHitTesting(!isCollapsed)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composerDock
            }
            .background(.clear)
            .presentationDetents(
                [.chatCollapsed, .chatMedium, .large],
                selection: detentBinding
            )
            .presentationBackgroundInteraction(.enabled(upThrough: .chatMedium))
            .presentationContentInteraction(.scrolls)
            .presentationDragIndicator(.visible)
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(store.detent == .collapsed ? .hidden : .visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.send(.chatListButtonTapped)
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.body.weight(.semibold))
                    }
                    .disabled(!store.isSignedIn)
                    .opacity(store.isSignedIn ? 1 : AppOpacity.disabled)
                }

                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Chat")
                            .font(.headline.weight(.semibold))

                        Text(store.activeChatTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.send(.chatSelected(nil))
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.body.weight(.semibold))
                    }
                    .disabled(!store.isSignedIn)
                    .opacity(store.isSignedIn ? 1 : AppOpacity.disabled)
                }
            }
            .onAppear {
                transcriptOpacity = store.detent == .collapsed ? 0 : 1
                if store.detent == .large {
                    scrollTranscriptToBottom(scrollProxy, retryAfter: detentSettleDelay)
                }
            }
            .onChange(of: store.detent) { oldValue, newValue in
                if newValue == .collapsed {
                    withAnimation(transcriptFadeOutAnimation) {
                        transcriptOpacity = 0
                    }
                } else {
                    withAnimation(transcriptFadeInAnimation) {
                        transcriptOpacity = 1
                    }

                    if oldValue == .collapsed && newValue == .large {
                        scrollTranscriptToBottom(scrollProxy, retryAfter: detentSettleDelay)
                    }
                }
            }
            .onChange(of: store.messages.count) { _, _ in
                if store.shouldAutoScrollToBottom {
                    scrollTranscriptToBottom(scrollProxy)
                    store.send(.autoScrollCompleted)
                }
            }
            .onChange(of: isComposerFocused) { _, focused in
                _ = store.send(.composerFocusChanged(focused), animation: detentTransitionAnimation)
                if focused {
                    scrollTranscriptToBottom(scrollProxy)
                }
            }
        }
    }

    @ViewBuilder
    private var transcriptContent: some View {
        if !store.isSignedIn {
            stateCard(
                title: L10n.ChatSheet.authRequiredTitle,
                body: L10n.ChatSheet.authRequiredBody
            )
        } else if store.isLoadingChats || (store.isLoadingMessages && store.messages.isEmpty) {
            loadingCard(title: store.isLoadingChats ? L10n.ChatSheet.loadingChats : L10n.ChatSheet.loadingMessages)
        } else if let errorMessage = store.errorMessage, store.messages.isEmpty {
            errorCard(message: errorMessage)
        } else if store.messages.isEmpty {
            stateCard(
                title: store.chatSummaries.isEmpty ? L10n.ChatSheet.noChatsTitle : L10n.ChatSheet.noMessagesTitle,
                body: store.chatSummaries.isEmpty ? L10n.ChatSheet.noChatsBody : L10n.ChatSheet.noMessagesBody
            )
        } else {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                if let errorMessage = store.errorMessage {
                    errorCard(message: errorMessage)
                }

                ChatSheetTranscriptView(
                    detent: store.detent,
                    messages: store.messages,
                    onToggleSuggestionExpansion: toggleSuggestionExpansion,
                    onToggleSuggestionSelection: toggleSuggestionSelection,
                    onAddSelectedSuggestions: addSelectedSuggestions
                )

                if store.isSending {
                    assistantThinkingRow
                        .padding(.horizontal, store.detent == .large ? 12 : 16)
                }

                Color.clear
                    .frame(height: AppSpacing.small)
                    .id(ScrollAnchor.bottom)
            }
        }
    }

    private var composerDock: some View {
        ChatSheetComposerView(
            draft: draftBinding,
            attachments: store.composerAttachments,
            isComposerEnabled: store.isSignedIn,
            isSendEnabled: store.isSignedIn
                && !store.isSending
                && (
                    !store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || !store.composerAttachments.isEmpty
                ),
            composerFocus: $isComposerFocused,
            onAttachmentTap: addAttachment,
            onRemoveAttachment: removeAttachment,
            onComposerTap: expandComposerIfNeeded,
            onSendTap: sendMessage
        )
        .padding(
            .horizontal,
            isCollapsed
                ? 16
                : 24
        )
        .padding(
            .bottom,
            isCollapsed
                ? 16
                : -8
        )
        .animation(detentTransitionAnimation, value: store.detent)
    }

    @ViewBuilder
    private var historyPagingControl: some View {
        if store.isLoadingMoreHistory {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.small)
        } else {
            Button(L10n.ChatSheet.loadEarlierMessages) {
                store.send(.loadMoreHistoryTapped)
            }
            .buttonStyle(.plain)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.top, AppSpacing.small)
        }
    }

    private func loadingCard(title: String) -> some View {
        VStack(spacing: AppSpacing.medium) {
            ProgressView()
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xLarge)
    }

    private func errorCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            stateCard(title: L10n.ChatSheet.errorTitle, body: message)

            Button(L10n.ChatSheet.retry) {
                store.send(.retryTapped)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, AppSpacing.large)
    }

    private func stateCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(title)
                .font(.body.weight(.semibold))

            Text(body)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.large)
        .background(
            Color(uiColor: .secondarySystemFill),
            in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
        )
        .padding(.horizontal, AppSpacing.large)
    }

    private var assistantThinkingRow: some View {
        HStack {
            ShimmeringThinkingText(text: L10n.ChatSheet.thinking)

            Spacer(minLength: AppSizing.minimumHitTarget)
        }
        .frame(maxWidth: .infinity)
    }

    private func scrollTranscriptToBottom(
        _ proxy: ScrollViewProxy,
        retryAfter delay: TimeInterval? = nil
    ) {
        DispatchQueue.main.async {
            withAnimation(.snappy(duration: AppAnimationDuration.standard)) {
                proxy.scrollTo(ScrollAnchor.bottom, anchor: .bottom)
            }
        }

        guard let delay else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.snappy(duration: AppAnimationDuration.standard)) {
                proxy.scrollTo(ScrollAnchor.bottom, anchor: .bottom)
            }
        }
    }

    private func toggleSuggestionExpansion(_ messageID: ChatSheetState.Message.ID) {
        withAnimation(.snappy(duration: AppAnimationDuration.standard)) {
            _ = store.send(.toggleSuggestionExpansion(messageID))
        }
    }

    private func toggleSuggestionSelection(
        _ messageID: ChatSheetState.Message.ID,
        _ suggestionID: ChatSheetState.Suggestion.ID
    ) {
        _ = store.send(.toggleSuggestionSelection(messageID: messageID, suggestionID: suggestionID))
    }

    private func addSelectedSuggestions(_ messageID: ChatSheetState.Message.ID) {
        _ = store.send(.addSelectedSuggestionsTapped(messageID))
    }

    private func addAttachment() {
        _ = store.send(.addAttachmentTapped, animation: detentTransitionAnimation)
        if store.isSignedIn && remainingAttachmentSlots > 0 {
            isPhotosPickerPresented = true
        }
    }

    private func removeAttachment(_ attachmentID: ChatSheetState.ComposerAttachment.ID) {
        store.send(.attachmentRemoved(attachmentID))
    }

    private func expandComposerIfNeeded() {
        guard store.detent == .collapsed else { return }
        _ = store.send(.detentChanged(.medium), animation: detentTransitionAnimation)
    }

    private func sendMessage() {
        _ = store.send(.sendButtonTapped, animation: detentTransitionAnimation)
    }

    private func syncPathWithPresentationState(animated: Bool) {
        let targetPath: [Route] = store.isChatListPresented ? [] : [.chat]
        guard targetPath != path else { return }

        if animated {
            withAnimation(.snappy(duration: AppAnimationDuration.standard)) {
                path = targetPath
            }
        } else {
            path = targetPath
        }
    }

    private var remainingAttachmentSlots: Int {
        max(0, 5 - store.composerAttachments.count)
    }

    private func makeComposerAttachments(
        from items: [PhotosPickerItem]
    ) async -> [ChatSheetState.ComposerAttachment] {
        var attachments: [ChatSheetState.ComposerAttachment] = []

        for (index, item) in items.enumerated() {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  !data.isEmpty else {
                continue
            }

            let contentType = item.supportedContentTypes.first ?? .png
            let fileExtension = contentType.preferredFilenameExtension ?? "jpg"
            let mimeType = contentType.preferredMIMEType ?? "image/jpeg"
            let filename = "photo-\(UUID().uuidString.prefix(8))-\(index + 1).\(fileExtension)"

            attachments.append(
                .init(
                    data: data,
                    filename: filename,
                    mimeType: mimeType
                )
            )
        }

        return attachments
    }
}

private struct ShimmeringThinkingText: View {
    let text: String

    @Environment(\.colorScheme) private var colorScheme
    @State private var shimmerOffset: CGFloat = -1

    private var baseColor: Color {
        colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.42)
    }

    private var highlightColor: Color {
        colorScheme == .dark ? .black.opacity(0.75) : .white.opacity(0.75)
    }

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(baseColor)
            .overlay {
                GeometryReader { geometry in
                    let width = geometry.size.width

                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: highlightColor.opacity(0.0), location: 0.12),
                            .init(color: highlightColor.opacity(0.28), location: 0.32),
                            .init(color: highlightColor.opacity(0.9), location: 0.5),
                            .init(color: highlightColor.opacity(0.28), location: 0.68),
                            .init(color: highlightColor.opacity(0.0), location: 0.88),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width, height: geometry.size.height)
                    .offset(x: width * shimmerOffset)
                    .blendMode(.screen)
                    .clipped()
                }
                .allowsHitTesting(false)
            }
        .fixedSize(horizontal: true, vertical: true)
        .onAppear {
            shimmerOffset = -1
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                shimmerOffset = 1
            }
        }
    }
}
