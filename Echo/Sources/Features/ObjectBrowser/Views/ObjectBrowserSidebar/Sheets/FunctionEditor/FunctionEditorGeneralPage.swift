import SwiftUI

struct FunctionEditorGeneralPage: View {
    @Bindable var viewModel: FunctionEditorViewModel

    var body: some View {
        Section("General") {
            if !viewModel.isEditing {
                PropertyRow(title: "Function Name") {
                    TextField("", text: $viewModel.functionName, prompt: Text("my_function"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }

            PropertyRow(title: "Schema") {
                Text(viewModel.schemaName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            PropertyRow(
                title: "Return Type",
                info: "The data type returned by the function. Use SETOF for set-returning functions, or void for procedures."
            ) {
                TextField("", text: $viewModel.returnType, prompt: Text("e.g. integer, void, SETOF record"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }

        Section("Documentation") {
            PropertyRow(title: "Description") {
                TextField(
                    "",
                    text: $viewModel.description,
                    prompt: Text("Describe what this function does"),
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(3...6)
            }
        }
    }
}
