#if os(macOS)
import AppKit

/// Round 28.10 (Y1, EC2): an empty editor shows a prompt where you type: on the first line, at
/// the caret, in the editor's font and the placeholder colour, gone with the first character.
/// The recent tables and snippets it used to offer (QE6) were dropped.
extension SQLTextView {
    static let emptyPrompt = "Start typing a query"

    func drawEmptyPrompt() {
        guard string.isEmpty, let textContainer else { return }
        let font = theme.nsFont
        let baseline = (layoutManager as? SQLLayoutManager)?.fixedBaselineOffset ?? font.ascender
        let origin = NSPoint(x: textContainerOrigin.x + textContainer.lineFragmentPadding,
                             y: textContainerOrigin.y + baseline - font.ascender)
        (Self.emptyPrompt as NSString).draw(at: origin, withAttributes: [.font: font, .foregroundColor: NSColor.placeholderTextColor])
    }

    /// The prompt appears and goes as the editor empties or fills (a paste included).
    func refreshEmptyPrompt() {
        guard string.isEmpty != showsEmptyPrompt else { return }
        showsEmptyPrompt = string.isEmpty
        setNeedsDisplay(visibleRect)
    }
}
#endif
