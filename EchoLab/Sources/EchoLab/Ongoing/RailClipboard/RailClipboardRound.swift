import SwiftUI

/// Round 39.5 · Rail tools: Clipboard. Echo today (ClipboardHistoryView, ClipboardHistoryStore):
/// Echo keeps its own list of what you copied (cells, rows, queries) with a filter, a setting to
/// turn it off, and a popover per entry. macOS 26 keeps a clipboard history for every app in
/// Spotlight (⌘Space, then ⌘4), with its own retention and privacy settings.
@MainActor
enum RailClipboardRound {
    enum Fate: String, CaseIterable {
        case keep = "CB0 · Keep Echo's history as it is"
        case drop = "CB1 · Drop it; the system's clipboard history covers it"
        case recent = "CB2 · Drop the panel, keep Paste Recent in the editor's and grid's menus"

        var summary: String {
            switch self {
            case .keep: "A second history, only for Echo, with its own setting."
            case .drop: "Less to learn and secure; copies are still in Spotlight's history for 8 hours by default."
            case .recent: "The last five things copied in Echo, offered where you'd paste them, with no panel or setting."
            }
        }
    }

    static let spec = RoundSpec(
        controls: [],
        exhibits: [
            .init(id: "drop", title: "Removed · Clipboard", summary: "CB1 / BP0. No Echo clipboard capture, settings, export option or rail pill. Regular Copy and Paste continue through the system clipboard.", isEchoToday: true, isWide: true, designWidth: 860, designHeight: 520) { _ in
                RailToolsAcceptedScene()
            },
        ], questions: []
    )

}
