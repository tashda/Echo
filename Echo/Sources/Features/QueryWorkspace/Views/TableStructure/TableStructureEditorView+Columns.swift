import SwiftUI

extension TableStructureEditorView {

    internal var columnsContent: some View {
        Group {
            if visibleColumns.isEmpty {
                ContentUnavailableView {
                    Label("No Columns", systemImage: "tablecells")
                } description: {
                    Text("Columns define the data stored in this table.")
                } actions: {
                    Button("Add Column") { presentNewColumn() }
                }
            } else {
                columnsTable
            }
        }
    }

    private var primaryKeyColumnNames: Set<String> {
        Set(viewModel.primaryKey?.columns ?? [])
    }

    private var columnsTable: some View {
        Table(viewModel.columns, selection: $selectedColumnIDs) {
            TableColumn("Kind") { column in
                if !column.isDeleted, primaryKeyColumnNames.contains(column.name) {
                    Text("PK")
                        .font(TypographyTokens.Table.kindBadge)
                        .foregroundStyle(.orange)
                }
            }
            .width(35)

            TableColumn("Name") { column in
                Text(column.name)
                    .font(TypographyTokens.Table.name)
                    .foregroundStyle(column.isDeleted ? ColorTokens.Text.tertiary : ColorTokens.Text.primary)
                    .strikethrough(column.isDeleted)
            }
            .width(min: 100, ideal: 180)

            TableColumn("Type") { column in
                if column.isDeleted {
                    Text(column.dataType)
                        .font(TypographyTokens.Table.category)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .strikethrough()
                } else if let index = columnIndexLookup[column.id], index < viewModel.columns.count {
                    DataTypePicker(selection: $viewModel.columns[index].dataType, databaseType: viewModel.databaseType, compact: true)
                } else {
                    Text(column.dataType)
                        .font(TypographyTokens.Table.category)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            .width(min: 80, ideal: 120)

            TableColumn("Null") { column in
                if !column.isDeleted {
                    Image(systemName: column.isNullable ? "checkmark" : "minus")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(column.isNullable ? .blue : ColorTokens.Text.tertiary)
                }
            }
            .width(40)

            TableColumn("Default") { column in
                if let defaultValue = column.defaultValue, !defaultValue.isEmpty {
                    Text(defaultValue)
                        .font(TypographyTokens.Table.sql)
                        .foregroundStyle(column.isDeleted ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(defaultValue)
                } else {
                    Text("\u{2014}")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(min: 60, ideal: 120)
        }
        .contextMenu(forSelectionType: TableStructureEditorViewModel.ColumnModel.ID.self) { selection in
            columnContextMenu(for: selection)
        } primaryAction: { selection in
            if let columnID = selection.first,
               let column = visibleColumns.first(where: { $0.id == columnID }) {
                presentColumnEditor(for: column)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
    }

    @ViewBuilder
    private func columnContextMenu(for selection: Set<TableStructureEditorViewModel.ColumnModel.ID>) -> some View {
        let targets = selection.compactMap { id in
            visibleColumns.first(where: { $0.id == id })
        }

        if targets.isEmpty {
            Button("Add Column") { presentNewColumn() }
        } else if targets.count > 1 {
            dataTypeSubmenu(for: targets)

            Button("Edit Default Value") {
                presentBulkEditor(mode: .defaultValue, columns: targets)
            }
            Button("Edit Generated Expression") {
                presentBulkEditor(mode: .generatedExpression, columns: targets)
            }

            Divider()

            Button("Delete \(targets.count) Columns", role: .destructive) {
                removeColumns(targets)
            }
        } else if let column = targets.first {
            Button("Edit Column") { presentColumnEditor(for: column) }

            Divider()

            dataTypeSubmenu(for: [column])

            Divider()

            Button("Delete Column", role: .destructive) { removeColumns([column]) }
        }
    }

    @ViewBuilder
    private func dataTypeSubmenu(for columns: [TableStructureEditorViewModel.ColumnModel]) -> some View {
        let typeList = viewModel.databaseType == .microsoftSQL
            ? MSSQLDataTypePicker.commonTypes
            : PostgresDataTypePicker.commonTypes
        Menu("Change Data Type") {
            ForEach(typeList, id: \.category) { group in
                Section(group.category) {
                    ForEach(group.types, id: \.self) { type in
                        Button(type) {
                            for column in columns {
                                if let index = columnIndexLookup[column.id], index < viewModel.columns.count {
                                    viewModel.columns[index].dataType = type
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
