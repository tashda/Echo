import SwiftUI

#if os(macOS)
import AppKit
#endif

extension TableStructureEditorView {

    // MARK: - Inline Editing Infrastructure
#if os(macOS)
    internal struct InlineEditableCell: View {
        @Binding var value: String
        let placeholder: String
        let alignment: TextAlignment

        @State private var isEditing = false
        @State private var workingValue: String = ""
        @State private var focusSession: Int = 0

        private var swiftAlignment: Alignment {
            switch alignment {
            case .trailing: return .trailing
            case .center: return .center
            default: return .leading
            }
        }

        private var textAlignment: NSTextAlignment {
            switch alignment {
            case .trailing: return .right
            case .center: return .center
            default: return .left
            }
        }

        private var textColor: Color { ColorTokens.Text.primary }
        private var placeholderColor: Color { ColorTokens.Text.primary.opacity(appearanceStore.effectiveColorScheme == .dark ? 0.4 : 0.45) }

        @Environment(AppearanceStore.self) var appearanceStore

        var body: some View {
            ZStack(alignment: swiftAlignment) {
                if isEditing {
                    InlineEditableTextField(
                        text: $workingValue,
                        alignment: textAlignment,
                        focusSession: focusSession,
                        onCommit: commit,
                        onCancel: cancel
                    )
                    .frame(maxWidth: .infinity, alignment: swiftAlignment)
                } else {
                    if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(placeholder)
                            .foregroundStyle(placeholderColor)
                            .frame(maxWidth: .infinity, alignment: swiftAlignment)
                    } else {
                        Text(value)
                            .foregroundStyle(textColor)
                            .frame(maxWidth: .infinity, alignment: swiftAlignment)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: swiftAlignment)
            .contentShape(Rectangle())
            .onTapGesture { beginEditing() }
        }

        private func beginEditing() {
            workingValue = value
            focusSession &+= 1
            isEditing = true
        }

        private func commit(_ newValue: String) {
            value = newValue
            workingValue = newValue
            isEditing = false
        }

        private func cancel() {
            workingValue = value
            isEditing = false
        }
    }

    internal struct InlineEditableTextField: NSViewRepresentable {
        @Binding var text: String
        let alignment: NSTextAlignment
        let focusSession: Int
        let onCommit: (String) -> Void
        let onCancel: () -> Void

        func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

        func makeNSView(context: Context) -> NSTextField {
            let field = NSTextField()
            field.isBordered = false
            field.drawsBackground = false
            field.font = NSFont.systemFont(ofSize: 12)
            field.alignment = alignment
            field.delegate = context.coordinator
            field.focusRingType = .none
            field.lineBreakMode = .byTruncatingTail
            field.translatesAutoresizingMaskIntoConstraints = false
            return field
        }

        func updateNSView(_ nsView: NSTextField, context: Context) {
            context.coordinator.parent = self
            if nsView.stringValue != text { nsView.stringValue = text }
            nsView.alignment = alignment
            nsView.textColor = NSColor(ColorTokens.Text.primary)

            if context.coordinator.lastFocusSession != focusSession {
                context.coordinator.lastFocusSession = focusSession
                Task { @MainActor in
                    nsView.window?.makeFirstResponder(nsView)
                    if let editor = nsView.currentEditor() {
                        editor.selectedRange = NSRange(location: 0, length: (nsView.stringValue as NSString).length)
                    }
                }
            }
        }

        final class Coordinator: NSObject, NSTextFieldDelegate {
            var parent: InlineEditableTextField
            var lastFocusSession: Int = -1
            private var didHandleCommand = false

            init(parent: InlineEditableTextField) { self.parent = parent }

            func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
                switch commandSelector {
                case #selector(NSResponder.cancelOperation(_:)):
                    didHandleCommand = true
                    parent.onCancel()
                    return true
                case #selector(NSResponder.insertNewline(_:)):
                    didHandleCommand = true
                    parent.onCommit(control.stringValue)
                    return true
                default: return false
                }
            }

            func controlTextDidEndEditing(_ notification: Notification) {
                guard let field = notification.object as? NSTextField else { return }
                if didHandleCommand { didHandleCommand = false; return }
                parent.onCommit(field.stringValue)
            }
        }
    }
#else
    internal struct InlineEditableCell: View {
        @Binding var value: String
        let placeholder: String
        let alignment: TextAlignment

        var body: some View {
            TextField(placeholder, text: $value)
                .multilineTextAlignment(alignment)
                .textFieldStyle(.plain)
        }
    }
#endif
}
