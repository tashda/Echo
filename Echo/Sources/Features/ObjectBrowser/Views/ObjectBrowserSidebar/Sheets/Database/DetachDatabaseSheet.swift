import SwiftUI
import SQLServerKit

struct DetachDatabaseSheet: View {
    let databaseName: String
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onDismiss: () -> Void

    @State private var updateStatistics = true
    @State private var dropConnections = false
    @State private var isDetaching = false
    @State private var errorMessage: String?

    var body: some View {
        SheetLayout(
            title: "Detach Database",
            icon: "eject",
            subtitle: "Detach a database from the server.",
            primaryAction: "Detach",
            canSubmit: !isDetaching,
            isSubmitting: isDetaching,
            errorMessage: errorMessage,
            onSubmit: { await detach() },
            onCancel: { onDismiss() }
        ) {
            Form {
                Section {
                    PropertyRow(title: "Database") {
                        Text(databaseName)
                            .foregroundStyle(ColorTokens.Text.primary)
                            .fontWeight(.medium)
                    }
                }

                Section("Options") {
                    Toggle("Update statistics before detach", isOn: $updateStatistics)
                    Toggle("Drop active connections", isOn: $dropConnections)
                }

                Section {
                    Label {
                        Text("Detaching a database removes it from the server but preserves its data and log files. The files can later be reattached using Attach Database.")
                            .font(TypographyTokens.formDescription)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(ColorTokens.Status.warning)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 440, minHeight: 280)
        .frame(idealWidth: 480, idealHeight: 320)
    }

    // MARK: - Helpers (Internal for testability)

    /// System databases cannot be detached.
    static let systemDatabases: Set<String> = ["master", "tempdb", "model", "msdb"]

    static func isSystemDatabase(_ name: String) -> Bool {
        systemDatabases.contains(name.lowercased())
    }

    static func shouldSkipChecks(updateStatistics: Bool) -> Bool {
        !updateStatistics
    }

    private func detach() async {
        isDetaching = true
        errorMessage = nil
        let handle = AppDirector.shared.activityEngine.begin("Detach \(databaseName)", connectionSessionID: session.id)

        do {
            let skipChecks = !updateStatistics
            if dropConnections, let mssql = session.session as? MSSQLSession {
                // Set single user mode to kick off other connections
                _ = try await mssql.admin.setDatabaseSingleUser(name: databaseName, rollbackImmediate: true)
            }
            try await session.session.detachDatabase(name: databaseName, skipChecks: skipChecks)
            handle.succeed()
            await environmentState.refreshDatabaseStructure(for: session.id)
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            handle.fail(error.localizedDescription)
            isDetaching = false
        }
    }
}
