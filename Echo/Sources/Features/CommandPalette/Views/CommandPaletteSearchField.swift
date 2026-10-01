import AppKit
import SwiftUI

/// The ⌘K palette's field (plan K4): an AppKit text field, so it takes the keyboard the moment the
/// palette opens, whatever had focus, and so ↑ ↓ (and ⌃P ⌃N, ⇥ ⇧⇥) move the selection while
/// Return performs it and Esc closes. In the tab overview, ⌫ ⌘⌫ and ⌥⌫ act on the selected tab
/// (round 35.1) when `onKeyCommand` takes them.
struct CommandPaletteSearchField: NSViewRepresentable {
    /// Keys the field offers before acting on the text.
    enum KeyCommand: Equatable {
        case deleteBackward, deleteToLineStart, deleteWordBackward
    }

    @Binding var text: String
    let placeholder: String
    let onMove: (Int) -> Void
    let onSubmit: () -> Void
    let onCancel: () -> Void
    /// Returns whether it handled the key; if not, the field edits the text as usual.
    var onKeyCommand: (KeyCommand) -> Bool = { _ in false }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> FocusingTextField {
        let field = FocusingTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = TypographyTokens.AppKit.title3
        field.placeholderString = placeholder
        field.cell?.sendsActionOnEndEditing = false
        field.cell?.lineBreakMode = .byTruncatingTail
        field.delegate = context.coordinator
        field.stringValue = text
        return field
    }

    func updateNSView(_ field: FocusingTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
        if field.placeholderString != placeholder { field.placeholderString = placeholder }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CommandPaletteSearchField

        init(parent: CommandPaletteSearchField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.moveUp(_:)), #selector(NSResponder.insertBacktab(_:)):
                parent.onMove(-1)
            case #selector(NSResponder.moveDown(_:)), #selector(NSResponder.insertTab(_:)):
                parent.onMove(1)
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit()
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onCancel()
            case #selector(NSResponder.deleteBackward(_:)):
                return parent.onKeyCommand(.deleteBackward)
            case #selector(NSResponder.deleteToBeginningOfLine(_:)):
                return parent.onKeyCommand(.deleteToLineStart)
            case #selector(NSResponder.deleteWordBackward(_:)):
                return parent.onKeyCommand(.deleteWordBackward)
            default:
                return false
            }
            return true
        }
    }
}

/// Becomes first responder as soon as it's in a window.
final class FocusingTextField: NSTextField {

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        // After the current layout pass, so SwiftUI's own focus handling can't take it back.
        Task { @MainActor [weak self, weak window] in
            guard let self, let window, self.window === window else { return }
            window.makeFirstResponder(self)
        }
    }
}
