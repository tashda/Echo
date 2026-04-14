import SwiftUI

struct DiagramCreateTableSheet: View {
    let schemaName: String
    let databaseType: DatabaseType
    let session: DatabaseSession
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var tableName = ""
    @State private var columns: [ColumnDef] = [
        ColumnDef(name: "id", dataType: "INTEGER", isPrimaryKey: true, isNullable: false),
        ColumnDef(name: "", dataType: "TEXT", isPrimaryKey: false, isNullable: true),
    ]
    @State private var isCreating = false
    @State private var errorMessage: String?

    struct ColumnDef: Identifiable {
        let id = UUID()
        var name: String
        var dataType: String
        var isPrimaryKey: Bool
        var isNullable: Bool
    }

    var body: some View {
        SheetLayoutCustomFooter(title: "New Table") {
            Form {
                Section("Table") {
                    TextField("Table Name", text: $tableName, prompt: Text("e.g. users"))
                    LabeledContent("Schema") {
                        Text(schemaName)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }

                Section("Columns") {
                    ForEach($columns) { $col in
                        HStack(spacing: SpacingTokens.xs) {
                            TextField("Name", text: $col.name, prompt: Text("column_name"))
                                .frame(minWidth: 100)
                            TextField("Type", text: $col.dataType, prompt: Text("TEXT"))
                                .frame(width: 100)
                            Toggle("PK", isOn: $col.isPrimaryKey)
                                .toggleStyle(.checkbox)
                                .frame(width: 40)
                            Toggle("Null", isOn: $col.isNullable)
                                .toggleStyle(.checkbox)
                                .frame(width: 45)
                            Button {
                                columns.removeAll(where: { $0.id == col.id })
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .disabled(columns.count <= 1)
                        }
                    }

                    Button("Add Column") {
                        columns.append(ColumnDef(name: "", dataType: "TEXT", isPrimaryKey: false, isNullable: true))
                    }
                    .controlSize(.small)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Status.error)
                    }
                }
            }
            .formStyle(.grouped)
        } footer: {
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Create Table") {
                createTable()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(tableName.isEmpty || columns.allSatisfy { $0.name.isEmpty } || isCreating)
        }
        .frame(width: 500, height: 420)
    }

    private func createTable() {
        let validColumns = columns.filter { !$0.name.isEmpty }
        guard !tableName.isEmpty, !validColumns.isEmpty else { return }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                let sql = buildCreateSQL(validColumns: validColumns)
                _ = try await session.simpleQuery(sql)
                dismiss()
                onCreated()
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
        }
    }

    private func buildCreateSQL(validColumns: [ColumnDef]) -> String {
        let pkColumns = validColumns.filter(\.isPrimaryKey).map(\.name)

        let colDefs = validColumns.map { col in
            let name = quoteName(col.name)
            let nullable = col.isNullable ? "" : " NOT NULL"
            return "    \(name) \(col.dataType)\(nullable)"
        }

        var parts = colDefs
        if !pkColumns.isEmpty {
            let pkList = pkColumns.map { quoteName($0) }.joined(separator: ", ")
            parts.append("    PRIMARY KEY (\(pkList))")
        }

        let qualifiedName: String
        switch databaseType {
        case .microsoftSQL:
            qualifiedName = "[\(schemaName)].[\(tableName)]"
        case .postgresql:
            qualifiedName = "\"\(schemaName)\".\"\(tableName)\""
        case .mysql:
            qualifiedName = "`\(tableName)`"
        case .sqlite:
            qualifiedName = "\"\(tableName)\""
        }

        var sql = "CREATE TABLE \(qualifiedName) (\n\(parts.joined(separator: ",\n"))\n)"
        if databaseType == .microsoftSQL {
            sql += ";\nGO"
        } else {
            sql += ";"
        }
        return sql
    }

    private func quoteName(_ name: String) -> String {
        switch databaseType {
        case .microsoftSQL: return "[\(name)]"
        case .mysql: return "`\(name)`"
        default: return "\"\(name)\""
        }
    }
}
