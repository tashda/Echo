import Foundation

enum ResultsGridMetrics {
    static let contentHorizontalPadding: CGFloat = SpacingTokens.xs2
    static let rowNumberLeadingPadding: CGFloat = SpacingTokens.xxxs
    static let rowNumberTrailingPadding: CGFloat = SpacingTokens.xxs1
    static let rowNumberFontSize: CGFloat = SpacingTokens.sm
    static let cellFontSize: CGFloat = SpacingTokens.sm
    static let minimumRowNumberDigits = 6
    static let maxAutoWidthSampleCount = 200
    static let minimumColumnWidth: CGFloat = 56
    static let maximumColumnWidth: CGFloat = 420
    /// Two lines: the column name over its data type (plan R2).
    static let headerHeight: CGFloat = 36
    /// The box the sort arrow sits in at a header's trailing edge, and the arrow's size.
    static let sortIndicatorSize: CGFloat = 14
    static let sortIndicatorPointSize: CGFloat = 9
    /// Extra room around the sort arrow that still counts as clicking it.
    static let sortIndicatorHitSlop: CGFloat = 4
    /// Row hover (plan R4): a faint rounded tint inset from the row's edges.
    static let hoverHorizontalInset: CGFloat = 2
    static let hoverVerticalInset: CGFloat = 1
    static let hoverCornerRadius: CGFloat = 5
    /// The stronger ring on the active cell of a selection (plan R3).
    static let activeCellRingWidth: CGFloat = 2
    static let activeCellCornerRadius: CGFloat = 4
}
