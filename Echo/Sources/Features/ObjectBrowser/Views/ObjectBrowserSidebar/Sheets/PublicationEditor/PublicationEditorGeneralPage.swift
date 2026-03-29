import SwiftUI

struct PublicationEditorGeneralPage: View {
    @Bindable var viewModel: PublicationEditorViewModel

    var body: some View {
        Section("General") {
            if !viewModel.isEditing {
                PropertyRow(title: "Publication Name") {
                    TextField("", text: $viewModel.publicationName, prompt: Text("my_publication"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }

            PropertyRow(
                title: "All Tables",
                info: "When enabled, the publication automatically includes all tables in the database, including any created in the future."
            ) {
                Toggle("", isOn: $viewModel.allTables)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }

        Section("Operations") {
            PropertyRow(
                title: "Publish INSERT",
                info: "Include INSERT operations in the publication."
            ) {
                Toggle("", isOn: $viewModel.publishInsert)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            PropertyRow(
                title: "Publish UPDATE",
                info: "Include UPDATE operations in the publication."
            ) {
                Toggle("", isOn: $viewModel.publishUpdate)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            PropertyRow(
                title: "Publish DELETE",
                info: "Include DELETE operations in the publication."
            ) {
                Toggle("", isOn: $viewModel.publishDelete)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            PropertyRow(
                title: "Publish TRUNCATE",
                info: "Include TRUNCATE operations in the publication."
            ) {
                Toggle("", isOn: $viewModel.publishTruncate)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
    }
}
