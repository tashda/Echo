import SwiftUI

struct ViewEditorGeneralPage: View {
    @Bindable var viewModel: ViewEditorViewModel

    var body: some View {
        Section("General") {
            if !viewModel.isEditing {
                PropertyRow(title: "View Name") {
                    TextField("", text: $viewModel.viewName, prompt: Text("e.g. active_users"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }

            PropertyRow(title: "Schema") {
                Text(viewModel.schemaName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            PropertyRow(title: "Type") {
                Text(viewModel.isMaterialized ? "Materialized View" : "View")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            if viewModel.isEditing {
                PropertyRow(title: "Owner") {
                    TextField("", text: $viewModel.owner, prompt: Text("e.g. postgres"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }
        }

        Section("Documentation") {
            PropertyRow(title: "Description") {
                TextField(
                    "",
                    text: $viewModel.description,
                    prompt: Text("Describe what this view returns"),
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(3...6)
            }
        }
    }
}
