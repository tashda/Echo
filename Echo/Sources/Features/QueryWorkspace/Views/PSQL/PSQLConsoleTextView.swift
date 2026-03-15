import AppKit

protocol PSQLConsoleTextViewDelegate: AnyObject {
    func consoleTextViewDidSubmit(_ textView: PSQLConsoleTextView)
    func consoleTextViewShowPreviousCommand(_ textView: PSQLConsoleTextView)
    func consoleTextViewShowNextCommand(_ textView: PSQLConsoleTextView)
}

final class PSQLConsoleTextView: NSTextView {
    weak var consoleDelegate: PSQLConsoleTextViewDelegate?
    var protectedLength: Int = 0

    override func keyDown(with event: NSEvent) {
        enforceEditableSelection()
        super.keyDown(with: event)
        enforceEditableSelection()
    }

    override func doCommand(by selector: Selector) {
        switch selector {
        case #selector(insertNewline(_:)):
            consoleDelegate?.consoleTextViewDidSubmit(self)
        case #selector(moveUp(_:)):
            consoleDelegate?.consoleTextViewShowPreviousCommand(self)
        case #selector(moveDown(_:)):
            consoleDelegate?.consoleTextViewShowNextCommand(self)
        default:
            super.doCommand(by: selector)
        }
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        enforceEditableSelection()
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        enforceEditableSelection()
    }

    override func selectionRange(forProposedRange proposedSelRange: NSRange, granularity: NSSelectionGranularity) -> NSRange {
        if proposedSelRange.location < protectedLength {
            return NSRange(location: string.count, length: 0)
        }
        return super.selectionRange(forProposedRange: proposedSelRange, granularity: granularity)
    }

    override func shouldChangeText(in affectedCharRange: NSRange, replacementString: String?) -> Bool {
        if affectedCharRange.location < protectedLength {
            moveCaretToEnd()
            return false
        }
        return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
    }

    func moveCaretToEnd() {
        let end = string.count
        setSelectedRange(NSRange(location: end, length: 0))
    }

    func replaceConsoleText(with text: String) {
        if string != text {
            string = text
        }
        relayoutConsole()
    }

    private func enforceEditableSelection() {
        let selection = selectedRange()
        if selection.location < protectedLength {
            moveCaretToEnd()
        }
    }

    private func relayoutConsole() {
        guard let textContainer, let layoutManager else { return }

        layoutManager.ensureLayout(for: textContainer)

        let usedRect = layoutManager.usedRect(for: textContainer)
        let contentHeight = ceil(usedRect.height + (textContainerInset.height * 2))
        let visibleHeight = enclosingScrollView?.contentSize.height ?? 0
        let targetHeight = max(contentHeight, visibleHeight)

        if frame.height != targetHeight {
            setFrameSize(NSSize(width: frame.width, height: targetHeight))
        }

        needsDisplay = true
        enclosingScrollView?.contentView.needsDisplay = true
    }
}
