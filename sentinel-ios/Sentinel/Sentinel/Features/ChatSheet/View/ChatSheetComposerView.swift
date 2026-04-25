import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ChatSheetComposerView: View {
    @Binding var draft: String

    let attachments: [ChatSheetState.ComposerAttachment]
    let isComposerEnabled: Bool
    let isSendEnabled: Bool
    let composerFocus: FocusState<Bool>.Binding
    let onAttachmentTap: () -> Void
    let onRemoveAttachment: (ChatSheetState.ComposerAttachment.ID) -> Void
    let onComposerTap: () -> Void
    let onSendTap: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                if !attachments.isEmpty {
                    attachmentStrip
                }

                HStack(alignment: .center, spacing: 10) {
                    Button(action: onAttachmentTap) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(.primary)
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .accessibilityLabel(L10n.ChatSheet.addAttachmentAccessibility)
                    .disabled(!isComposerEnabled)
                    .opacity(isComposerEnabled ? 1 : AppOpacity.disabled)

                    HStack(alignment: .center, spacing: 8) {
                        TextField(L10n.ChatSheet.composerPlaceholder, text: $draft, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(1 ... 5)
                            .font(.callout)
                            .frame(minHeight: 20)
                            .focused(composerFocus)
                            .onTapGesture(perform: onComposerTap)
                            .disabled(!isComposerEnabled)

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
                        .allowsHitTesting(isSendEnabled && isComposerEnabled)
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                    .glassEffect(
                        .regular.interactive(),
                        in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    )
                }
            }
        }
    }

    private var attachmentStrip: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(L10n.ChatSheet.selectedImages)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.medium) {
                    ForEach(attachments) { attachment in
                        ComposerAttachmentPreview(
                            attachment: attachment,
                            onRemove: { onRemoveAttachment(attachment.id) }
                        )
                    }
                }
            }
        }
    }
}

private struct ComposerAttachmentPreview: View {
    let attachment: ChatSheetState.ComposerAttachment
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            attachmentImage
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.white, .black.opacity(0.75))
                    .padding(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.ChatSheet.removeAttachmentAccessibility)
        }
    }

    @ViewBuilder
    private var attachmentImage: some View {
        if let image = PlatformImage(data: attachment.data) {
            platformImageView(image)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(AppPlatformColor.tertiaryGroupedBackground)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
        }
    }
}

#if canImport(UIKit)
private typealias PlatformImage = UIImage

private func platformImageView(_ image: UIImage) -> Image {
    Image(uiImage: image)
}
#elseif canImport(AppKit)
private typealias PlatformImage = NSImage

private func platformImageView(_ image: NSImage) -> Image {
    Image(nsImage: image)
}
#endif
