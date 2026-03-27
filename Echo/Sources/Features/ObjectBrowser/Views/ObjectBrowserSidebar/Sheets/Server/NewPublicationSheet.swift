import SwiftUI
import SQLServerKit

/// Sheet for creating a new replication publication.
struct NewPublicationSheet: View {
    let databaseName: String
    let session: ConnectionSession
    let onCreated: () -> Void
    let onDismiss: () -> Void

    @State private var name = ""
    @State private var publicationType: SQLServerPublicationType = .transactional
    @State private var isCreating = false
    @State private var errorMessage: String?

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreating
    }

    var body: some View {
        SheetLayout(
            title: "New Publication",
            icon: "arrow.up.circle",
            subtitle: "Create a publication for replication.",
            primaryAction: "Create",
            canSubmit: canCreate,
            isSubmitting: isCreating,
            errorMessage: errorMessage,
            onSubmit: { await create() },
            onCancel: { onDismiss() }
        ) {
            Form {
                Section("Publication") {
                    PropertyRow(title: "Name") {
                        TextField("", text: $name, prompt: Text("e.g. MyPublication"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }

                    PropertyRow(title: "Type") {
                        Picker("", selection: $publicationType) {
                            Text("Transactional").tag(SQLServerPublicationType.transactional)
                            Text("Snapshot").tag(SQLServerPublicationType.snapshot)
                            Text("Merge").tag(SQLServerPublicationType.merge)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 240)
    }

    private func create() async {
        isCreating = true
        errorMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let handle = AppDirector.shared.activityEngine.begin(
            "Create publication \(trimmedName)",
            connectionSessionID: session.id
        )

        do {
            guard let mssql = session.session as? MSSQLSession else { return }
            try await mssql.replication.createPublication(
                name: trimmedName,
                type: publicationType,
                database: databaseName
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
