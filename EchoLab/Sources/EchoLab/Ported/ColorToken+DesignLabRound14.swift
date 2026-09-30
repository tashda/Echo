import AppKit
import SwiftUI

extension ColorTokens {
    /// Colours for the round 14 Design Lab proposals. Every value follows light, dark and
    /// Increase Contrast. Proposals only; nothing in Echo reads them yet.
    enum DesignLabRound14 {
        /// N1R: the recessed track, a step darker than the canvas.
        static let sunkWell = Color.adaptive(
            light: NSColor(white: 0.875, alpha: 1), dark: NSColor(white: 0.115, alpha: 1),
            highContrastLight: NSColor(white: 0.80, alpha: 1), highContrastDark: NSColor(white: 0.06, alpha: 1)
        )
        /// N1R: the active tab, lifted a step lighter than the canvas but never white.
        static let sunkLift = Color.adaptive(
            light: NSColor(white: 0.955, alpha: 1), dark: NSColor(white: 0.29, alpha: 1),
            highContrastLight: NSColor(white: 0.985, alpha: 1), highContrastDark: NSColor(white: 0.38, alpha: 1)
        )
        /// N1R: the soft shadow inside the track.
        static let sunkInnerShadow = Color.black.opacity(0.09)
        /// N1R, N7: hairlines between inactive tabs.
        static let tabDivider = Color(nsColor: .separatorColor)
        /// N7: the faint track behind the ink tab.
        static let inkTrack = Color.primary.opacity(0.055)
        /// N7: the active tab, filled in the text colour.
        static let inkFill = Color(nsColor: .labelColor)
        /// N7: the active tab's title, reversed out of the ink.
        static let inkTitle = Color(nsColor: .textBackgroundColor)
        /// Inactive tab hover.
        static let tabHover = Color.primary.opacity(0.06)
        /// The drawer's page chips.
        static let pageChip = Color.primary.opacity(0.05)
        /// The lift under raised shapes.
        static let liftShadow = Color.black.opacity(0.14)
        /// Tool group label (ST3).
        static let groupLabelTitle = Color.white
        /// EchoSense rows: a tint while typing, the accent once choosing.
        static let senseTint = Color.accentColor.opacity(0.16)
        static let senseSolid = Color.accentColor
        static let senseSolidTitle = Color(nsColor: .alternateSelectedControlTextColor)
        static let senseFooter = Color.primary.opacity(0.035)
        static let senseAlias = Color.primary.opacity(0.07)
    }
}
