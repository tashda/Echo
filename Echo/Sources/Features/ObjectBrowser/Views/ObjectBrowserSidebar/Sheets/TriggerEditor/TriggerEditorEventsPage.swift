import SwiftUI

struct TriggerEditorEventsPage: View {
    @Bindable var viewModel: TriggerEditorViewModel

    var body: some View {
        Section("Events") {
            PropertyRow(title: "INSERT") {
                Toggle("", isOn: $viewModel.onInsert)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            PropertyRow(title: "UPDATE") {
                Toggle("", isOn: $viewModel.onUpdate)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            PropertyRow(title: "DELETE") {
                Toggle("", isOn: $viewModel.onDelete)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            PropertyRow(title: "TRUNCATE") {
                Toggle("", isOn: $viewModel.onTruncate)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }

        Section("Condition") {
            PropertyRow(
                title: "WHEN",
                info: "Optional boolean expression. The trigger fires only when this condition is true. Use OLD and NEW to reference row values."
            ) {
                TextField(
                    "",
                    text: $viewModel.whenCondition,
                    prompt: Text("e.g. OLD.status IS DISTINCT FROM NEW.status"),
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(2...4)
            }
        }
    }
}
