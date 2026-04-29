import SentinelUI
import SentinelCore
import ComposableArchitecture
import CoreGraphics

extension AppFeature {
    @ObservableState
    struct State: Equatable {
        var auth = AuthState()
        var home = HomeState()
        var chatSheet = ChatSheetState.initial
        var profile = ProfileFeature.State()
        var rebalance = RebalanceFeature.State(accessToken: "")
        var isAuthFlowPresented = false
        var isChatSheetPresented = false
        var isProfileSheetPresented = false
        var isRebalanceSheetPresented = false
        var wasChatSheetPresentedBeforeProfile = false
        var wasChatSheetPresentedBeforeRebalance = false

        func chatSheetInsetHeight(containerHeight: CGFloat) -> CGFloat {
            guard isChatSheetPresented else { return 0 }

            switch chatSheet.detent {
            case .collapsed:
                return AppGrid.value(24)
            case .medium:
                return max(containerHeight * 0.56, 420)
            case .large:
                return containerHeight * 0.82
            }
        }
    }

    @CasePathable
    enum Action: Equatable {
        case chatSheetDismissed
        case auth(AuthAction)
        case authFlowDismissed
        case authFlowPresentationChanged(Bool)
        case chatSheetPresentationChanged(Bool)
        case home(HomeAction)
        case profile(ProfileFeature.Action)
        case profileSheetDismissed
        case profileSheetPresentationChanged(Bool)
        case rebalance(RebalanceFeature.Action)
        case rebalanceSheetDismissed
        case rebalanceSheetPresentationChanged(Bool)
        case task
        case chatSheet(ChatSheetAction)
    }
}
