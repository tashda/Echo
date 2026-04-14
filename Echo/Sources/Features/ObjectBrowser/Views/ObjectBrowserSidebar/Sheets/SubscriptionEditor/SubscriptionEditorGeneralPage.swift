import SwiftUI

struct SubscriptionEditorGeneralPage: View {
    @Bindable var viewModel: SubscriptionEditorViewModel

    var body: some View {
        Section("General") {
            if !viewModel.isEditing {
                PropertyRow(title: "Subscription Name") {
                    TextField("", text: $viewModel.subscriptionName, prompt: Text("my_subscription"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }

            PropertyRow(
                title: "Connection String",
                info: "The connection string to the publisher database. Uses libpq-style key=value format."
            ) {
                TextField(
                    "",
                    text: $viewModel.connectionString,
                    prompt: Text("host=remote dbname=source"),
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(2...4)
            }

            PropertyRow(
                title: "Publications",
                info: "Comma-separated list of publication names on the publisher to subscribe to."
            ) {
                TextField(
                    "",
                    text: $viewModel.publicationNames,
                    prompt: Text("pub1, pub2")
                )
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
            }
        }
    }
}
