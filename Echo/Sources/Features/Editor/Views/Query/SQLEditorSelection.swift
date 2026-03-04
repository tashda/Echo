import Foundation

struct SQLEditorSelection: Equatable {
    let selectedText: String
    let range: NSRange
    let lineRange: ClosedRange<Int>?

    var hasSelection: Bool { !selectedText.isEmpty }
}
