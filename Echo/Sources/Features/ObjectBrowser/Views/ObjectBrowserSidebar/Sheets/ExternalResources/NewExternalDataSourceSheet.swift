import SwiftUI
import SQLServerKit

struct NewExternalDataSourceSheet: View {
    let databaseName: String
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onDismiss: () -> Void

    @State private var name = ""
    @State private var location = ""
    @State private var sourceType: ExternalDataSourceType = .hadoop
    @State private var credential = ""
    @State private var resourceManagerLocation = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    var canCreate: Bool {
        Self.isCreateValid(name: name, location: location, isCreating: isCreating)
    }

    var body: some View {
        SheetLayout(
            title: "New External Data Source",
            icon: "externaldrive.connected.to.line.below",
            subtitle: "Create a connection to an external data source.",
            primaryAction: "Create",
            canSubmit: canCreate,
            isSubmitting: isCreating,
            errorMessage: errorMessage,
            onSubmit: { await create() },
            onCancel: { onDismiss() }
        ) {
            Form {
                Section("Data Source") {
                    PropertyRow(title: "Name") {
                        TextField("", text: $name, prompt: Text("e.g. MyHadoopCluster"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Location", info: "The connection string or URI for the external data source.") {
                        TextField("", text: $location, prompt: Text("e.g. hdfs://namenode:8020"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Type", info: "The type of external data source determines the available connection options.") {
                        Picker("", selection: $sourceType) {
                            Text("Hadoop").tag(ExternalDataSourceType.hadoop)
                            Text("Blob Storage").tag(ExternalDataSourceType.blobStorage)
                            Text("RDBMS").tag(ExternalDataSourceType.rdbms)
                            Text("Shard Map Manager").tag(ExternalDataSourceType.shardMapManager)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }

                Section("Authentication") {
                    PropertyRow(title: "Credential", info: "A database-scoped credential used to authenticate to the external data source.") {
                        TextField("", text: $credential, prompt: Text("e.g. MyCredential"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Advanced") {
                    PropertyRow(title: "Resource Manager", info: "The Hadoop YARN Resource Manager location for pushdown computation.") {
                        TextField("", text: $resourceManagerLocation, prompt: Text("e.g. namenode:8032"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 480, minHeight: 320)
        .frame(idealWidth: 520, idealHeight: 380)
    }

    // MARK: - Validation (Internal for testability)

    static func isCreateValid(name: String, location: String, isCreating: Bool) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isCreating
    }

    private func create() async {
        isCreating = true
        errorMessage = nil
        let handle = AppDirector.shared.activityEngine.begin(
            "Create external data source \(name)",
            connectionSessionID: session.id
        )

        do {
            guard let mssql = session.session as? MSSQLSession else { return }
            let trimmedCredential = credential.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedRML = resourceManagerLocation.trimmingCharacters(in: .whitespacesAndNewlines)
            try await mssql.polyBase.createExternalDataSource(
                database: databaseName,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                type: sourceType,
                credential: trimmedCredential.isEmpty ? nil : trimmedCredential,
                resourceManagerLocation: trimmedRML.isEmpty ? nil : trimmedRML
            )
            handle.succeed()
            environmentState.notificationEngine?.post(
                category: .maintenanceCompleted,
                message: "External data source \(name) created."
            )
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            handle.fail(error.localizedDescription)
            isCreating = false
        }
    }
}
