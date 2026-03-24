import SwiftUI

struct CreateSnapshotSheet: View {
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onDismiss: () -> Void

    @State private var sourceDatabase = ""
    @State private var snapshotName = ""
    @State private var databaseList: [String] = []
    @State private var isCreating = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    var canCreate: Bool {
        !sourceDatabase.isEmpty
            && !snapshotName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isCreating
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Source") {
                    Picker("Database", selection: $sourceDatabase) {
                        Text("Select a database").tag("")
                        ForEach(databaseList, id: \.self) { db in
                            Text(db).tag(db)
                        }
                    }
                    .disabled(isLoading)
                }

                Section("Snapshot") {
                    TextField("", text: $snapshotName, prompt: Text("e.g. AdventureWorks_Snapshot_20260324"))
                }

                Section {
                    Label {
                        Text("A database snapshot captures a point-in-time, read-only view of the source database. You can later revert the source database to this snapshot.")
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
                    Task { await createSnapshot() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canCreate)
            }
            .padding(SpacingTokens.md)
        }
        .frame(minWidth: 440, minHeight: 280)
        .frame(idealWidth: 480, idealHeight: 320)
        .task {
            await loadDatabases()
        }
        .onChange(of: sourceDatabase) { _, newValue in
            if !newValue.isEmpty && snapshotName.isEmpty {
                generateSnapshotName(from: newValue)
            }
        }
    }

    // MARK: - Validation & Helpers (Internal for testability)

    static func isCreateValid(sourceDatabase: String, snapshotName: String, isCreating: Bool) -> Bool {
        !sourceDatabase.isEmpty
            && !snapshotName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isCreating
    }

    static func generateSnapshotName(from database: String, date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "\(database)_Snapshot_\(formatter.string(from: date))"
    }

    private func generateSnapshotName(from database: String) {
        snapshotName = Self.generateSnapshotName(from: database)
    }

    private func loadDatabases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            databaseList = try await session.session.listDatabases()
            // Auto-select current database if available
            if let current = try? await session.session.currentDatabaseName(), !current.isEmpty {
                sourceDatabase = current
                generateSnapshotName(from: current)
            }
        } catch {
            databaseList = []
        }
    }

    private func createSnapshot() async {
        isCreating = true
        errorMessage = nil
        let handle = AppDirector.shared.activityEngine.begin(
            "Create snapshot \(snapshotName)",
            connectionSessionID: session.id
        )

        do {
            let trimmedName = snapshotName.trimmingCharacters(in: .whitespacesAndNewlines)
            try await session.session.createDatabaseSnapshot(name: trimmedName, sourceDatabase: sourceDatabase)
            handle.succeed()
            environmentState.notificationEngine?.post(
                category: .maintenanceCompleted,
                message: "Snapshot \(trimmedName) created from \(sourceDatabase)."
            )
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            handle.fail(error.localizedDescription)
            isCreating = false
        }
    }
}
