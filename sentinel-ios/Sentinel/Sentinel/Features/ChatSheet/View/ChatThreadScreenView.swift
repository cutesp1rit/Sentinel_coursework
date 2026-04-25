import ComposableArchitecture
import PhotosUI
import SwiftUI

struct ChatThreadScreenView: View {
    private enum ScrollAnchor {
        static let bottom = "chat-bottom"
    }

    let activeChatTitle: String
    let detent: ChatSheetState.Detent
    let onDetentChanged: (ChatSheetState.Detent) -> Void
    let onOpenChatList: () -> Void
    let store: StoreOf<ChatThreadFeature>

    @FocusState private var isComposerFocused: Bool
    @State private var isPhotosPickerPresented = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
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
            .toolbar(detent == .collapsed ? .hidden : .visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
                maxSelectionCount: max(1, 5 - store.composerAttachments.count),
                matching: .images
            )
            .onAppear {
                store.send(.onAppear)
                transcriptOpacity = detent == .collapsed ? 0 : 1
            }
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
            .onChange(of: selectedPhotoItems.count) { _, _ in
                let items = selectedPhotoItems
                guard !items.isEmpty else { return }
                Task {
                    let attachments = await makeComposerAttachments(from: items)
                    if !attachments.isEmpty {
                        store.send(.attachmentsAdded(attachments))
                    }
                    selectedPhotoItems = []
                }
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
            EmptyStateCard(title: L10n.ChatSheet.errorTitle, bodyText: errorMessage)
        } else if store.messages.isEmpty {
            EmptyStateCard(
                title: L10n.ChatSheet.noMessagesTitle,
                bodyText: store.activeChatID == nil ? L10n.ChatSheet.noChatsBody : L10n.ChatSheet.noMessagesBody
            )
        } else {
            VStack(spacing: AppSpacing.medium) {
                ChatSheetTranscriptView(
                    detent: detent,
                    messages: store.messages,
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

    private var composerDock: some View {
        ChatSheetComposerView(
            draft: draftBinding,
            attachments: store.composerAttachments,
            isCollapsed: detent == .collapsed,
            isComposerEnabled: store.isSignedIn,
            isSendEnabled: store.isSignedIn && !store.isSending && (!store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !store.composerAttachments.isEmpty),
            composerFocus: $isComposerFocused,
            onAttachmentTap: {
                if detent == .collapsed {
                    onDetentChanged(.medium)
                }
                if store.isSignedIn {
                    isPhotosPickerPresented = true
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
