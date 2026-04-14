import SwiftUI
import SQLServerKit

// MARK: - Memory, Processors, Security, Connections, Database Settings Pages

extension ServerEditorView {

    // MARK: - Memory

    @ViewBuilder
    func memoryPage() -> some View {
        Section("Server Memory") {
            configRow(
                title: "Min Server Memory (MB)",
                configName: SQLServerConfigurationName.minServerMemory
            )
            configRow(
                title: "Max Server Memory (MB)",
                configName: SQLServerConfigurationName.maxServerMemory
            )

            if let sys = viewModel.systemInfo {
                PropertyRow(title: "Physical Memory") {
                    Text(String(format: "%.1f GB", Double(sys.physicalMemoryMB) / 1024.0))
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }

        Section("Query Memory") {
            configRow(
                title: "Index Create Memory (KB)",
                configName: SQLServerConfigurationName.indexCreateMemory
            )
            configRow(
                title: "Min Memory per Query (KB)",
                configName: SQLServerConfigurationName.minMemoryPerQuery
            )
        }
    }

    // MARK: - Processors

    @ViewBuilder
    func processorsPage() -> some View {
        Section("Thread Management") {
            configRow(
                title: "Max Worker Threads",
                configName: SQLServerConfigurationName.maxWorkerThreads,
                info: "0 = auto-configured based on processor count"
            )
            configToggleRow(
                title: "Boost SQL Server Priority",
                configName: SQLServerConfigurationName.priorityBoost,
                info: "Runs SQL Server at a higher OS scheduling priority. Not recommended for most workloads."
            )
            configToggleRow(
                title: "Use Lightweight Pooling",
                configName: SQLServerConfigurationName.lightweightPooling,
                info: "Uses fiber mode scheduling instead of thread mode. Rarely needed."
            )
        }
    }

    // MARK: - Security

    @ViewBuilder
    func securityPage() -> some View {
        Section("Authentication") {
            PropertyRow(title: "Server Authentication") {
                Text(viewModel.securitySettings?.authenticationMode.rawValue ?? "Unknown")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Login Auditing") {
                Text(loginAuditDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }

        Section("Options") {
            configToggleRow(
                title: "C2 Audit Mode",
                configName: SQLServerConfigurationName.c2AuditMode,
                info: "Enables C2-level security auditing. Requires server restart."
            )
            configToggleRow(
                title: "Cross-database Ownership Chaining",
                configName: SQLServerConfigurationName.crossDbOwnershipChaining
            )
            configToggleRow(
                title: "Enable xp_cmdshell",
                configName: SQLServerConfigurationName.xpCmdshell,
                info: "Allows execution of operating system commands from SQL Server."
            )
        }
    }

    // MARK: - Connections

    @ViewBuilder
    func connectionsPage() -> some View {
        Section("Connections") {
            configRow(
                title: "Max Concurrent Connections",
                configName: SQLServerConfigurationName.userConnections,
                info: "0 = unlimited (auto-configured)"
            )
        }

        Section("Remote Connections") {
            configToggleRow(
                title: "Allow Remote Connections",
                configName: SQLServerConfigurationName.remoteAccess
            )
            configRow(
                title: "Remote Query Timeout (seconds)",
                configName: SQLServerConfigurationName.remoteQueryTimeout
            )
            configToggleRow(
                title: "Require Distributed Transactions",
                configName: SQLServerConfigurationName.remoteProcTrans
            )
        }
    }

    // MARK: - Database Settings

    @ViewBuilder
    func databaseSettingsPage() -> some View {
        Section("Default Locations") {
            PropertyRow(title: "Default Data") {
                TextField(
                    "",
                    text: Binding(
                        get: { viewModel.pendingDataPath ?? viewModel.serverInfo?.instanceDefaultDataPath ?? "" },
                        set: { viewModel.pendingDataPath = $0 }
                    ),
                    prompt: Text("C:\\Data")
                )
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
            }
            PropertyRow(title: "Default Log") {
                TextField(
                    "",
                    text: Binding(
                        get: { viewModel.pendingLogPath ?? viewModel.serverInfo?.instanceDefaultLogPath ?? "" },
                        set: { viewModel.pendingLogPath = $0 }
                    ),
                    prompt: Text("C:\\Log")
                )
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
            }
            PropertyRow(title: "Default Backup") {
                TextField(
                    "",
                    text: Binding(
                        get: { viewModel.pendingBackupPath ?? viewModel.serverInfo?.instanceDefaultBackupPath ?? "" },
                        set: { viewModel.pendingBackupPath = $0 }
                    ),
                    prompt: Text("C:\\Backup")
                )
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
            }
        }

        Section("Recovery") {
            configRow(
                title: "Recovery Interval (min)",
                configName: SQLServerConfigurationName.recoveryInterval
            )
        }

        Section("Backup") {
            configToggleRow(
                title: "Compress Backup",
                configName: SQLServerConfigurationName.backupCompressionDefault
            )
            configToggleRow(
                title: "Backup Checksum",
                configName: SQLServerConfigurationName.backupChecksumDefault
            )
        }

        Section("Database") {
            configRow(
                title: "Fill Factor (%)",
                configName: SQLServerConfigurationName.fillFactor,
                info: "0 = use default fill factor behavior"
            )
        }
    }

    // MARK: - Shared Helpers

    private func configRow(
        title: String,
        configName: String,
        info: String? = nil
    ) -> some View {
        let option = viewModel.configOption(for: configName)
        let subtitle = option.map { rangeDescription($0) }
        return PropertyRow(title: title, subtitle: subtitle, info: info) {
            HStack(spacing: SpacingTokens.xs) {
                TextField("", value: configValueBinding(for: configName), format: .number, prompt: Text("0"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                restartIndicator(for: configName)
            }
        }
    }

    private func configToggleRow(
        title: String,
        configName: String,
        info: String? = nil
    ) -> some View {
        let toggleBinding = Binding<Bool>(
            get: { viewModel.configValue(for: configName) != 0 },
            set: { viewModel.pendingChanges[configName] = $0 ? 1 : 0 }
        )
        return PropertyRow(title: title, info: info) {
            HStack(spacing: SpacingTokens.xs) {
                Toggle("", isOn: toggleBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
                restartIndicator(for: configName)
            }
        }
    }

    @ViewBuilder
    private func restartIndicator(for configName: String) -> some View {
        let option = viewModel.configOption(for: configName)
        let hasPending = viewModel.pendingChanges[configName] != nil
        if option?.isPendingRestart == true || (hasPending && option?.isDynamic == false) {
            Image(systemName: "arrow.clockwise.circle")
                .foregroundStyle(ColorTokens.Status.warning)
                .help("Requires SQL Server restart")
        }
    }

    private func rangeDescription(_ option: SQLServerConfigurationOption) -> String {
        "Range: \(option.minimum)–\(option.maximum)"
    }

    func configValueBinding(for configName: String) -> Binding<Int64> {
        Binding(
            get: { viewModel.configValue(for: configName) },
            set: { newValue in
                let original = viewModel.configurations.first(where: { $0.name == configName })?.configuredValue ?? 0
                if newValue != original {
                    viewModel.pendingChanges[configName] = newValue
                } else {
                    viewModel.pendingChanges.removeValue(forKey: configName)
                }
            }
        )
    }

    private var loginAuditDescription: String {
        guard let level = viewModel.securitySettings?.loginAuditLevel else { return "Unknown" }
        switch level {
        case .none: return "None"
        case .failedLoginsOnly: return "Failed logins only"
        case .successfulLoginsOnly: return "Successful logins only"
        case .both: return "Both failed and successful logins"
        }
    }
}
