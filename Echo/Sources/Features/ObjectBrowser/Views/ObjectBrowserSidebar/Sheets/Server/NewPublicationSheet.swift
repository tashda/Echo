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
        VStack(spacing: 0) {
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
            .padding(.horizontal, SpacingTokens.md2)
            .padding(.vertical, SpacingTokens.sm2)
            .background(.bar)
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
