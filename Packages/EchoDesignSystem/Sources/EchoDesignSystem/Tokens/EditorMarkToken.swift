import AppKit
import SwiftUI

/// Round 28.15: the editor's mark language. Everything drawn on the text (the word at the caret,
/// find matches, a mistake, what a replacement removes and adds, the selection's corners) reads
/// these values: one corner (Settings › Editor › Marks › Corners, round by default), two
/// strengths, colour by meaning and the letters' height. Floating pieces over the text are glass.
public enum EditorMarkTokens {
    /// What a mark means; each meaning has one colour everywhere in the editor.
    public enum Meaning: Sendable, CaseIterable {
        /// The same word as the one at the caret.
        case same
        /// A find match.
        case found
        /// A mistake, or what a replacement removes.
        case wrong
        /// What a replacement adds, or a run that went well.
        case added
        /// Where you are: the statement at the caret.
        case here

        public var nsColor: NSColor {
            switch self {
            case .same: .labelColor
            case .found: .findHighlightColor
            case .wrong: .systemRed
            case .added: .systemGreen
            case .here: .controlAccentColor
            }
        }

        public var color: Color { Color(nsColor: nsColor) }
    }

    /// Soft for “also here”, strong for “this one”.
    public enum Strength: Sendable {
        case soft
        case strong

        public var opacity: CGFloat { self == .soft ? EditorMarkTokens.softOpacity : EditorMarkTokens.strongOpacity }
    }

    public static let softOpacity: CGFloat = 0.10
    public static let strongOpacity: CGFloat = 0.22
    /// A mark is as high as the letters plus this above and below.
    public static let verticalPadding: CGFloat = SpacingTokens.micro
    /// And this much wider than the letters on each side.
    public static let sidePadding: CGFloat = SpacingTokens.xxxs
}
