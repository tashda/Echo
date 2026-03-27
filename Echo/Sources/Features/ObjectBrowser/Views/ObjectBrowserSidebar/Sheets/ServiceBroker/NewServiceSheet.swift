import SwiftUI
import SQLServerKit

struct NewServiceSheet: View {
    let databaseName: String
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onDismiss: () -> Void

    @State private var name = ""
    @State private var queueName = ""
    @State private var contracts: [(id: UUID, name: String)] = []
    @State private var isCreating = false
    @State private var errorMessage: String?

    var canCreate: Bool {
        Self.isCreateValid(name: name, queueName: queueName, isCreating: isCreating)
    }

    var body: some View {
        SheetLayout(
            title: "New Service",
            icon: "point.3.connected.trianglepath.dotted",
            subtitle: "Create a Service Broker endpoint bound to a queue.",
            primaryAction: "Create",
            canSubmit: canCreate,
            isSubmitting: isCreating,
            errorMessage: errorMessage,
            onSubmit: { await create() },
            onCancel: { onDismiss() }
        ) {
            Form {
                Section("Service") {
                    TextField("Name", text: $name, prompt: Text("e.g. OrderService"))
                    TextField("Queue", text: $queueName, prompt: Text("e.g. dbo.MyQueue"))
                }

                Section("Contracts") {
                    ForEach(Array(contracts.enumerated()), id: \.element.id) { index, _ in
                        HStack(spacing: SpacingTokens.sm) {
                            TextField(
                                "Contract",
                                text: contractNameBinding(at: index),
                                prompt: Text("e.g. OrderContract")
                            )

                            Button {
                                removeContract(at: index)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    Button("Add Contract") {
                        contracts.append((UUID(), ""))
                    }
                    .buttonStyle(.borderless)
                }

                Section {
                    Label {
                        Text("A service defines an endpoint for Service Broker conversations. It is bound to a queue where incoming messages are stored, and may use one or more contracts.")
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
        }
        .frame(minWidth: 460, minHeight: 300)
        .frame(idealWidth: 500, idealHeight: 360)
    }

    // MARK: - Bindings

    private func contractNameBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { contracts[index].name },
            set: { contracts[index].name = $0 }
        )
    }

    private func removeContract(at index: Int) {
        contracts.remove(at: index)
    }

    // MARK: - Validation (Internal for testability)

    static func isCreateValid(name: String, queueName: String, isCreating: Bool) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !queueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isCreating
    }

    // MARK: - Submission

    private func create() async {
        isCreating = true
        errorMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let handle = AppDirector.shared.activityEngine.begin(
            "Create service \(trimmedName)",
            connectionSessionID: session.id
        )

        do {
            guard let mssql = session.session as? MSSQLSession else { return }
            let database = databaseName
            let trimmedQueue = queueName.trimmingCharacters(in: .whitespacesAndNewlines)
            let contractNames = contracts
                .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            try await mssql.serviceBroker.createService(
                database: database,
                name: trimmedName,
                queue: trimmedQueue,
                contracts: contractNames
            )
            handle.succeed()
            environmentState.notificationEngine?.post(
                category: .maintenanceCompleted,
                message: "Service \(trimmedName) created."
            )
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            handle.fail(error.localizedDescription)
            isCreating = false
        }
    }
}
