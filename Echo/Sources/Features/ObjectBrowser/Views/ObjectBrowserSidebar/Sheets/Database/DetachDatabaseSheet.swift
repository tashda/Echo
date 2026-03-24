import SwiftUI

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
        VStack(spacing: 0) {
            Form {
                Section {
                    LabeledContent("Database") {
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

            Divider()

            HStack {
                if let error = errorMessage {
                    Text(error)
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Status.error)
                        .lineLimit(2)
                }
                Spacer()
                if isDetaching {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Cancel") { onDismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Button("Detach", role: .destructive) {
                    Task { await detach() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(isDetaching)
            }
            .padding(SpacingTokens.md)
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
            if dropConnections {
                // Set single user mode to kick off other connections
                _ = try await session.session.executeUpdate("ALTER DATABASE [\(databaseName)] SET SINGLE_USER WITH ROLLBACK IMMEDIATE")
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
