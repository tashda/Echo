import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PgBackupGlobalsSheet: View {
    let connection: SavedConnection
    let password: String?
    let resolvedUsername: String?
    let customToolPath: String?
    let onDismiss: () -> Void

    @State private var outputPath: String = ""
    @State private var outputURL: URL?
    @State private var rolesOnly = false
    @State private var tablespacesOnly = false
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
            title: "Backup Globals",
            icon: "internaldrive",
            subtitle: "Back up global objects (roles and tablespaces).",
            primaryAction: "Backup",
            canSubmit: canExecute,
            isSubmitting: isRunning,
            errorMessage: isError ? statusText : nil,
            onSubmit: { await executeBackup() },
            onCancel: { onDismiss() }
        ) {
            Form {
                Section("Scope") {
                    PropertyRow(
                        title: "Roles Only",
                        info: "Dump only role definitions (CREATE ROLE statements). Excludes tablespace definitions."
                    ) {
                        Toggle("", isOn: $rolesOnly)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .onChange(of: rolesOnly) { _, newVal in
                                if newVal { tablespacesOnly = false }
                            }
                    }
                    PropertyRow(
                        title: "Tablespaces Only",
                        info: "Dump only tablespace definitions. Excludes role definitions."
                    ) {
                        Toggle("", isOn: $tablespacesOnly)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .onChange(of: tablespacesOnly) { _, newVal in
                                if newVal { rolesOnly = false }
                            }
                    }
                }

                Section("Destination") {
                    PropertyRow(title: "Output File") {
                        HStack(spacing: SpacingTokens.xs) {
                            TextField("", text: $outputPath, prompt: Text("/path/to/globals.sql"))
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
        .frame(minWidth: 480, idealWidth: 540, minHeight: 340)
    }

    private var commandPreview: String {
        guard !outputPath.isEmpty else { return "" }
        return buildCommand().joined(separator: " ")
    }

    private func selectOutputFile() {
        let panel = NSSavePanel()
        panel.title = "Backup Globals"
        panel.nameFieldStringValue = "globals.sql"
        panel.allowedContentTypes = [.data]
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            outputURL = url
            outputPath = url.path
        }
    }

    private func buildCommand() -> [String] {
        var args: [String] = ["pg_dumpall", "--globals-only"]
        if rolesOnly { args.append("--roles-only") }
        if tablespacesOnly { args.append("--tablespaces-only") }
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
