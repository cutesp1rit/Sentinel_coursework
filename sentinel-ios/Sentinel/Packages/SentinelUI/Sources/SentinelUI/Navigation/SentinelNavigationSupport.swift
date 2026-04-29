import SwiftUI

#if os(iOS)
public nonisolated(unsafe) let sentinelToolbarLeadingPlacement = ToolbarItemPlacement.topBarLeading
public nonisolated(unsafe) let sentinelToolbarTrailingPlacement = ToolbarItemPlacement.topBarTrailing
#else
public nonisolated(unsafe) let sentinelToolbarLeadingPlacement = ToolbarItemPlacement.automatic
public nonisolated(unsafe) let sentinelToolbarTrailingPlacement = ToolbarItemPlacement.automatic
#endif

public extension View {
    @ViewBuilder
    func sentinelInlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func sentinelLargeNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.large)
        #else
        self
        #endif
    }

    @ViewBuilder
    func sentinelHiddenNavigationBar() -> some View {
        #if os(iOS)
        self.navigationBarHidden(true)
        #else
        self
        #endif
    }

    @ViewBuilder
    func sentinelNavigationBarToolbarVisibility(_ visibility: Visibility) -> some View {
        #if os(iOS)
        self.toolbar(visibility, for: .navigationBar)
        #else
        self
        #endif
    }

    @ViewBuilder
    func sentinelNavigationBarMaterialBackground() -> some View {
        #if os(iOS)
        self
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        #else
        self
        #endif
    }
}
