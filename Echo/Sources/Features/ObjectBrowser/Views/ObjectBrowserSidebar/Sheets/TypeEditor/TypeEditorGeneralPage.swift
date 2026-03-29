import SwiftUI

struct TypeEditorGeneralPage: View {
    @Bindable var viewModel: TypeEditorViewModel

    var body: some View {
        Section("General") {
            if !viewModel.isEditing {
                PropertyRow(title: "Type Name") {
                    TextField("", text: $viewModel.typeName, prompt: Text("e.g. my_type"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }

            PropertyRow(title: "Schema") {
                Text(viewModel.schemaName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            PropertyRow(title: "Category") {
                Text(viewModel.typeCategory.title)
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
                    prompt: Text("Describe the purpose of this type"),
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(3...6)
            }
        }
    }
}
