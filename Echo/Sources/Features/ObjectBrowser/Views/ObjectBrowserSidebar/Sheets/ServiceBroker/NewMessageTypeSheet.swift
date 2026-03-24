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
        VStack(spacing: 0) {
            Form {
                Section("Message Type") {
                    TextField("Name", text: $name, prompt: Text("e.g. OrderMessage"))
                }

                Section("Validation") {
                    Picker("Validation", selection: $validationType) {
                        Text("None").tag("NONE")
                        Text("Empty").tag("EMPTY")
                        Text("Well-Formed XML").tag("WELL_FORMED_XML")
                        Text("Valid XML").tag("VALID_XML")
                    }

                    if validationType == "VALID_XML" {
                        TextField(
                            "Schema Collection",
                            text: $schemaCollection,
                            prompt: Text("e.g. dbo.MySchemaCollection")
                        )
                    }
                }

                Section {
                    Label {
                        Text("A message type defines the format of messages used in Service Broker conversations. Validation ensures messages conform to the expected structure.")
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
