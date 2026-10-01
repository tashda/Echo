import Foundation

/// Asks the editor to put the caret on a line and show it. A new request each time, so asking for
/// the same line twice works.
struct EditorLineRequest: Equatable {
    let line: Int
    /// Selects this text instead of putting the caret at the line start (the error's word, J1).
    var range: NSRange? = nil
    let id = UUID()
}
