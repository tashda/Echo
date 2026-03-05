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
                .font(TypographyTokens.detail.weight(.regular))
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
                .font(TypographyTokens.detail.weight(.semibold))
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

}
