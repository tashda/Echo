import SwiftUI
import PostgresKit

/// Sheet for creating a new PostgreSQL trigger with visual options.
struct NewTriggerSheet: View {
    let session: ConnectionSession
    let schemaName: String
    let onComplete: () -> Void

    @State private var name = ""
    @State private var tableName = ""
    @State private var timing = "AFTER"
    @State private var onInsert = true
    @State private var onUpdate = false
    @State private var onDelete = false
    @State private var forEach = "ROW"
    @State private var functionName = ""
    @State private var whenCondition = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let timings = ["BEFORE", "AFTER", "INSTEAD OF"]
    private let forEachOptions = ["ROW", "STATEMENT"]

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !tableName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !functionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && (onInsert || onUpdate || onDelete)
        && !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New Trigger",
            icon: "bolt",
            subtitle: "Create a new table trigger.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section("Trigger") {
                    PropertyRow(title: "Name") {
                        TextField("", text: $name, prompt: Text("e.g. audit_changes"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Table") {
                        TextField("", text: $tableName, prompt: Text("e.g. orders"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Function") {
                        TextField("", text: $functionName, prompt: Text("e.g. log_changes()"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Timing") {
                    PropertyRow(title: "When") {
                        Picker("", selection: $timing) {
                            ForEach(timings, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    PropertyRow(title: "For Each") {
                        Picker("", selection: $forEach) {
                            ForEach(forEachOptions, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }

                Section("Events") {
                    PropertyRow(title: "INSERT") {
                        Toggle("", isOn: $onInsert)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    PropertyRow(title: "UPDATE") {
                        Toggle("", isOn: $onUpdate)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    PropertyRow(title: "DELETE") {
                        Toggle("", isOn: $onDelete)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }

                Section("Condition (optional)") {
                    PropertyRow(title: "WHEN") {
                        TextField("", text: $whenCondition, prompt: Text("e.g. OLD.status IS DISTINCT FROM NEW.status"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 460, idealWidth: 500, minHeight: 480)
    }

    private func submit() async {
        let trigName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let table = tableName.trimmingCharacters(in: .whitespacesAndNewlines)
        let funcName = functionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trigName.isEmpty, !table.isEmpty, !funcName.isEmpty else { return }
        guard let pg = session.session as? PostgresSession else { return }

        isSubmitting = true
        errorMessage = nil

        let handle = AppDirector.shared.activityEngine.begin("Creating trigger \(trigName)", connectionSessionID: session.id)
        do {
            var events: [String] = []
            if onInsert { events.append("INSERT") }
            if onUpdate { events.append("UPDATE") }
            if onDelete { events.append("DELETE") }

            let qualifiedTable = "\(ScriptingActions.pgQuote(schemaName)).\(ScriptingActions.pgQuote(table))"
            let qualifiedFunc = funcName.contains("(") ? funcName : "\(funcName)()"
            let whenClause = whenCondition.trimmingCharacters(in: .whitespacesAndNewlines)

            var sql = "CREATE TRIGGER \(ScriptingActions.pgQuote(trigName))"
            sql += " \(timing) \(events.joined(separator: " OR "))"
            sql += " ON \(qualifiedTable)"
            sql += " FOR EACH \(forEach)"
            if !whenClause.isEmpty { sql += " WHEN (\(whenClause))" }
            sql += " EXECUTE FUNCTION \(qualifiedFunc);"

            _ = try await pg.client.simpleQuery(sql)
            handle.succeed()
            onComplete()
        } catch {
            handle.fail(error.localizedDescription)
            isSubmitting = false
            errorMessage = error.localizedDescription
        }
    }
}
