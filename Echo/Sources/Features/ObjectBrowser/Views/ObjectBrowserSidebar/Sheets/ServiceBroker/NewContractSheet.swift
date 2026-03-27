import SwiftUI
import SQLServerKit

struct NewContractSheet: View {
    let databaseName: String
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onDismiss: () -> Void

    @State private var name = ""
    @State private var messageUsages: [(id: UUID, messageType: String, sentBy: String)] = [
        (UUID(), "", "ANY")
    ]
    @State private var isCreating = false
    @State private var errorMessage: String?

    private static let sentByOptions = ["INITIATOR", "TARGET", "ANY"]

    var canCreate: Bool {
        Self.isCreateValid(name: name, messageUsages: messageUsages, isCreating: isCreating)
    }

    var body: some View {
        SheetLayout(
            title: "New Contract",
            icon: "doc.text.magnifyingglass",
            subtitle: "Specify which message types a conversation uses.",
            primaryAction: "Create",
            canSubmit: canCreate,
            isSubmitting: isCreating,
            errorMessage: errorMessage,
            onSubmit: { await create() },
            onCancel: { onDismiss() }
        ) {
            Form {
                Section("Contract") {
                    TextField("Name", text: $name, prompt: Text("e.g. OrderContract"))
                }

                Section("Message Usages") {
                    ForEach(Array(messageUsages.enumerated()), id: \.element.id) { index, _ in
                        HStack(spacing: SpacingTokens.sm) {
                            TextField(
                                "Message Type",
                                text: messageTypeBinding(at: index),
                                prompt: Text("e.g. OrderMessage")
                            )

                            Picker("Sent By", selection: sentByBinding(at: index)) {
                                Text("Initiator").tag("INITIATOR")
                                Text("Target").tag("TARGET")
                                Text("Any").tag("ANY")
                            }
                            .frame(width: 140)

                            Button {
                                removeUsage(at: index)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .disabled(messageUsages.count <= 1)
                        }
                    }

                    Button("Add Message Usage") {
                        messageUsages.append((UUID(), "", "ANY"))
                    }
                    .buttonStyle(.borderless)
                }

                Section {
                    Label {
                        Text("A contract specifies which message types a conversation uses and which side (initiator or target) can send each type.")
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
        .frame(minWidth: 500, minHeight: 340)
        .frame(idealWidth: 540, idealHeight: 400)
    }

    // MARK: - Bindings

    private func messageTypeBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { messageUsages[index].messageType },
            set: { messageUsages[index].messageType = $0 }
        )
    }

    private func sentByBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { messageUsages[index].sentBy },
            set: { messageUsages[index].sentBy = $0 }
        )
    }

    private func removeUsage(at index: Int) {
        guard messageUsages.count > 1 else { return }
        messageUsages.remove(at: index)
    }

    // MARK: - Validation (Internal for testability)

    static func isCreateValid(
        name: String,
        messageUsages: [(id: UUID, messageType: String, sentBy: String)],
        isCreating: Bool
    ) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && messageUsages.contains(where: {
                !$0.messageType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            })
            && !isCreating
    }

    // MARK: - Submission

    private func create() async {
        isCreating = true
        errorMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let handle = AppDirector.shared.activityEngine.begin(
            "Create contract \(trimmedName)",
            connectionSessionID: session.id
        )

        do {
            guard let mssql = session.session as? MSSQLSession else { return }
            let database = databaseName
            let usages: [(messageType: String, sentBy: ContractSentBy)] = messageUsages
                .filter { !$0.messageType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { usage in
                    let sentBy = ContractSentBy(rawValue: usage.sentBy) ?? .any
                    return (usage.messageType.trimmingCharacters(in: .whitespacesAndNewlines), sentBy)
                }
            try await mssql.serviceBroker.createContract(
                database: database,
                name: trimmedName,
                messageUsages: usages
            )
            handle.succeed()
            environmentState.notificationEngine?.post(
                category: .maintenanceCompleted,
                message: "Contract \(trimmedName) created."
            )
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            handle.fail(error.localizedDescription)
            isCreating = false
        }
    }
}
