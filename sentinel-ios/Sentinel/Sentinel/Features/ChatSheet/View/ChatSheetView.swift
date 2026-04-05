import ComposableArchitecture
import SwiftUI

struct ChatSheetView: View {
    private enum ScrollAnchor {
        static let bottom = "chat-bottom"
    }

    private let detentTransitionAnimation = Animation.snappy(duration: AppAnimationDuration.standard)
    private let detentSettleDelay = AppAnimationDuration.settle
    private let transcriptFadeOutAnimation = Animation.easeOut(duration: AppAnimationDuration.fast)
    private let transcriptFadeInAnimation = Animation.easeOut(duration: AppAnimationDuration.quick)

    let store: StoreOf<ChatSheetReducer>

    @FocusState private var isComposerFocused: Bool
    @State private var transcriptOpacity: CGFloat = 1

    private var isCollapsed: Bool {
        store.detent == .collapsed
    }

    var body: some View {
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
            .safeAreaInset(edge: .top, spacing: 0) {
                if !isCollapsed {
                    chatHeader
                }
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
            .onAppear {
                _ = store.send(.onAppear)
                transcriptOpacity = store.detent == .collapsed ? 0 : 1
                if store.detent == .large {
                    scrollTranscriptToBottom(scrollProxy, retryAfter: detentSettleDelay)
                }
            }
            .sheet(
                isPresented: chatListBinding
            ) {
                ChatHistoryPickerView(
                    chats: store.chatSummaries,
                    activeChatID: store.activeChatID,
                    onClose: { store.send(.chatListPresentationChanged(false)) },
                    onCreateNewChat: { store.send(.chatSelected(nil)) },
                    onSelectChat: { store.send(.chatSelected($0)) }
                )
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
                debugTrace(
                    "ChatSheetView.onChange(messages.count) -> count=\(store.messages.count), " +
                    "last=\(store.messages.last.map { "\($0.id)|\($0.role)|text:\($0.markdownText != nil)|structured:\($0.suggestionsPayload != nil)" } ?? "nil"), " +
                    "autoScroll=\(store.shouldAutoScrollToBottom)"
                )
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
            isComposerEnabled: store.isSignedIn,
            isSendEnabled: store.isSignedIn
                && !store.isSending
                && !store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            composerFocus: $isComposerFocused,
            onAttachmentTap: addAttachment,
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

    private var chatHeader: some View {
        HStack(spacing: AppSpacing.medium) {
            Button {
                store.send(.chatListButtonTapped)
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.body.weight(.semibold))
                    .frame(width: AppGrid.value(11), height: AppGrid.value(11))
                    .background(Color(uiColor: .secondarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.ChatSheet.historyButtonAccessibility)
            .disabled(!store.isSignedIn)
            .opacity(store.isSignedIn ? 1 : AppOpacity.disabled)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(store.activeChatTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(store.isSignedIn ? L10n.ChatSheet.historyTitle : L10n.ChatSheet.authRequiredTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.top, AppSpacing.small)
        .padding(.bottom, AppSpacing.medium)
        .background(.ultraThinMaterial)
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
    }

    private func expandComposerIfNeeded() {
        guard store.detent == .collapsed else { return }
        _ = store.send(.detentChanged(.medium), animation: detentTransitionAnimation)
    }

    private func sendMessage() {
        _ = store.send(.sendButtonTapped, animation: detentTransitionAnimation)
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
