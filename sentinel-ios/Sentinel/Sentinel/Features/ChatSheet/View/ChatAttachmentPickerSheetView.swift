import SentinelUI
import SentinelPlatformiOS
import SentinelCore
import SwiftUI
import UIKit

struct ChatAttachmentPickerSheetView: View {
    let canOpenCamera: Bool
    let isLoadingRecentPhotos: Bool
    let recentPhotos: [RecentLibraryPhoto]
    let selectedRecentPhotoIDs: [RecentLibraryPhoto.ID]
    let onAddFilesTap: () -> Void
    let onAllPhotosTap: () -> Void
    let onCameraTap: () -> Void
    let onRecentPhotoTap: (RecentLibraryPhoto) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.App.title)
                        .font(.headline.weight(.semibold))

                    Spacer()

                    Button(L10n.ChatSheet.allPhotos, action: onAllPhotosTap)
                        .buttonStyle(.plain)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.blue)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.medium) {
                        if canOpenCamera {
                            cameraTile
                        }

                        ForEach(recentPhotos) { photo in
                            Button {
                                onRecentPhotoTap(photo)
                            } label: {
                                recentPhotoTile(
                                    photo,
                                    selectionIndex: selectedRecentPhotoIDs.firstIndex(of: photo.id).map { $0 + 1 }
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if isLoadingRecentPhotos {
                            ProgressView()
                                .frame(width: 72, height: 72)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollClipDisabled()

                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 1)

                Button(action: onAddFilesTap) {
                    HStack(spacing: AppSpacing.medium) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 22, weight: .semibold))
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                            Text(L10n.ChatSheet.addFiles)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text(L10n.ChatSheet.addFilesSubtitle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, AppSpacing.large)
                    .frame(minHeight: 72)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.xLarge)
            .padding(.horizontal, AppSpacing.medium)
            .padding(.top, AppSpacing.small)
        }
        .background(Color.clear)
        .presentationBackground(.clear)
        .presentationDetents([.height(388)])
        .presentationDragIndicator(.visible)
    }

    private var cameraTile: some View {
        Button(action: onCameraTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppPlatformColor.secondaryGroupedBackground)

                Image(systemName: "camera.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(canOpenCamera ? .primary : .secondary)
            }
            .frame(width: 72, height: 72)
        }
        .buttonStyle(.plain)
        .disabled(!canOpenCamera)
        .opacity(canOpenCamera ? 1 : AppOpacity.disabled)
    }

    @ViewBuilder
    private func recentPhotoTile(_ photo: RecentLibraryPhoto, selectionIndex: Int?) -> some View {
        ZStack(alignment: .topTrailing) {
            if let image = UIImage(data: photo.thumbnailData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(selectionIndex == nil ? Color.clear : Color.blue, lineWidth: 4)
                    }
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppPlatformColor.secondaryGroupedBackground)
                    .frame(width: 72, height: 72)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(selectionIndex == nil ? Color.clear : Color.blue, lineWidth: 4)
                    }
                }

            selectionBadge(selectionIndex: selectionIndex)
                .padding(6)
        }
    }

    @ViewBuilder
    private func selectionBadge(selectionIndex: Int?) -> some View {
        if let selectionIndex {
            Text(selectionIndex.formatted())
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial, in: Circle())
        } else {
            Circle()
                .stroke(Color.primary.opacity(0.8), lineWidth: 2.5)
                .frame(width: 24, height: 24)
                .background(.ultraThinMaterial.opacity(0.45), in: Circle())
        }
    }
}
