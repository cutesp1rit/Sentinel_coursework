import SwiftUI

struct ChatSheetComposerView: View {
    @Binding var draft: String

    let composerFocus: FocusState<Bool>.Binding
    let onAttachmentTap: () -> Void
    let onComposerTap: () -> Void
    let onSendTap: () -> Void

    private var isSendEnabled: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(alignment: .bottom, spacing: 10) {
                Button(action: onAttachmentTap) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(.primary)
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
                .accessibilityLabel(L10n.ChatSheet.addAttachmentAccessibility)

                HStack(spacing: 8) {
                    TextField(L10n.ChatSheet.composerPlaceholder, text: $draft, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1 ... 5)
                        .font(.callout)
                        .frame(minHeight: 20)
                        .focused(composerFocus)
                        .onTapGesture(perform: onComposerTap)

                    Button(action: onSendTap) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(isSendEnabled ? 1 : 0))
                            .frame(width: 38, height: 30)
                            .background {
                                Capsule()
                                    .fill(isSendEnabled ? Color.blue : Color.clear)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.ChatSheet.sendMessageAccessibility)
                    .allowsHitTesting(isSendEnabled)
                }
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                .glassEffect(.regular.interactive(), in: Capsule())
            }
        }
    }
}
