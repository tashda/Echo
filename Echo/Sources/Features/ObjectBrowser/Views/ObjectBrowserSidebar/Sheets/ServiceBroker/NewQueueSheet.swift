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
        SheetLayout(
            title: "New Queue",
            icon: "tray.2",
            subtitle: "Create a Service Broker message queue.",
            primaryAction: "Create",
            canSubmit: canCreate,
            isSubmitting: isCreating,
            errorMessage: errorMessage,
            onSubmit: { await create() },
            onCancel: { onDismiss() }
        ) {
            Form {
                Section("Queue") {
                    PropertyRow(title: "Schema") {
                        TextField("", text: $schema, prompt: Text("e.g. dbo"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Name") {
                        TextField("", text: $name, prompt: Text("e.g. OrderQueue"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Status") {
                    PropertyRow(title: "Queue Enabled", info: "When disabled, messages can be sent to the queue but cannot be received.") {
                        Toggle("", isOn: $statusEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    PropertyRow(title: "Retention", info: "When enabled, all messages remain in the queue until the conversation ends.") {
                        Toggle("", isOn: $retentionEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    PropertyRow(title: "Poison Message Handling", info: "When enabled, messages that cause transaction rollbacks 5 times are automatically moved to a poison message queue.") {
                        Toggle("", isOn: $poisonMessageHandling)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }

                Section("Activation") {
                    PropertyRow(title: "Activation Enabled", info: "When enabled, SQL Server automatically starts stored procedures to process messages.") {
                        Toggle("", isOn: $activationEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    if activationEnabled {
                        PropertyRow(title: "Stored Procedure", info: "The stored procedure to execute when messages arrive in the queue.") {
                            TextField("", text: $activationProcedure, prompt: Text("e.g. dbo.ProcessOrders"))
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                        }
                        PropertyRow(title: "Max Queue Readers", info: "Maximum number of concurrent instances of the activation procedure (1\u{2013}32).") {
                            Stepper("\(maxQueueReaders)", value: $maxQueueReaders, in: 1...32)
                        }
                        PropertyRow(title: "Execute As", info: "The security context under which the activation procedure runs. Leave empty to use SELF.") {
                            TextField("", text: $executeAs, prompt: Text("e.g. dbo"))
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
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
