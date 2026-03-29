import SwiftUI

struct TriggerEditorGeneralPage: View {
    @Bindable var viewModel: TriggerEditorViewModel

    var body: some View {
        Section("General") {
            if !viewModel.isEditing {
                PropertyRow(title: "Trigger Name") {
                    TextField("", text: $viewModel.triggerName, prompt: Text("e.g. audit_changes"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }

            PropertyRow(title: "Table") {
                Text("\(viewModel.schemaName).\(viewModel.tableName)")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            PropertyRow(title: "Function") {
                TextField("", text: $viewModel.functionName, prompt: Text("e.g. log_changes"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }

        Section("Timing") {
            PropertyRow(title: "When") {
                Picker("", selection: $viewModel.timing) {
                    ForEach(TriggerTiming.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            PropertyRow(title: "For Each") {
                Picker("", selection: $viewModel.forEach) {
                    ForEach(TriggerForEach.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }

        if viewModel.isEditing {
            Section("State") {
                PropertyRow(
                    title: "Enabled",
                    info: "Disabling a trigger prevents it from firing without dropping it."
                ) {
                    Toggle("", isOn: $viewModel.isEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }
        }

        Section("Documentation") {
            PropertyRow(title: "Description") {
                TextField(
                    "",
                    text: $viewModel.description,
                    prompt: Text("Describe what this trigger does"),
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(3...6)
            }
        }
    }
}
