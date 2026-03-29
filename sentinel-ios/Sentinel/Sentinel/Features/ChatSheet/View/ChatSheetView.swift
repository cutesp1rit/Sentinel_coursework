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
                    ChatSheetTranscriptView(
                        detent: store.detent,
                        messages: store.messages,
                        bottomAnchorID: ScrollAnchor.bottom,
                        onToggleSuggestionExpansion: toggleSuggestionExpansion,
                        onToggleSuggestionSelection: toggleSuggestionSelection,
                        onAddSelectedSuggestions: addSelectedSuggestions
                    )
                    .opacity(transcriptOpacity)
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
            .onAppear {
                transcriptOpacity = store.detent == .collapsed ? 0 : 1
                if store.detent != .collapsed {
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

                    if oldValue == .collapsed {
                        scrollTranscriptToBottom(scrollProxy, retryAfter: detentSettleDelay)
                    }
                }
            }
            .onChange(of: store.messages.count) { _, _ in
                scrollTranscriptToBottom(scrollProxy)
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

    private var composerDock: some View {
        ChatSheetComposerView(
            draft: draftBinding,
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

    private func scrollTranscriptToBottom(
        _ proxy: ScrollViewProxy,
        retryAfter delay: TimeInterval? = nil
    ) {
        DispatchQueue.main.async {
            withAnimation(.none) {
                proxy.scrollTo(ScrollAnchor.bottom, anchor: .bottom)
            }
        }

        guard let delay else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.none) {
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
