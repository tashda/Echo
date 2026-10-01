import SwiftUI

extension View {
    /// Room for a card's floating footer under a SwiftUI scroll view (a table, a list), and its
    /// scroll bars just above the footer's pills (round 27, as `FooterScrollOverlay` does for
    /// AppKit views).
    ///
    /// SwiftUI places the bars at the indicators' margin less the content's margin, where AppKit
    /// adds its two insets (measured 2026-10-01); with only a content margin, the bars sat below
    /// the visible area.
    func footerScrollRoom(_ footerHeight: CGFloat) -> some View {
        contentMargins(.bottom, footerHeight, for: .scrollContent)
            .contentMargins(.bottom, FooterScrollRoomMetrics.indicatorMargin(overFooter: footerHeight), for: .scrollIndicators)
    }
}

enum FooterScrollRoomMetrics {
    /// The indicators' margin that puts a SwiftUI scroll bar's thumb where an AppKit one goes.
    nonisolated static func indicatorMargin(overFooter footerHeight: CGFloat) -> CGFloat {
        footerHeight > 0 ? LayoutTokens.Footer.scrollerInset(overFooter: footerHeight) + footerHeight * 2 : 0
    }
}
