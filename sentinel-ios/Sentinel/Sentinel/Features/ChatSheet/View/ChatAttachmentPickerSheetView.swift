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

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    Button(action: onAllPhotosTap) {
                        Text(L10n.ChatSheet.allPhotos)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.blue)
                            )
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        Text(L10n.ChatSheet.recentPhotos)
                            .font(.headline)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppSpacing.medium) {
                                cameraTile

                                ForEach(recentPhotos) { photo in
                                    Button {
                                        onRecentPhotoTap(photo)
                                    } label: {
                                        recentPhotoTile(photo)
                                    }
                                    .buttonStyle(.plain)
                                }

                                if isLoadingRecentPhotos {
                                    ProgressView()
                                        .frame(width: 78, height: 78)
                                }
                            }
                        }
                    }

                    Button(action: onAddFilesTap) {
                        HStack(spacing: AppSpacing.medium) {
                            Image(systemName: "folder")
                                .font(.body.weight(.semibold))
                                .frame(width: 28)

                            Text(L10n.ChatSheet.addFiles)
                                .font(.body)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, AppSpacing.large)
                        .padding(.vertical, AppSpacing.medium)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(AppPlatformColor.secondaryGroupedBackground)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppSpacing.large)
                .padding(.vertical, AppSpacing.xLarge)
            }
            .background(HomeTopGradientBackground().ignoresSafeArea())
            .navigationTitle(L10n.ChatSheet.attachmentSourceTitle)
            .sentinelInlineNavigationTitle()
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }

    private var cameraTile: some View {
        Button(action: onCameraTap) {
            VStack(spacing: AppSpacing.small) {
                Image(systemName: "camera.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(canOpenCamera ? .primary : .secondary)

                Text(L10n.ChatSheet.cameraOption)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 78, height: 78)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppPlatformColor.secondaryGroupedBackground)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canOpenCamera)
        .opacity(canOpenCamera ? 1 : AppOpacity.disabled)
    }

    @ViewBuilder
    private func recentPhotoTile(_ photo: RecentLibraryPhoto) -> some View {
        #if canImport(UIKit)
        Image(uiImage: photo.thumbnail)
            .resizable()
            .scaledToFill()
            .frame(width: 78, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        #elseif canImport(AppKit)
        Image(nsImage: photo.thumbnail)
            .resizable()
            .scaledToFill()
            .frame(width: 78, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        #else
        Color.clear
            .frame(width: 78, height: 78)
        #endif
    }
}
