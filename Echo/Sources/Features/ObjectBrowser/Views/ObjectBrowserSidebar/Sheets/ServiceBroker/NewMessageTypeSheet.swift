import SwiftUI
import SQLServerKit

struct NewMessageTypeSheet: View {
    let databaseName: String
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onDismiss: () -> Void

    @State private var name = ""
    @State private var validationType = "NONE"
    @State private var schemaCollection = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    private static let validationOptions = ["NONE", "EMPTY", "WELL_FORMED_XML", "VALID_XML"]

    var canCreate: Bool {
        Self.isCreateValid(name: name, isCreating: isCreating)
    }

    var body: some View {
        SheetLayout(
            title: "New Message Type",
            icon: "envelope",
            subtitle: "Define a Service Broker message type.",
            primaryAction: "Create",
            canSubmit: canCreate,
            isSubmitting: isCreating,
            errorMessage: errorMessage,
            onSubmit: { await create() },
            onCancel: { onDismiss() }
        ) {
            Form {
                Section("Message Type") {
                    PropertyRow(title: "Name") {
                        TextField("", text: $name, prompt: Text("e.g. OrderMessage"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Validation") {
                    PropertyRow(title: "Validation", info: "Determines how message content is validated. NONE accepts any content, XML options enforce structure.") {
                        Picker("", selection: $validationType) {
                            Text("None").tag("NONE")
                            Text("Empty").tag("EMPTY")
                            Text("Well-Formed XML").tag("WELL_FORMED_XML")
                            Text("Valid XML").tag("VALID_XML")
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    if validationType == "VALID_XML" {
                        PropertyRow(title: "Schema Collection", info: "The XML schema collection used to validate message content.") {
                            TextField("", text: $schemaCollection, prompt: Text("e.g. dbo.MySchemaCollection"))
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 440, minHeight: 260)
        .frame(idealWidth: 480, idealHeight: 300)
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
        let handle = AppDirector.shared.activityEngine.begin(
            "Create message type \(trimmedName)",
            connectionSessionID: session.id
        )

        do {
            guard let mssql = session.session as? MSSQLSession else { return }
            let database = databaseName
            let validation: MessageTypeValidation = switch validationType {
            case "EMPTY": .empty
            case "WELL_FORMED_XML": .wellFormedXML
            case "VALID_XML": .validXML(schemaCollection: schemaCollection.trimmingCharacters(in: .whitespacesAndNewlines))
            default: .none
            }
            try await mssql.serviceBroker.createMessageType(
                database: database,
                name: trimmedName,
                validation: validation
            )
            handle.succeed()
            environmentState.notificationEngine?.post(
                category: .maintenanceCompleted,
                message: "Message type \(trimmedName) created."
            )
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            handle.fail(error.localizedDescription)
            isCreating = false
        }
    }
}
