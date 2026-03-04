import SwiftUI

#if os(macOS)
import AppKit
#endif

extension TableStructureEditorView {
    
    // MARK: - Layout Constants
    internal enum ColumnLayout {
        static let name: CGFloat = 220
        static let dataType: CGFloat = 160
        static let allowNull: CGFloat = 90
        static let defaultValue: CGFloat = 180
        static let generated: CGFloat = 200
        static let status: CGFloat = 120
    }

    // MARK: - Atomic Cells (macOS)
#if os(macOS)
    @ViewBuilder
    internal func nameCell(for column: TableStructureEditorViewModel.ColumnModel, binding: Binding<TableStructureEditorViewModel.ColumnModel>?) -> some View {
        if let binding {
            inlineEditableField(text: binding.name, placeholder: "column_name", alignment: .leading)
        } else {
            Text(column.name)
                .fontWeight(.medium)
        }
    }

    @ViewBuilder
    internal func dataTypeCell(for column: TableStructureEditorViewModel.ColumnModel, binding: Binding<TableStructureEditorViewModel.ColumnModel>?) -> some View {
        if let binding {
            HStack(spacing: 4) {
                inlineEditableField(
                    text: Binding(
                        get: { binding.wrappedValue.dataType },
                        set: { binding.wrappedValue.dataType = $0.lowercased() }
                    ),
                    placeholder: "Data Type",
                    alignment: .leading
                )
                .focused($focusedCustomColumnID, equals: column.id)

                dataTypeMenuButton(for: column, binding: binding)
            }
        } else {
            Text(column.dataType.uppercased())
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func dataTypeMenuButton(
        for column: TableStructureEditorViewModel.ColumnModel,
        binding: Binding<TableStructureEditorViewModel.ColumnModel>
    ) -> some View {
        if #available(macOS 13.0, *) {
            dataTypeMenuBase(for: column, binding: binding)
                .menuIndicator(.hidden)
        } else {
            dataTypeMenuBase(for: column, binding: binding)
        }
    }

    private func dataTypeMenuBase(
        for column: TableStructureEditorViewModel.ColumnModel,
        binding: Binding<TableStructureEditorViewModel.ColumnModel>
    ) -> some View {
        Menu {
            dataTypeMenuItems(for: column, binding: binding)
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.vertical, 3)
                .padding(.horizontal, 5)
                .background(inlineButtonBackground)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .menuStyle(.borderlessButton)
    }

    @ViewBuilder
    private func dataTypeMenuItems(
        for column: TableStructureEditorViewModel.ColumnModel,
        binding: Binding<TableStructureEditorViewModel.ColumnModel>
    ) -> some View {
        ForEach(postgresDataTypeOptions, id: \.self) { option in
            Button(option) { binding.wrappedValue.dataType = option }
        }
        Divider()
        Button("Custom…") { focusedCustomColumnID = column.id }
    }

    @ViewBuilder
    internal func allowNullCell(for column: TableStructureEditorViewModel.ColumnModel, binding: Binding<TableStructureEditorViewModel.ColumnModel>?) -> some View {
        if let binding {
            Toggle("", isOn: binding.isNullable)
                .toggleStyle(.checkbox)
                .labelsHidden()
        } else {
            Toggle("", isOn: .constant(column.isNullable))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(true)
        }
    }

    @ViewBuilder
    internal func defaultValueCell(for column: TableStructureEditorViewModel.ColumnModel, binding: Binding<TableStructureEditorViewModel.ColumnModel>?) -> some View {
        if let binding {
            inlineEditableField(
                text: Binding(
                    get: { binding.wrappedValue.defaultValue ?? "" },
                    set: { newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        binding.wrappedValue.defaultValue = trimmed.isEmpty ? nil : trimmed
                    }
                ),
                placeholder: "—",
                alignment: .trailing
            )
        } else {
            Text(column.defaultValue?.isEmpty == false ? column.defaultValue! : "—")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    internal func generatedExpressionCell(for column: TableStructureEditorViewModel.ColumnModel, binding: Binding<TableStructureEditorViewModel.ColumnModel>?) -> some View {
        if let binding {
            inlineEditableField(
                text: Binding(
                    get: { binding.wrappedValue.generatedExpression ?? "" },
                    set: { newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        binding.wrappedValue.generatedExpression = trimmed.isEmpty ? nil : trimmed
                    }
                ),
                placeholder: "—",
                alignment: .trailing
            )
        } else {
            Text(column.generatedExpression?.isEmpty == false ? column.generatedExpression! : "—")
                .foregroundStyle(.secondary)
        }
    }
#endif

    // MARK: - Shared Atomic Cells
    @ViewBuilder
    internal func statusCell(for column: TableStructureEditorViewModel.ColumnModel) -> some View {
        let metadata = columnStatusMetadata(for: column)
        Label(metadata.title, systemImage: metadata.systemImage)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(metadata.tint)
    }

    @ViewBuilder
    internal func changesCell(for column: TableStructureEditorViewModel.ColumnModel) -> some View {
        if let description = columnChangeDescription(for: column) {
            Text(description)
                .foregroundStyle(.secondary)
        } else {
            Text("—")
                .foregroundStyle(Color.secondary.opacity(0.6))
        }
    }

    internal func inlineEditableField(
        text: Binding<String>,
        placeholder: String,
        alignment: TextAlignment
    ) -> some View {
        InlineEditableCell(
            value: text,
            placeholder: placeholder,
            alignment: alignment
        )
    }

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
        private var placeholderColor: Color { ColorTokens.Text.primary.opacity(themeManager.effectiveColorScheme == .dark ? 0.4 : 0.45) }

        @EnvironmentObject var themeManager: ThemeManager

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
                DispatchQueue.main.async {
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
