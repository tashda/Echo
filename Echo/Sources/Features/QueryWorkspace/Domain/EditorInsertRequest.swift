import Foundation

/// Text to put at the editor's caret, replacing any selection (round IC: Insert from a bookmark
/// or a history row, ⌥-click, ⌥Return). Each request is new, so the same text can go in twice.
struct EditorInsertRequest: Equatable {
    let text: String
    let id = UUID()
}
