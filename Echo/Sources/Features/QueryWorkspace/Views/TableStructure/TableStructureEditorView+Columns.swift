import SwiftUI

extension TableStructureEditorView {

    internal var columnsContent: some View {
        VStack(spacing: 0) {
            sectionToolbar(title: "Columns", count: visibleColumns.count) {
                presentNewColumn()
            }

            Divider()

            if visibleColumns.isEmpty {
                EmptyStatePlaceholder(
                    icon: "tablecells",
                    title: "No Columns",
                    subtitle: "Columns define the data stored in this table.",
                    actionTitle: "Add Column"
                ) {
                    presentNewColumn()
                }
            } else {
                columnsTable
            }
        }
    }

    private var columnsTable: some View {
        Table(of: TableStructureEditorViewModel.ColumnModel.self, selection: $selectedColumnIDs) {
            TableColumn("Name") { column in
                HStack(spacing: SpacingTokens.xxs) {
                    if column.isNew || column.isDirty {
                        Circle()
                            .fill(accentColor)
                            .frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2)
                    }
                    Text(column.name)
                        .font(TypographyTokens.standard.weight(.medium))
                        .help(column.name)
                }
            }
            .width(min: 100, ideal: 180)

            TableColumn("Type") { column in
                Text(column.dataType)
                    .font(TypographyTokens.detail.monospaced())
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .help(column.dataType)
            }
            .width(min: 80, ideal: 140)

            TableColumn("Nullable") { column in
                Image(systemName: column.isNullable ? "checkmark" : "minus")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(column.isNullable ? accentColor : ColorTokens.Text.tertiary)
            }
            .width(55)

            TableColumn("Default") { column in
                Text(column.defaultValue ?? "\u{2014}")
                    .font(TypographyTokens.detail.monospaced())
                    .foregroundStyle(column.defaultValue != nil ? ColorTokens.Text.secondary : ColorTokens.Text.tertiary)
                    .lineLimit(1)
            }
            .width(min: 60, ideal: 120)

            TableColumn("Generated") { column in
                Text(column.generatedExpression ?? "\u{2014}")
                    .font(TypographyTokens.detail.monospaced())
                    .foregroundStyle(column.generatedExpression != nil ? ColorTokens.Text.secondary : ColorTokens.Text.tertiary)
                    .lineLimit(1)
            }
            .width(min: 60, ideal: 120)
        } rows: {
            ForEach(visibleColumns) { column in
                TableRow(column)
            }
        }
        .contextMenu(forSelectionType: TableStructureEditorViewModel.ColumnModel.ID.self) { selection in
            columnContextMenu(for: selection)
        } primaryAction: { selection in
            if let columnID = selection.first,
               let column = visibleColumns.first(where: { $0.id == columnID }) {
                presentColumnEditor(for: column)
            }
        }
        .tableStyle(.bordered(alternatesRowBackgrounds: true))
        .environment(\.defaultMinListRowHeight, 28)
    }

    @ViewBuilder
    private func columnContextMenu(for selection: Set<TableStructureEditorViewModel.ColumnModel.ID>) -> some View {
        let targets = selection.compactMap { id in
            visibleColumns.first(where: { $0.id == id })
        }

        if targets.count > 1 {
            Button("Edit Data Type\u{2026}") {
                presentBulkEditor(mode: .dataType, columns: targets)
            }
            Button("Edit Default Value\u{2026}") {
                presentBulkEditor(mode: .defaultValue, columns: targets)
            }
            Button("Edit Generated Expression\u{2026}") {
                presentBulkEditor(mode: .generatedExpression, columns: targets)
            }

            Divider()

            Button("Delete \(targets.count) Columns", role: .destructive) {
                removeColumns(targets)
            }
        } else if let column = targets.first {
            Button("Edit Column\u{2026}") { presentColumnEditor(for: column) }
            Divider()
            Button("Delete Column", role: .destructive) { removeColumns([column]) }
        }
    }
}
