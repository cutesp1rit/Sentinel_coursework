import SwiftUI

public enum AppGrid {
    public static let unit: CGFloat = 4

    public static func value(_ multiplier: Int) -> CGFloat {
        CGFloat(multiplier) * unit
    }
}

public enum AppSpacing {
    public static let xSmall = AppGrid.value(1)
    public static let small = AppGrid.value(2)
    public static let medium = AppGrid.value(3)
    public static let large = AppGrid.value(4)
    public static let xLarge = AppGrid.value(6)
}

public enum AppSizing {
    public static let hairline: CGFloat = 1
    public static let minimumHitTarget = AppGrid.value(11)
}

public enum AppRadius {
    public static let medium = AppGrid.value(5)
    public static let large = AppGrid.value(6)
}

public enum AppOpacity {
    public static let disabled: CGFloat = 0.4
    public static let overlay: CGFloat = 0.16
    public static let secondaryBorder: CGFloat = 0.24
    public static let selection: CGFloat = 0.8
}

public enum AppAnimationDuration {
    public static let fast: TimeInterval = 0.16
    public static let quick: TimeInterval = 0.2
    public static let standard: TimeInterval = 0.24
    public static let settle: TimeInterval = 0.32
}

public enum AppStrokeWidth {
    public static let standard: CGFloat = 1
    public static let emphasis: CGFloat = 2
}
