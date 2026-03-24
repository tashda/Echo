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
        VStack(spacing: 0) {
            Form {
                Section("Data Source") {
                    TextField("Name", text: $name, prompt: Text("e.g. MyHadoopCluster"))
                    TextField("Location", text: $location, prompt: Text("e.g. hdfs://namenode:8020"))
                    Picker("Type", selection: $sourceType) {
                        Text("Hadoop").tag(ExternalDataSourceType.hadoop)
                        Text("Blob Storage").tag(ExternalDataSourceType.blobStorage)
                        Text("RDBMS").tag(ExternalDataSourceType.rdbms)
                        Text("Shard Map Manager").tag(ExternalDataSourceType.shardMapManager)
                    }
                }

                Section("Authentication") {
                    TextField("Credential", text: $credential, prompt: Text("e.g. MyCredential"))
                }

                Section("Advanced") {
                    TextField("Resource Manager Location", text: $resourceManagerLocation, prompt: Text("e.g. namenode:8032"))
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                if let error = errorMessage {
                    Text(error)
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Status.error)
                        .lineLimit(2)
                }
                Spacer()
                if isCreating {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Cancel") { onDismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Button("Create") {
                    Task { await create() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canCreate)
            }
            .padding(SpacingTokens.md)
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
