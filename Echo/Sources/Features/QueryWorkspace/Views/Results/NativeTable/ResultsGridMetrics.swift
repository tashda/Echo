import Foundation

enum ResultsGridMetrics {
    static let contentHorizontalPadding: CGFloat = SpacingTokens.xs2
    /// The row numbers' side padding (round 47: 8pt, as the editor's gutter).
    static let rowNumberLeadingPadding: CGFloat = SpacingTokens.xs
    static let rowNumberTrailingPadding: CGFloat = SpacingTokens.xs
    static let rowNumberFontSize: CGFloat = SpacingTokens.sm
    static let cellFontSize: CGFloat = SpacingTokens.sm
    /// The gutter fits the digits, at least three, and grows (round 47, GW1).
    static let minimumRowNumberDigits = 3
    static let maxAutoWidthSampleCount = 200
    /// Empty room after the last column, so its right edge can be grabbed and the soft edge never covers it.
    static let trailingColumnRoom: CGFloat = SpacingTokens.xl + SpacingTokens.sm
    static let minimumColumnWidth: CGFloat = 56
    static let maximumColumnWidth: CGFloat = 420
    /// Two lines: the column name over its data type (plan R2).
    static let headerHeight: CGFloat = 36
    /// The box the sort arrow sits in at a header's trailing edge, and the arrow's size.
    static let sortIndicatorSize: CGFloat = 14
    static let sortIndicatorPointSize: CGFloat = 9
    /// Extra room around the sort arrow that still counts as clicking it.
    static let sortIndicatorHitSlop: CGFloat = 4
    /// The one shape of a row's tint: the shaded rows (drawn by Echo since round 47, the system's
    /// were inset further than the hover), the hover (plan R4) and the gutter's. Inset from the
    /// row's edges, with rounded corners.
    static let hoverHorizontalInset: CGFloat = SpacingTokens.xs
    static let hoverVerticalInset: CGFloat = 1
    static let hoverCornerRadius: CGFloat = 6
    /// The gutter's tint is inset from the gutter's sides by this (round 47).
    static let gutterTintInset: CGFloat = SpacingTokens.xxs
    /// A selected range's rounded ends, in the grid and in the gutter.
    static let selectionCornerRadius: CGFloat = 6
    static let selectionEndInset: CGFloat = 2
    /// The stronger ring on the active cell of a selection (plan R3).
    static let activeCellRingWidth: CGFloat = 2
    static let activeCellCornerRadius: CGFloat = 4
}
