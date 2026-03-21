import SwiftUI

extension TableStructureEditorView {

    internal var columnsContent: some View {
        Group {
            if viewModel.columns.filter({ !$0.isDeleted }).isEmpty {
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

    /// All columns including deleted ones — deleted rows render dimmed with strikethrough.
    private var displayColumns: [TableStructureEditorViewModel.ColumnModel] {
        viewModel.columns
    }

    private var columnsTable: some View {
        Table(of: TableStructureEditorViewModel.ColumnModel.self, selection: $selectedColumnIDs) {
            TableColumn("PK") { column in
                if !column.isDeleted, primaryKeyColumnNames.contains(column.name) {
                    Image(systemName: "key.fill")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(accentColor.opacity(0.8))
                }
            }
            .width(30)

            TableColumn("Name") { column in
                if column.isDeleted {
                    Text(column.name)
                        .strikethrough()
                        .foregroundStyle(ColorTokens.Text.tertiary)
                } else if let binding = columnBinding(for: column.id) {
                    InlineEditableCell(value: binding.name, placeholder: "column_name", alignment: .leading)
                } else {
                    Text(column.name)
                }
            }
            .width(min: 100, ideal: 180)

            TableColumn("Type") { column in
                if column.isDeleted {
                    Text(column.dataType)
                        .font(TypographyTokens.Table.category)
                        .foregroundStyle(ColorTokens.Text.quaternary)
                        .strikethrough()
                } else if let binding = columnBinding(for: column.id) {
                    Picker("", selection: binding.dataType) {
                        ForEach(dataTypeOptions(for: viewModel.databaseType), id: \.self) { option in
                            Text(option).tag(option)
                        }
                        if !dataTypeOptions(for: viewModel.databaseType).contains(column.dataType) {
                            Divider()
                            Text(column.dataType).tag(column.dataType)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                } else {
                    Text(column.dataType)
                        .font(TypographyTokens.Table.category)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            .width(min: 60, ideal: 100)

            TableColumn("Null") { column in
                if column.isDeleted {
                    EmptyView()
                } else if let binding = columnBinding(for: column.id) {
                    Toggle("", isOn: binding.isNullable)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                } else {
                    Image(systemName: column.isNullable ? "checkmark" : "minus")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(column.isNullable ? accentColor : ColorTokens.Text.tertiary)
                }
            }
            .width(40)

            TableColumn("Default") { column in
                if let defaultValue = column.defaultValue, !defaultValue.isEmpty {
                    Text(defaultValue)
                        .font(TypographyTokens.Table.sql)
                        .foregroundStyle(column.isDeleted ? ColorTokens.Text.quaternary : ColorTokens.Text.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(defaultValue)
                }
            }
            .width(min: 60, ideal: 120)
        } rows: {
            ForEach(displayColumns) { column in
                TableRow(column)
                    .itemProvider { nil }
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
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .environment(\.defaultMinListRowHeight, 28)
        .onChange(of: selectedColumnIDs) { _, newIDs in
            pushColumnInspector(ids: newIDs)
        }
    }

    @ViewBuilder
    private func columnContextMenu(for selection: Set<TableStructureEditorViewModel.ColumnModel.ID>) -> some View {
        let targets = selection.compactMap { id in
            visibleColumns.first(where: { $0.id == id })
        }

        if targets.isEmpty {
            // Right-clicked empty area
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
        Menu("Change Data Type") {
            ForEach(dataTypeOptions(for: viewModel.databaseType), id: \.self) { option in
                Button(option) {
                    for column in columns {
                        if let binding = columnBinding(for: column.id) {
                            binding.wrappedValue.dataType = option
                        }
                    }
                }
            }
        }
    }
}
