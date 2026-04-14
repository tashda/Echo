import SwiftUI

struct SequenceEditorGeneralPage: View {
    @Bindable var viewModel: SequenceEditorViewModel

    var body: some View {
        Section("General") {
            if !viewModel.isEditing {
                PropertyRow(title: "Sequence Name") {
                    TextField("", text: $viewModel.sequenceName, prompt: Text("e.g. order_id_seq"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }

            PropertyRow(title: "Schema") {
                Text(viewModel.schemaName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            if viewModel.isEditing {
                PropertyRow(title: "Owner") {
                    TextField("", text: $viewModel.owner, prompt: Text("e.g. postgres"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }

                PropertyRow(title: "Last Value") {
                    Text(viewModel.lastValue.isEmpty ? "—" : viewModel.lastValue)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }

        Section("Documentation") {
            PropertyRow(title: "Description") {
                TextField(
                    "",
                    text: $viewModel.description,
                    prompt: Text("Describe what this sequence is used for"),
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(3...6)
            }
        }
    }
}
