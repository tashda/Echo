import SwiftUI

struct DiagramCreateRelationshipSheet: View {
    let schemaName: String
    let databaseType: DatabaseType
    let session: DatabaseSession
    let availableTables: [(schema: String, name: String, columns: [String])]
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var sourceTableIndex: Int = 0
    @State private var sourceColumnName = ""
    @State private var targetTableIndex: Int = 0
    @State private var targetColumnName = ""
    @State private var constraintName = ""
    @State private var onDelete = "NO ACTION"
    @State private var onUpdate = "NO ACTION"
    @State private var isCreating = false
    @State private var errorMessage: String?

    private let referentialActions = ["NO ACTION", "CASCADE", "SET NULL", "SET DEFAULT", "RESTRICT"]

    var body: some View {
        SheetLayoutCustomFooter(title: "New Relationship") {
            Form {
                Section("Source (Foreign Key)") {
                    if availableTables.isEmpty {
                        Text("No tables in diagram")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    } else {
                        Picker("Table", selection: $sourceTableIndex) {
                            ForEach(availableTables.indices, id: \.self) { idx in
                                Text(availableTables[idx].name).tag(idx)
                            }
                        }

                        if !sourceColumns.isEmpty {
                            Picker("Column", selection: $sourceColumnName) {
                                Text("Select column").tag("")
                                ForEach(sourceColumns, id: \.self) { col in
                                    Text(col).tag(col)
                                }
                            }
                        }
                    }
                }

                Section("Target (References)") {
                    if availableTables.isEmpty {
                        Text("No tables in diagram")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    } else {
                        Picker("Table", selection: $targetTableIndex) {
                            ForEach(availableTables.indices, id: \.self) { idx in
                                Text(availableTables[idx].name).tag(idx)
                            }
                        }

                        if !targetColumns.isEmpty {
                            Picker("Column", selection: $targetColumnName) {
                                Text("Select column").tag("")
                                ForEach(targetColumns, id: \.self) { col in
                                    Text(col).tag(col)
                                }
                            }
                        }
                    }
                }

                Section("Options") {
                    TextField("Constraint Name", text: $constraintName, prompt: Text("Auto-generated if empty"))

                    Picker("ON DELETE", selection: $onDelete) {
                        ForEach(referentialActions, id: \.self) { action in
                            Text(action).tag(action)
                        }
                    }

                    Picker("ON UPDATE", selection: $onUpdate) {
                        ForEach(referentialActions, id: \.self) { action in
                            Text(action).tag(action)
                        }
                    }
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
            Button("Create Relationship") {
                createRelationship()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!canCreate || isCreating)
        }
        .frame(width: 480, height: 460)
        .onAppear {
            if availableTables.count > 1 {
                targetTableIndex = 1
            }
        }
    }

    private var sourceColumns: [String] {
        guard sourceTableIndex < availableTables.count else { return [] }
        return availableTables[sourceTableIndex].columns
    }

    private var targetColumns: [String] {
        guard targetTableIndex < availableTables.count else { return [] }
        return availableTables[targetTableIndex].columns
    }

    private var canCreate: Bool {
        !sourceColumnName.isEmpty && !targetColumnName.isEmpty && !availableTables.isEmpty
    }

    private func createRelationship() {
        guard canCreate else { return }
        isCreating = true
        errorMessage = nil

        let source = availableTables[sourceTableIndex]
        let target = availableTables[targetTableIndex]

        let fkName = constraintName.isEmpty
            ? "fk_\(source.name)_\(target.name)_\(sourceColumnName)"
            : constraintName

        Task {
            do {
                let sql = buildAlterSQL(
                    sourceSchema: source.schema,
                    sourceTable: source.name,
                    sourceColumn: sourceColumnName,
                    targetSchema: target.schema,
                    targetTable: target.name,
                    targetColumn: targetColumnName,
                    constraintName: fkName
                )
                _ = try await session.simpleQuery(sql)
                dismiss()
                onCreated()
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
        }
    }

    private func buildAlterSQL(
        sourceSchema: String,
        sourceTable: String,
        sourceColumn: String,
        targetSchema: String,
        targetTable: String,
        targetColumn: String,
        constraintName: String
    ) -> String {
        switch databaseType {
        case .microsoftSQL:
            return """
            ALTER TABLE [\(sourceSchema)].[\(sourceTable)]
            ADD CONSTRAINT [\(constraintName)]
                FOREIGN KEY ([\(sourceColumn)])
                REFERENCES [\(targetSchema)].[\(targetTable)] ([\(targetColumn)])
                ON DELETE \(onDelete) ON UPDATE \(onUpdate);
            GO
            """
        case .postgresql:
            return """
            ALTER TABLE "\(sourceSchema)"."\(sourceTable)"
            ADD CONSTRAINT "\(constraintName)"
                FOREIGN KEY ("\(sourceColumn)")
                REFERENCES "\(targetSchema)"."\(targetTable)" ("\(targetColumn)")
                ON DELETE \(onDelete) ON UPDATE \(onUpdate);
            """
        case .mysql:
            return """
            ALTER TABLE `\(sourceTable)`
            ADD CONSTRAINT `\(constraintName)`
                FOREIGN KEY (`\(sourceColumn)`)
                REFERENCES `\(targetTable)` (`\(targetColumn)`)
                ON DELETE \(onDelete) ON UPDATE \(onUpdate);
            """
        case .sqlite:
            return "-- SQLite does not support ALTER TABLE ADD CONSTRAINT. Recreate the table with the foreign key."
        }
    }
}
