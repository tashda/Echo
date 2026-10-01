import SwiftUI

extension SQLEditorPalette {
    /// Round 28.11 (TH1): only Aurora (light) and Midnight (dark) until themes come back; a saved
    /// palette that is gone falls back to these.
    static let builtIn: [SQLEditorPalette] = [
        aurora,
        midnight
    ]

    /// The palettes removed in round 28.11; settings that named one fall back to Aurora or Midnight.
    static let removedIDs: Set<String> = [
        "echo-light", "solstice", "github-light", "catppuccin-latte", "ember-light", "sea-breeze", "orchard", "paperwhite",
        "echo-dark", "one-dark", "dracula", "nebula-night", "ember-dark", "charcoal", "catppuccin-mocha", "solarized-dark",
        "violet-storm", "nord",
    ]

    static func palette(withID id: String) -> SQLEditorPalette? {
        builtIn.first { $0.id == id }
    }
}
