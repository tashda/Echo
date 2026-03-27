import SwiftUI
import SQLServerKit

/// Sheet for creating a new replication subscription.
struct NewSubscriptionSheet: View {
    let publications: [SQLServerPublication]
    let session: ConnectionSession
    let onCreated: () -> Void
    let onDismiss: () -> Void

    @State private var selectedPublication: String = ""
    @State private var subscriberServer = ""
    @State private var subscriberDB = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    private var canCreate: Bool {
        !selectedPublication.isEmpty
            && !subscriberServer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !subscriberDB.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isCreating
    }

    var body: some View {
        SheetLayout(
            title: "New Subscription",
            icon: "arrow.down.circle",
            subtitle: "Subscribe to a replication publication.",
            primaryAction: "Create",
            canSubmit: canCreate,
            isSubmitting: isCreating,
            errorMessage: errorMessage,
            onSubmit: { await create() },
            onCancel: { onDismiss() }
        ) {
            Form {
                Section("Subscription") {
                    PropertyRow(title: "Publication") {
                        Picker("", selection: $selectedPublication) {
                            Text("Select a publication").tag("")
                            ForEach(publications) { pub in
                                Text(pub.name).tag(pub.name)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    PropertyRow(title: "Subscriber Server") {
                        TextField("", text: $subscriberServer, prompt: Text("e.g. SQLSERVER02"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }

                    PropertyRow(title: "Subscriber Database") {
                        TextField("", text: $subscriberDB, prompt: Text("e.g. SubscriberDB"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 300)
    }

    private func create() async {
        isCreating = true
        errorMessage = nil
        let trimmedServer = subscriberServer.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDB = subscriberDB.trimmingCharacters(in: .whitespacesAndNewlines)
        let handle = AppDirector.shared.activityEngine.begin(
            "Create subscription to \(selectedPublication)",
            connectionSessionID: session.id
        )

        do {
            guard let mssql = session.session as? MSSQLSession else { return }
            try await mssql.replication.createSubscription(
                publicationName: selectedPublication,
                subscriberServer: trimmedServer,
                subscriberDB: trimmedDB
            )
            handle.succeed()
            onCreated()
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            handle.fail(error.localizedDescription)
            isCreating = false
        }
    }
}
