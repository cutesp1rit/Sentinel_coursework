import SwiftUI
import SentinelCore

#if os(iOS)
let sentinelToolbarLeadingPlacement = ToolbarItemPlacement.topBarLeading
let sentinelToolbarTrailingPlacement = ToolbarItemPlacement.topBarTrailing
#else
let sentinelToolbarLeadingPlacement = ToolbarItemPlacement.automatic
let sentinelToolbarTrailingPlacement = ToolbarItemPlacement.automatic
#endif

extension View {
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
