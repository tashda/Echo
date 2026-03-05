import SwiftUI

#if os(macOS)
extension TableStructureEditorView {
    func columnRow(for column: TableStructureEditorViewModel.ColumnModel, index: Int) -> some View {
        let binding = Binding(
            get: { column },
            set: { viewModel.updateColumn($0) }
        )

        return HStack(spacing: 0) {
            nameCell(for: column, binding: binding)
                .frame(width: ColumnLayout.name, alignment: .leading)

            dataTypeCell(for: column, binding: binding)
                .frame(width: ColumnLayout.dataType, alignment: .leading)

            allowNullCell(for: column, binding: binding)
                .frame(width: ColumnLayout.allowNull, alignment: .center)

            defaultValueCell(for: column, binding: binding)
                .frame(width: ColumnLayout.defaultValue, alignment: .trailing)

            generatedExpressionCell(for: column, binding: binding)
                .frame(width: ColumnLayout.generated, alignment: .trailing)

            statusCell(for: column)
                .frame(width: ColumnLayout.status, alignment: .leading)

            Spacer()

            changesCell(for: column)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, SpacingTokens.md)
        .frame(height: 38)
        .contentShape(Rectangle())
        .onTapGesture {
            handleColumnClick(column)
        }
        .contextMenu {
            Button("Edit Column…") { presentColumnEditor(for: column) }
            Divider()
            Button("Remove Column", role: .destructive) { removeColumns([column]) }
        }
    }

    func handleColumnClick(_ column: TableStructureEditorViewModel.ColumnModel) {
        let modifiers = NSEvent.modifierFlags
        if modifiers.contains(.command) {
            if selectedColumnIDs.contains(column.id) {
                selectedColumnIDs.remove(column.id)
            } else {
                selectedColumnIDs.insert(column.id)
            }
            selectionAnchor = column.id
        } else if modifiers.contains(.shift), let anchor = selectionAnchor {
            let allIDs = visibleColumns.map(\.id)
            if let anchorIndex = allIDs.firstIndex(of: anchor),
               let currentIndex = allIDs.firstIndex(of: column.id) {
                let range = min(anchorIndex, currentIndex)...max(anchorIndex, currentIndex)
                selectedColumnIDs = Set(range.map { allIDs[$0] })
            }
        } else {
            selectedColumnIDs = [column.id]
            selectionAnchor = column.id
        }
    }
}
#endif
