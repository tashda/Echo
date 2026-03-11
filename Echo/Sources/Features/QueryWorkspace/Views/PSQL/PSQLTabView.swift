import SwiftUI
import AppKit

struct PSQLTabView: View {
    @ObservedObject var viewModel: PSQLTabViewModel

    var body: some View {
        PSQLTerminalView(viewModel: viewModel)
            .background(ColorTokens.Background.primary)
    }
}

struct PSQLTerminalView: NSViewRepresentable {
    @ObservedObject var viewModel: PSQLTabViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.contentView.backgroundColor = .clear

        let textView = PSQLConsoleTextView()
        textView.consoleDelegate = context.coordinator
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.autoresizingMask = [.width]
        textView.backgroundColor = .clear
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.insertionPointColor = NSColor.labelColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.lineFragmentPadding = 0
        textView.replaceConsoleText(with: context.coordinator.renderedText)
        textView.protectedLength = viewModel.history.count

        scrollView.documentView = textView

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
            textView.moveCaretToEnd()
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.viewModel = viewModel

        guard let textView = nsView.documentView as? PSQLConsoleTextView else { return }
        context.coordinator.applyViewModelState(to: textView, forceScroll: false)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate, PSQLConsoleTextViewDelegate {
        var viewModel: PSQLTabViewModel
        private var lastHistory = ""
        private var lastInput = ""

        init(viewModel: PSQLTabViewModel) {
            self.viewModel = viewModel
            self.lastHistory = viewModel.history
            self.lastInput = viewModel.input
        }

        var renderedText: String {
            viewModel.history + viewModel.input
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? PSQLConsoleTextView else { return }
            let fullText = textView.string
            let historyLength = min(viewModel.history.count, fullText.count)
            let inputStart = fullText.index(fullText.startIndex, offsetBy: historyLength)
            let updatedInput = String(fullText[inputStart...])
            if viewModel.input != updatedInput {
                viewModel.input = updatedInput
            }
            textView.protectedLength = viewModel.history.count
            lastInput = viewModel.input
            lastHistory = viewModel.history
        }

        func consoleTextViewDidSubmit(_ textView: PSQLConsoleTextView) {
            viewModel.execute()
            applyViewModelState(to: textView, forceScroll: true)
        }

        func consoleTextViewShowPreviousCommand(_ textView: PSQLConsoleTextView) {
            viewModel.showPreviousCommand()
            applyViewModelState(to: textView, forceScroll: false)
        }

        func consoleTextViewShowNextCommand(_ textView: PSQLConsoleTextView) {
            viewModel.showNextCommand()
            applyViewModelState(to: textView, forceScroll: false)
        }

        func applyViewModelState(to textView: PSQLConsoleTextView, forceScroll: Bool) {
            let historyChanged = viewModel.history != lastHistory
            let inputChanged = viewModel.input != lastInput

            if historyChanged || inputChanged {
                textView.replaceConsoleText(with: renderedText)
            }

            textView.protectedLength = viewModel.history.count
            textView.moveCaretToEnd()
            if forceScroll || historyChanged {
                textView.scrollToEndOfDocument(nil)
            }

            lastHistory = viewModel.history
            lastInput = viewModel.input
        }
    }
}

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
