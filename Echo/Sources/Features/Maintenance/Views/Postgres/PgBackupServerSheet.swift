import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PgBackupServerSheet: View {
    let connection: SavedConnection
    let password: String?
    let resolvedUsername: String?
    let customToolPath: String?
    let onDismiss: () -> Void

    @State private var outputPath: String = ""
    @State private var outputURL: URL?
    @State private var cleanBeforeRestore = false
    @State private var ifExists = false
    @State private var noOwner = false
    @State private var isRunning = false
    @State private var statusMessage: String?
    @State private var isError = false

    private var canExecute: Bool {
        !outputPath.isEmpty && !isRunning
    }

    private var statusText: String? {
        if let status = statusMessage {
            return status
        }
        return nil
    }

    var body: some View {
        SheetLayout(
            title: "Backup Server",
            icon: "server.rack",
            subtitle: "Back up the entire PostgreSQL server.",
            primaryAction: "Backup",
            canSubmit: canExecute,
            isSubmitting: isRunning,
            errorMessage: isError ? statusText : nil,
            onSubmit: { await executeBackup() },
            onCancel: { onDismiss() }
        ) {
            Form {
                Section("Options") {
                    PropertyRow(
                        title: "Clean (DROP)",
                        info: "Include DROP commands before CREATE commands to clean existing objects before restore."
                    ) {
                        Toggle("", isOn: $cleanBeforeRestore)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    PropertyRow(
                        title: "IF EXISTS",
                        info: "Add IF EXISTS to DROP commands. Only effective when Clean is enabled."
                    ) {
                        Toggle("", isOn: $ifExists)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    PropertyRow(
                        title: "No Owner",
                        info: "Do not output ALTER OWNER statements to match ownership of the original database."
                    ) {
                        Toggle("", isOn: $noOwner)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }

                Section("Destination") {
                    PropertyRow(title: "Output File") {
                        HStack(spacing: SpacingTokens.xs) {
                            TextField("", text: $outputPath, prompt: Text("/path/to/server_backup.sql"))
                                .textFieldStyle(.plain)
                                .font(TypographyTokens.monospaced)
                                .truncationMode(.head)
                            Button("Browse") { selectOutputFile() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }

                if !commandPreview.isEmpty {
                    SQLPreviewSection(sql: commandPreview)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 380)
    }

    private var commandPreview: String {
        guard !outputPath.isEmpty else { return "" }
        return buildCommand().joined(separator: " ")
    }

    private func selectOutputFile() {
        let panel = NSSavePanel()
        panel.title = "Backup Server"
        panel.nameFieldStringValue = "server_backup.sql"
        panel.allowedContentTypes = [.data]
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            outputURL = url
            outputPath = url.path
        }
    }

    private func buildCommand() -> [String] {
        var args: [String] = ["pg_dumpall"]
        if cleanBeforeRestore { args.append("--clean") }
        if ifExists { args.append("--if-exists") }
        if noOwner { args.append("--no-owner") }
        args.append(contentsOf: ["--file", outputPath])
        args.append(contentsOf: buildConnectionArgs())
        return args
    }

    private func buildConnectionArgs() -> [String] {
        var args: [String] = []
        args.append(contentsOf: ["--host", connection.host])
        args.append(contentsOf: ["--port", String(connection.port)])
        let user = resolvedUsername ?? connection.username
        if !user.isEmpty { args.append(contentsOf: ["--username", user]) }
        args.append("--no-password")
        return args
    }

    private func executeBackup() async {
        guard canExecute else { return }
        guard let pgDumpAll = PostgresToolLocator.pgDumpAllURL(customPath: customToolPath) else {
            statusMessage = "pg_dumpall not found. Install PostgreSQL or set a custom tool path."
            isError = true
            return
        }

        isRunning = true
        isError = false
        statusMessage = "Running\u{2026}"

        var args = buildCommand()
        args.removeFirst() // Remove "pg_dumpall" since we pass the executable URL

        var env: [String: String] = [:]
        if let pw = password, !pw.isEmpty { env["PGPASSWORD"] = pw }

        let runner = PostgresProcessRunner()
        do {
            let result = try await runner.run(executable: pgDumpAll, arguments: Array(args), environment: env)
            if result.exitCode == 0 {
                statusMessage = "Backup completed successfully"
                isError = false
            } else {
                let msg = result.stderrLines.joined(separator: "\n")
                statusMessage = msg.isEmpty ? "Backup failed (exit code \(result.exitCode))" : msg
                isError = true
            }
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }

        isRunning = false
    }
}
