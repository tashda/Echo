import SwiftUI
import SQLServerKit

struct NewRouteSheet: View {
    let databaseName: String
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onDismiss: () -> Void

    @State private var name = ""
    @State private var address = ""
    @State private var serviceName = ""
    @State private var brokerInstance = ""
    @State private var lifetimeText = ""
    @State private var mirrorAddress = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    var canCreate: Bool {
        Self.isCreateValid(name: name, address: address, isCreating: isCreating)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Route") {
                    TextField("Name", text: $name, prompt: Text("e.g. OrderRoute"))
                    TextField("Address", text: $address, prompt: Text("e.g. TCP://server:4022 or LOCAL"))
                }

                Section("Options") {
                    TextField("Service Name", text: $serviceName, prompt: Text("e.g. //mycompany/OrderService"))
                    TextField("Broker Instance", text: $brokerInstance, prompt: Text("e.g. broker GUID"))
                    TextField("Lifetime (seconds)", text: $lifetimeText, prompt: Text("e.g. 3600 (optional)"))
                    TextField("Mirror Address", text: $mirrorAddress, prompt: Text("e.g. TCP://mirror:4022 (optional)"))
                }

                Section {
                    Label {
                        Text("A route specifies the network address for a Service Broker service. Routes direct messages to the correct SQL Server instance.")
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
        .frame(minWidth: 460, minHeight: 340)
        .frame(idealWidth: 500, idealHeight: 400)
    }

    // MARK: - Validation (Internal for testability)

    static func isCreateValid(name: String, address: String, isCreating: Bool) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isCreating
    }

    // MARK: - Submission

    private func create() async {
        isCreating = true
        errorMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let handle = AppDirector.shared.activityEngine.begin(
            "Create route \(trimmedName)",
            connectionSessionID: session.id
        )

        do {
            guard let mssql = session.session as? MSSQLSession else { return }
            let database = databaseName
            let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedServiceName = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedBrokerInstance = brokerInstance.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedMirrorAddress = mirrorAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            let lifetime = Int(lifetimeText.trimmingCharacters(in: .whitespacesAndNewlines))
            try await mssql.serviceBroker.createRoute(
                database: database,
                name: trimmedName,
                address: trimmedAddress,
                serviceName: trimmedServiceName.isEmpty ? nil : trimmedServiceName,
                brokerInstance: trimmedBrokerInstance.isEmpty ? nil : trimmedBrokerInstance,
                lifetime: lifetime,
                mirrorAddress: trimmedMirrorAddress.isEmpty ? nil : trimmedMirrorAddress
            )
            handle.succeed()
            environmentState.notificationEngine?.post(
                category: .maintenanceCompleted,
                message: "Route \(trimmedName) created."
            )
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            handle.fail(error.localizedDescription)
            isCreating = false
        }
    }
}
