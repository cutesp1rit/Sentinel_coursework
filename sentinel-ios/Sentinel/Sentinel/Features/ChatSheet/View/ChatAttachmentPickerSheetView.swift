import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ChatAttachmentPickerSheetView: View {
    let canOpenCamera: Bool
    let isLoadingRecentPhotos: Bool
    let recentPhotos: [RecentLibraryPhoto]
    let onAddFilesTap: () -> Void
    let onAllPhotosTap: () -> Void
    let onCameraTap: () -> Void
    let onRecentPhotoTap: (RecentLibraryPhoto) -> Void
    @State private var selectedRecentPhotoIDs: [RecentLibraryPhoto.ID] = []

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.App.title)
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Spacer()

                    Button(L10n.ChatSheet.allPhotos, action: onAllPhotosTap)
                        .buttonStyle(.plain)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.blue)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.medium) {
                        cameraTile

                        ForEach(recentPhotos) { photo in
                            Button {
                                guard !selectedRecentPhotoIDs.contains(photo.id) else { return }
                                selectedRecentPhotoIDs.append(photo.id)
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
                                .frame(width: 124, height: 124)
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
                            .font(.system(size: 28, weight: .semibold))
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
                    .frame(minHeight: 82)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.xLarge)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
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
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(canOpenCamera ? .primary : .secondary)
            }
            .frame(width: 124, height: 124)
        }
        .buttonStyle(.plain)
        .disabled(!canOpenCamera)
        .opacity(canOpenCamera ? 1 : AppOpacity.disabled)
    }

    @ViewBuilder
    private func recentPhotoTile(_ photo: RecentLibraryPhoto, selectionIndex: Int?) -> some View {
        #if canImport(UIKit)
        ZStack(alignment: .topTrailing) {
            Image(uiImage: photo.thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: 124, height: 124)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(selectionIndex == nil ? Color.clear : Color.blue, lineWidth: 4)
                }

            selectionBadge(selectionIndex: selectionIndex)
                .padding(10)
        }
        #elseif canImport(AppKit)
        Image(nsImage: photo.thumbnail)
            .resizable()
            .scaledToFill()
            .frame(width: 124, height: 124)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        #else
        Color.clear
            .frame(width: 124, height: 124)
        #endif
    }

    @ViewBuilder
    private func selectionBadge(selectionIndex: Int?) -> some View {
        if let selectionIndex {
            Text(selectionIndex.formatted())
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(Color.white, in: Circle())
        } else {
            Circle()
                .stroke(Color.white, lineWidth: 4)
                .frame(width: 32, height: 32)
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        }
    }
}
