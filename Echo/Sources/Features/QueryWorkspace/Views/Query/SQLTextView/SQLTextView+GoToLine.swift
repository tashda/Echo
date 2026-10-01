#if os(macOS)
import AppKit
import SwiftUI

/// Round 28.9 (GL1): ⌘L shows `GoToLineField` over the top of the editor instead of an alert.
extension SQLTextView {
    func showGoToLinePanel() {
        guard let host = enclosingScrollView?.superview ?? enclosingScrollView else { return }
        goToLineField?.removeFromSuperview()
        let text = string as NSString
        let field = NSHostingView(rootView: GoToLineField(
            lineCount: max(text.lineNumber(at: text.length), 1),
            onGo: { [weak self] line in
                self?.goToLine(line)
                self?.closeGoToLine()
            },
            onCancel: { [weak self] in self?.closeGoToLine() }
        ))
        let size = field.fittingSize
        let top = SpacingTokens.xs
        field.frame = NSRect(x: (host.bounds.width - size.width) / 2,
                             y: host.isFlipped ? top : host.bounds.height - size.height - top,
                             width: size.width, height: size.height)
        field.autoresizingMask = [.minXMargin, .maxXMargin, host.isFlipped ? .maxYMargin : .minYMargin]
        host.addSubview(field)
        goToLineField = field
    }

    func closeGoToLine() {
        goToLineField?.removeFromSuperview()
        goToLineField = nil
        window?.makeFirstResponder(self)
    }
}
#endif
