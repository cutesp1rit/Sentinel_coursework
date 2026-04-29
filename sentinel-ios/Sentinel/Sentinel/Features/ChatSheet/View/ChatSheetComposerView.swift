import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ChatSheetComposerView: View {
    @Binding var draft: String

    let attachments: [ChatComposerAttachment]
    let isCollapsed: Bool
    let isComposerEnabled: Bool
    let isSendEnabled: Bool
    let composerFocus: FocusState<Bool>.Binding
    let onAttachmentTap: () -> Void
    let onRemoveAttachment: (ChatComposerAttachment.ID) -> Void
    let onComposerTap: () -> Void
    let onSendTap: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: AppSpacing.medium) {
            expandedComposer
        }
    }

    private var expandedComposer: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
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

            VStack(alignment: .leading, spacing: hasAttachmentStrip ? AppSpacing.small : 0) {
                if hasAttachmentStrip {
                    attachmentStrip
                }

                composerTextRow
            }
            .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
            .glassEffect(
                .regular.interactive(),
                in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
            )
        }
    }

    private var attachmentStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.small) {
                ForEach(attachments) { attachment in
                    ComposerAttachmentPreview(
                        attachment: attachment,
                        onRemove: { onRemoveAttachment(attachment.id) }
                    )
                }
            }
        }
        .contentMargins(.top, AppSpacing.medium, for: .scrollContent)
        .contentMargins(.horizontal, AppSpacing.medium, for: .scrollContent)
        .frame(maxWidth: .infinity, alignment: .leading)
        .scrollClipDisabled()
    }

    private var composerTextRow: some View {
        HStack(alignment: .center, spacing: AppSpacing.small) {
            TextField(L10n.ChatSheet.composerPlaceholder, text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1 ... 5)
                .font(.callout)
                .frame(minHeight: 20)
                .padding(.vertical, AppSpacing.small)
                .focused(composerFocus)
                .onTapGesture(perform: onComposerTap)
                .disabled(!isComposerEnabled)

            Button(action: onSendTap) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(isSendEnabled ? 1 : 0))
                    .frame(width: 34, height: 26)
                    .background {
                        Capsule()
                            .fill(isSendEnabled ? Color.blue : Color.clear)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.ChatSheet.sendMessageAccessibility)
            .allowsHitTesting(isSendEnabled && isComposerEnabled)
        }
        .padding(.horizontal, AppSpacing.medium)
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .center)
    }

    private var hasAttachmentStrip: Bool {
        !isCollapsed && !attachments.isEmpty
    }
}

private struct ComposerAttachmentPreview: View {
    let attachment: ChatComposerAttachment
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            attachmentImage
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white, .black.opacity(0.75))
                    .padding(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.ChatSheet.removeAttachmentAccessibility)
        }
    }

    @ViewBuilder
    private var attachmentImage: some View {
        let imageData = attachment.previewData ?? attachment.data
        if let image = PlatformImage(data: imageData) {
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
