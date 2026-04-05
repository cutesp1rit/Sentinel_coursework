import SwiftUI

extension ChatSheetState.Detent {
    init(_ presentationDetent: PresentationDetent) {
        if presentationDetent == .chatCollapsed {
            self = .collapsed
        } else if presentationDetent == .chatMedium {
            self = .medium
        } else {
            self = .large
        }
    }

    var presentationDetent: PresentationDetent {
        switch self {
        case .collapsed:
            return .chatCollapsed
        case .medium:
            return .chatMedium
        case .large:
            return .large
        }
    }
}

extension PresentationDetent {
    static let chatCollapsed = PresentationDetent.height(AppGrid.value(18))
    static let chatMedium = PresentationDetent.fraction(0.5)
}
