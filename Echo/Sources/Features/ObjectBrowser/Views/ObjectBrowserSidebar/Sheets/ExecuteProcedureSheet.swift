import SwiftUI

/// Sheet for executing a stored procedure or function with a visual parameter form.
struct ExecuteProcedureSheet: View {
    let object: SchemaObjectInfo
    let connection: SavedConnection
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onDismiss: () -> Void

    @State private var parameterValues: [UUID: String] = [:]
    @State private var drafts: [ParameterDraft] = []

    struct ParameterDraft: Identifiable {
        let id = UUID()
        let name: String
        let dataType: String
        let isOutput: Bool
        let hasDefault: Bool
    }

    private var objectKeyword: String {
        object.type == .procedure ? "Procedure" : "Function"
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Parameters") {
                    if drafts.isEmpty {
                        Text("This \(objectKeyword.lowercased()) has no parameters.")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    } else {
                        ForEach(drafts) { draft in
                            PropertyRow(title: parameterLabel(draft)) {
                                TextField(
                                    "",
                                    text: Binding(
                                        get: { parameterValues[draft.id] ?? "" },
                                        set: { parameterValues[draft.id] = $0 }
                                    ),
                                    prompt: Text(draft.hasDefault ? "DEFAULT" : "NULL")
                                )
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                                .font(TypographyTokens.code)
                            }
                        }
                    }
                }

                Section("SQL Preview") {
                    SQLPreviewSection(sql: generateExecuteSQL())
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Open in Query Tab") {
                    openInQueryTab()
                    onDismiss()
                }
                Button("Execute") {
                    executeDirectly()
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(SpacingTokens.md)
        }
        .frame(minWidth: 500, minHeight: 400)
        .navigationTitle("Execute \(objectKeyword)")
        .navigationSubtitle(object.name)
        .onAppear { buildDrafts() }
    }

    private func parameterLabel(_ draft: ParameterDraft) -> String {
        let prefix = connection.databaseType == .microsoftSQL ? "@" : ""
        let suffix = draft.isOutput ? " (OUT)" : ""
        return "\(prefix)\(draft.name)\(suffix)  \(draft.dataType)"
    }

    private func buildDrafts() {
        drafts = object.parameters
            .sorted(by: { $0.ordinalPosition < $1.ordinalPosition })
            .map { param in
                ParameterDraft(
                    name: param.name,
                    dataType: param.dataType,
                    isOutput: param.isOutput,
                    hasDefault: param.hasDefaultValue
                )
            }
    }

    private func generateExecuteSQL() -> String {
        let qualified: String
        switch connection.databaseType {
        case .microsoftSQL:
            let schema = object.schema.replacingOccurrences(of: "]", with: "]]")
            let name = object.name.replacingOccurrences(of: "]", with: "]]")
            qualified = "[\(schema)].[\(name)]"
        case .postgresql:
            let schema = object.schema.replacingOccurrences(of: "\"", with: "\"\"")
            let name = object.name.replacingOccurrences(of: "\"", with: "\"\"")
            qualified = "\"\(schema)\".\"\(name)\""
        default:
            qualified = "\(object.schema).\(object.name)"
        }

        let inputDrafts = drafts.filter { !$0.isOutput }

        switch connection.databaseType {
        case .microsoftSQL:
            if object.type == .function {
                let args = inputDrafts.map { valueOrNull($0) }.joined(separator: ", ")
                return "SELECT * FROM \(qualified)(\(args));"
            } else {
                if inputDrafts.isEmpty {
                    return "EXEC \(qualified);"
                }
                let args = inputDrafts.map { "    @\($0.name) = \(valueOrNull($0))" }.joined(separator: ",\n")
                return "EXEC \(qualified)\n\(args);"
            }
        case .postgresql:
            let args = inputDrafts.map { valueOrNull($0) }.joined(separator: ", ")
            if object.type == .procedure {
                return "CALL \(qualified)(\(args));"
            } else {
                return "SELECT * FROM \(qualified)(\(args));"
            }
        case .mysql:
            let args = inputDrafts.map { valueOrNull($0) }.joined(separator: ", ")
            if object.type == .procedure {
                return "CALL \(qualified)(\(args));"
            } else {
                return "SELECT \(qualified)(\(args));"
            }
        case .sqlite:
            return "-- Not supported"
        }
    }

    private func valueOrNull(_ draft: ParameterDraft) -> String {
        let value = parameterValues[draft.id] ?? ""
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return draft.hasDefault ? "DEFAULT" : "NULL"
        }
        return value
    }

    private func openInQueryTab() {
        let sql = generateExecuteSQL()
        environmentState.openQueryTab(for: session, presetQuery: sql)
    }

    private func executeDirectly() {
        let sql = generateExecuteSQL()
        environmentState.openQueryTab(for: session, presetQuery: sql, autoExecute: true)
    }
}
