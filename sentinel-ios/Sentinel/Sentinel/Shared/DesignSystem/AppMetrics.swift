import SwiftUI

enum AppGrid {
    static let unit: CGFloat = 4

    static func value(_ multiplier: Int) -> CGFloat {
        CGFloat(multiplier) * unit
    }
}

enum AppSpacing {
    static let xSmall = AppGrid.value(1)
    static let small = AppGrid.value(2)
    static let medium = AppGrid.value(3)
    static let large = AppGrid.value(4)
    static let xLarge = AppGrid.value(6)
}

enum AppSizing {
    static let hairline: CGFloat = 1
    static let minimumHitTarget = AppGrid.value(11)
}

enum AppRadius {
    static let medium = AppGrid.value(5)
    static let large = AppGrid.value(6)
}

enum AppOpacity {
    static let disabled: CGFloat = 0.4
    static let overlay: CGFloat = 0.16
    static let secondaryBorder: CGFloat = 0.24
    static let selection: CGFloat = 0.8
}

enum AppAnimationDuration {
    static let fast: TimeInterval = 0.16
    static let quick: TimeInterval = 0.2
    static let standard: TimeInterval = 0.24
    static let settle: TimeInterval = 0.32
}

enum AppStrokeWidth {
    static let standard: CGFloat = 1
    static let emphasis: CGFloat = 2
}
