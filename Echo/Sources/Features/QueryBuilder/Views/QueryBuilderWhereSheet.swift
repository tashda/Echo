import SwiftUI

struct QueryBuilderWhereSheet: View {
    @Bindable var viewModel: VisualQueryBuilderViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var tableID: UUID?
    @State private var column = ""
    @State private var operatorType = "="
    @State private var value = ""

    private let operators = ["=", "!=", "<", ">", "<=", ">=", "LIKE", "IN", "IS NULL", "IS NOT NULL", "BETWEEN"]

    var body: some View {
        SheetLayoutCustomFooter(title: "Add Filter Condition") {
            Form {
                Section("Column") {
                    Picker("Table", selection: $tableID) {
                        Text("Select table").tag(nil as UUID?)
                        ForEach(viewModel.tables) { table in
                            Text("\(table.name) (\(table.alias))").tag(table.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)

                    if let tid = tableID,
                       let table = viewModel.tables.first(where: { $0.id == tid }) {
                        Picker("Column", selection: $column) {
                            Text("Select column").tag("")
                            ForEach(table.columns, id: \.name) { col in
                                Text(col.name).tag(col.name)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Condition") {
                    Picker("Operator", selection: $operatorType) {
                        ForEach(operators, id: \.self) { op in
                            Text(op).tag(op)
                        }
                    }
                    .pickerStyle(.menu)

                    if operatorType != "IS NULL" && operatorType != "IS NOT NULL" {
                        TextField("Value", text: $value, prompt: Text("e.g. 'hello' or 42"))
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        } footer: {
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Add Filter") {
                guard let tid = tableID, !column.isEmpty else { return }
                let effectiveValue: String
                if operatorType == "IS NULL" || operatorType == "IS NOT NULL" {
                    effectiveValue = ""
                } else {
                    effectiveValue = value
                }
                viewModel.addWhereCondition(tableID: tid, column: column, op: operatorType, value: effectiveValue)
                dismiss()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.defaultAction)
            .disabled(tableID == nil || column.isEmpty)
        }
        .frame(width: 400, height: 340)
    }
}
