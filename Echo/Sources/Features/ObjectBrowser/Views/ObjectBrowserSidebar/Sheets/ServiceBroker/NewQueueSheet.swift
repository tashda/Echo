import SwiftUI
import SQLServerKit

struct NewQueueSheet: View {
    let databaseName: String
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onDismiss: () -> Void

    @State private var schema = "dbo"
    @State private var name = ""
    @State private var statusEnabled = true
    @State private var retentionEnabled = false
    @State private var activationEnabled = false
    @State private var activationProcedure = ""
    @State private var maxQueueReaders = 1
    @State private var executeAs = ""
    @State private var poisonMessageHandling = true
    @State private var isCreating = false
    @State private var errorMessage: String?

    var canCreate: Bool {
        Self.isCreateValid(name: name, isCreating: isCreating)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Queue") {
                    TextField("Schema", text: $schema, prompt: Text("e.g. dbo"))
                    TextField("Name", text: $name, prompt: Text("e.g. OrderQueue"))
                }

                Section("Status") {
                    Toggle("Queue Enabled", isOn: $statusEnabled)
                    Toggle("Retention", isOn: $retentionEnabled)
                    Toggle("Poison Message Handling", isOn: $poisonMessageHandling)
                }

                Section("Activation") {
                    Toggle("Activation Enabled", isOn: $activationEnabled)

                    if activationEnabled {
                        TextField(
                            "Stored Procedure",
                            text: $activationProcedure,
                            prompt: Text("e.g. dbo.ProcessOrders")
                        )
                        Stepper(
                            "Max Queue Readers: \(maxQueueReaders)",
                            value: $maxQueueReaders,
                            in: 1...32
                        )
                        TextField(
                            "Execute As",
                            text: $executeAs,
                            prompt: Text("e.g. dbo (leave empty for SELF)")
                        )
                    }
                }

                Section {
                    Label {
                        Text("A queue stores messages for Service Broker conversations. Activation automatically starts stored procedures when messages arrive.")
                            .font(TypographyTokens.formDescription)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
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
        .frame(minWidth: 480, minHeight: 380)
        .frame(idealWidth: 520, idealHeight: 440)
    }

    // MARK: - Validation (Internal for testability)

    static func isCreateValid(name: String, isCreating: Bool) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreating
    }

    // MARK: - Submission

    private func create() async {
        isCreating = true
        errorMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSchema = schema.trimmingCharacters(in: .whitespacesAndNewlines)
        let handle = AppDirector.shared.activityEngine.begin(
            "Create queue \(trimmedSchema).\(trimmedName)",
            connectionSessionID: session.id
        )

        do {
            guard let mssql = session.session as? MSSQLSession else { return }
            let database = databaseName
            let trimmedExecuteAs = executeAs.trimmingCharacters(in: .whitespacesAndNewlines)
            let options = QueueCreationOptions(
                status: statusEnabled,
                retention: retentionEnabled,
                activationEnabled: activationEnabled,
                activationProcedure: activationProcedure.trimmingCharacters(in: .whitespacesAndNewlines),
                maxQueueReaders: maxQueueReaders,
                executeAs: trimmedExecuteAs.isEmpty ? nil : trimmedExecuteAs,
                poisonMessageHandling: poisonMessageHandling
            )
            try await mssql.serviceBroker.createQueue(
                database: database,
                schema: trimmedSchema.isEmpty ? "dbo" : trimmedSchema,
                name: trimmedName,
                options: options
            )
            handle.succeed()
            environmentState.notificationEngine?.post(
                category: .maintenanceCompleted,
                message: "Queue \(trimmedSchema).\(trimmedName) created."
            )
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            handle.fail(error.localizedDescription)
            isCreating = false
        }
    }
}
