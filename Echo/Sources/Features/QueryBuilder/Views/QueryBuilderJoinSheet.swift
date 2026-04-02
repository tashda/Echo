import SwiftUI

struct QueryBuilderJoinSheet: View {
    @Bindable var viewModel: VisualQueryBuilderViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var sourceTableID: UUID?
    @State private var sourceColumn = ""
    @State private var targetTableID: UUID?
    @State private var targetColumn = ""
    @State private var joinType: VisualQueryBuilderViewModel.JoinType = .inner

    var body: some View {
        SheetLayoutCustomFooter(title: "Add Join") {
            Form {
                Section("Join Type") {
                    Picker("Type", selection: $joinType) {
                        ForEach(VisualQueryBuilderViewModel.JoinType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Source Table") {
                    Picker("Table", selection: $sourceTableID) {
                        Text("Select table").tag(nil as UUID?)
                        ForEach(viewModel.tables) { table in
                            Text("\(table.name) (\(table.alias))").tag(table.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)

                    if let sourceID = sourceTableID,
                       let table = viewModel.tables.first(where: { $0.id == sourceID }) {
                        Picker("Column", selection: $sourceColumn) {
                            Text("Select column").tag("")
                            ForEach(table.columns, id: \.name) { col in
                                Text(col.name).tag(col.name)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Target Table") {
                    Picker("Table", selection: $targetTableID) {
                        Text("Select table").tag(nil as UUID?)
                        ForEach(viewModel.tables) { table in
                            Text("\(table.name) (\(table.alias))").tag(table.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)

                    if let targetID = targetTableID,
                       let table = viewModel.tables.first(where: { $0.id == targetID }) {
                        Picker("Column", selection: $targetColumn) {
                            Text("Select column").tag("")
                            ForEach(table.columns, id: \.name) { col in
                                Text(col.name).tag(col.name)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        } footer: {
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Add Join") {
                guard let sourceID = sourceTableID,
                      let targetID = targetTableID,
                      !sourceColumn.isEmpty,
                      !targetColumn.isEmpty else { return }
                viewModel.addJoin(
                    sourceTableID: sourceID,
                    sourceColumn: sourceColumn,
                    targetTableID: targetID,
                    targetColumn: targetColumn,
                    type: joinType
                )
                dismiss()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.defaultAction)
            .disabled(sourceTableID == nil || targetTableID == nil || sourceColumn.isEmpty || targetColumn.isEmpty)
        }
        .frame(width: 420, height: 400)
    }
}
