import SwiftUI
import Foundation
#if os(macOS)
import AppKit
#endif

struct ForeignKeyEditorSheet: View {
    @Binding var foreignKey: TableStructureEditorViewModel.ForeignKeyModel
    let availableColumns: [String]
    let databaseType: DatabaseType
    let session: DatabaseSession
    let onDelete: () -> Void
    let onCancelNew: () -> Void

    @Environment(\.dismiss) var dismiss
    @State var draft: Draft
    @State private var availableSchemas: [String] = []
    @State private var availableTables: [String] = []
    @State private var availableRefColumns: [String] = []

    init(
        foreignKey: Binding<TableStructureEditorViewModel.ForeignKeyModel>,
        availableColumns: [String],
        databaseType: DatabaseType,
        session: DatabaseSession,
        onDelete: @escaping () -> Void,
        onCancelNew: @escaping () -> Void
    ) {
        self._foreignKey = foreignKey
        self.availableColumns = availableColumns
        self.databaseType = databaseType
        self.session = session
        self.onDelete = onDelete
        self.onCancelNew = onCancelNew
        _draft = State(initialValue: Draft(model: foreignKey.wrappedValue, availableColumns: availableColumns))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Form {
                    nameSection
                    referencedTableSection
                    columnMappingsSection
                    actionsSection
                    if databaseType == .postgresql {
                        deferrableSection
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }

            Divider()

            toolbar
        }
        .frame(minWidth: 560, idealWidth: 600, minHeight: 480)
        .navigationTitle(draft.isEditingExisting ? "Edit Foreign Key" : "New Foreign Key")
        .task { await loadSchemas() }
        .onChange(of: draft.referencedSchema) { _, newSchema in
            // Reset table and columns when schema changes
            if !availableTables.isEmpty || draft.referencedTable.isEmpty {
                draft.referencedTable = ""
                availableRefColumns = []
            }
            Task { await loadTables() }
        }
        .onChange(of: draft.referencedTable) { _, _ in
            Task { await loadRefColumns() }
        }
    }

    // MARK: - Data Loading

    private func loadSchemas() async {
        do {
            let allSchemas = try await session.listSchemas()
            // Filter to schemas that contain at least one table
            var schemasWithTables: [String] = []
            for schema in allSchemas {
                let objects = try await session.listTablesAndViews(schema: schema)
                if objects.contains(where: { $0.type == .table }) {
                    schemasWithTables.append(schema)
                }
            }
            availableSchemas = schemasWithTables.sorted()
            if !draft.referencedSchema.isEmpty {
                await loadTables()
            }
        } catch { /* silently degrade to text input */ }
    }

    private func loadTables() async {
        guard !draft.referencedSchema.isEmpty else {
            availableTables = []
            return
        }
        do {
            let objects = try await session.listTablesAndViews(schema: draft.referencedSchema)
            availableTables = objects.filter { $0.type == .table }.map(\.name).sorted()
            if !draft.referencedTable.isEmpty {
                await loadRefColumns()
            }
        } catch { availableTables = [] }
    }

    private func loadRefColumns() async {
        guard !draft.referencedTable.isEmpty, !draft.referencedSchema.isEmpty else {
            availableRefColumns = []
            return
        }
        do {
            let columns = try await session.getTableSchema(draft.referencedTable, schemaName: draft.referencedSchema)
            availableRefColumns = columns.map(\.name)
        } catch { availableRefColumns = [] }
    }

    // MARK: - Name

    private var nameSection: some View {
        Section {
            PropertyRow(title: "Constraint Name") {
                TextField("", text: $draft.name, prompt: Text("fk_table_column"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("Name")
        } footer: {
            if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Name is required.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Status.error)
            }
        }
    }

    // MARK: - Referenced Table

    private var referencedTableSection: some View {
        Section {
            PropertyRow(title: "Schema") {
                if availableSchemas.isEmpty {
                    TextField("", text: $draft.referencedSchema, prompt: Text("schema_name"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                } else {
                    Picker("", selection: $draft.referencedSchema) {
                        ForEach(availableSchemas, id: \.self) { schema in
                            Text(schema).tag(schema)
                        }
                        if !availableSchemas.contains(draft.referencedSchema), !draft.referencedSchema.isEmpty {
                            Text(draft.referencedSchema).tag(draft.referencedSchema)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }

            PropertyRow(title: "Table") {
                if availableTables.isEmpty {
                    TextField("", text: $draft.referencedTable, prompt: Text("table_name"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                } else {
                    Picker("", selection: $draft.referencedTable) {
                        ForEach(availableTables, id: \.self) { table in
                            Text(table).tag(table)
                        }
                        if !availableTables.contains(draft.referencedTable), !draft.referencedTable.isEmpty {
                            Text(draft.referencedTable).tag(draft.referencedTable)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }
        } header: {
            Text("Referenced Table")
        } footer: {
            if draft.referencedTable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Referenced table is required.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Status.error)
            } else {
                Text("The table this foreign key references.")
                    .font(TypographyTokens.formDescription)
            }
        }
    }

    // MARK: - Column Mappings

    private var columnMappingsSection: some View {
        Section {
            ForEach(Array(draft.mappings.enumerated()), id: \.element.id) { _, mapping in
                if let idx = draft.mappings.firstIndex(where: { $0.id == mapping.id }) {
                    mappingRow(at: idx)
                }
            }

            Menu {
                ForEach(mappingAddableColumns, id: \.self) { name in
                    Button(name) {
                        draft.mappings.append(Draft.ColumnMapping(localColumn: name, referencedColumn: ""))
                    }
                }
            } label: {
                Label("Add Mapping", systemImage: "plus")
            }
            .menuStyle(.borderlessButton)
            .disabled(mappingAddableColumns.isEmpty)
        } header: {
            Text("Column Mappings")
        } footer: {
            if draft.mappings.isEmpty {
                Text("At least one column mapping is required.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Status.error)
            } else {
                Text("Each row maps a column in this table to a column in the referenced table.")
                    .font(TypographyTokens.formDescription)
            }
        }
    }

    private func mappingRow(at index: Int) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            // Local column picker
            Picker("", selection: $draft.mappings[index].localColumn) {
                ForEach(mappingLocalOptions(for: draft.mappings[index].id), id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()

            Image(systemName: "arrow.right")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)

            // Referenced column — picker if we have data, text field otherwise
            Spacer(minLength: 0)

            if availableRefColumns.isEmpty {
                TextField("", text: $draft.mappings[index].referencedColumn, prompt: Text("column_name"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            } else {
                Picker("", selection: $draft.mappings[index].referencedColumn) {
                    Text("Select column").tag("")
                    ForEach(availableRefColumns, id: \.self) { col in
                        Text(col).tag(col)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }

            Button(role: .destructive) {
                draft.mappings.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .buttonStyle(.borderless)
            .disabled(false)
        }
    }

    private var mappingAddableColumns: [String] {
        let used = Set(draft.mappings.map(\.localColumn))
        return availableColumns.filter { !used.contains($0) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func mappingLocalOptions(for mappingID: UUID) -> [String] {
        let usedByOthers = Set(draft.mappings.filter { $0.id != mappingID }.map(\.localColumn))
        var options = availableColumns.filter { !usedByOthers.contains($0) }
        if let current = draft.mappings.first(where: { $0.id == mappingID })?.localColumn,
           !current.isEmpty, !options.contains(current) {
            options.append(current)
        }
        return options.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
