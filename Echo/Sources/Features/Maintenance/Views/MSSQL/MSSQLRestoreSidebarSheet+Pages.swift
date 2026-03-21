import SwiftUI
import SQLServerKit

// MARK: - General Page

extension MSSQLRestoreSidebarSheet {
    var generalPage: some View {
        Group {
            Section("Source") {
                PropertyRow(
                    title: "Path on server",
                    info: "The file path to the .bak backup file on the SQL Server machine. The SQL Server service account must have read access."
                ) {
                    TextField("", text: $viewModel.restoreDiskPath, prompt: Text("/var/backups/file.bak"))
                        .textFieldStyle(.plain)
                        .font(TypographyTokens.monospaced)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Spacer()
                    Button("List Backup Sets") {
                        Task { await viewModel.listBackupSets() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!viewModel.canListSets)
                }

                if viewModel.isLoadingSets {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Reading backup file\u{2026}")
                            .font(TypographyTokens.formDescription)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }

                if let error = viewModel.loadError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Status.error)
                }
            }

            if !viewModel.backupSets.isEmpty {
                Section("Backup Sets") {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Text("#")
                                .frame(width: 30, alignment: .leading)
                            Text("Type")
                                .frame(width: 80, alignment: .leading)
                            Text("Database")
                                .frame(width: 100, alignment: .leading)
                            Text("Size")
                            Spacer()
                        }
                        .font(TypographyTokens.detail.weight(.medium))
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .padding(.horizontal, SpacingTokens.sm)
                        .padding(.vertical, SpacingTokens.xs)

                        Divider()

                        ScrollView(.vertical) {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.backupSets) { set in
                                    HStack(spacing: 0) {
                                        Text("\(set.id + 1)")
                                            .frame(width: 30, alignment: .leading)
                                        Text(set.backupTypeDescription)
                                            .frame(width: 80, alignment: .leading)
                                        Text(set.databaseName)
                                            .frame(width: 100, alignment: .leading)
                                        Text(set.formattedSize)
                                        Spacer()
                                    }
                                    .font(TypographyTokens.detail)
                                    .padding(.horizontal, SpacingTokens.sm)
                                    .padding(.vertical, 4)

                                    if set.id != viewModel.backupSets.last?.id {
                                        Divider().padding(.leading, SpacingTokens.sm)
                                    }
                                }
                            }
                        }
                        .frame(height: min(CGFloat(viewModel.backupSets.count) * 28 + 8, 140))
                    }
                    .background(ColorTokens.Background.secondary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            Section("Target") {
                PropertyRow(
                    title: "Database Name",
                    info: "The name of the database to restore into. If it does not exist, SQL Server will create it."
                ) {
                    TextField("", text: $viewModel.restoreDatabaseName, prompt: Text("database_name"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }

                PropertyRow(
                    title: "File Number",
                    info: "Which backup set to restore from the file. A single .bak file can contain multiple backup sets."
                ) {
                    TextField("", value: $viewModel.fileNumber, format: .number, prompt: Text("1"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }
}

// MARK: - Files Page

extension MSSQLRestoreSidebarSheet {
    @ViewBuilder
    var filesPage: some View {
        if viewModel.fileRelocations.isEmpty {
            Section("File Relocation") {
                Text("No file information available. Use \"List Backup Sets\" on the General page first.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        } else {
            Section {
                ForEach($viewModel.fileRelocations) { $entry in
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text(entry.logicalName)
                            .font(TypographyTokens.detail.weight(.medium))
                        TextField("", text: $entry.relocatedPath, prompt: Text(entry.originalPath))
                            .textFieldStyle(.plain)
                            .font(TypographyTokens.monospaced)
                    }
                }
            } header: {
                Text("File Relocation")
            } footer: {
                Text("Change the physical file paths if restoring to a server with a different directory layout.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }
}

// MARK: - Options Page

extension MSSQLRestoreSidebarSheet {
    var restoreOptionsPage: some View {
        Group {
            Section("Overwrite") {
                PropertyRow(
                    title: "Overwrite (REPLACE)",
                    info: "Allow restoring over an existing database even if the database name differs from the backup. Use with caution — this overwrites the target database."
                ) {
                    Toggle("", isOn: $viewModel.replace)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                PropertyRow(
                    title: "Close Connections",
                    info: "Set the database to SINGLE_USER mode before restoring, disconnecting all active sessions. Automatically restores MULTI_USER mode after the restore completes."
                ) {
                    Toggle("", isOn: $viewModel.closeConnections)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Section("Access") {
                PropertyRow(
                    title: "Preserve Replication",
                    info: "Keep replication settings intact after restore. Without this, replication configuration is removed during restore."
                ) {
                    Toggle("", isOn: $viewModel.keepReplication)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                PropertyRow(
                    title: "Restricted Access",
                    info: "Restrict access to the restored database to members of db_owner, dbcreator, and sysadmin roles."
                ) {
                    Toggle("", isOn: $viewModel.restrictedUser)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Section("Reliability") {
                PropertyRow(
                    title: "Checksum",
                    info: "Verify page checksums during restore. Detects corruption in the backup file."
                ) {
                    Toggle("", isOn: $viewModel.restoreChecksum)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                PropertyRow(
                    title: "Continue on Error",
                    info: "Continue restoring even if checksum errors are found. By default, restore stops on the first error."
                ) {
                    Toggle("", isOn: $viewModel.restoreContinueOnError)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
        }
    }
}

// MARK: - Recovery Page

extension MSSQLRestoreSidebarSheet {
    var recoveryPage: some View {
        Group {
            Section {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    PropertyRow(title: "Recovery Mode") {
                        Picker("", selection: $viewModel.recoveryMode) {
                            ForEach(MSSQLRestoreRecoveryMode.allCases, id: \.self) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    Text(recoveryModeDescription)
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            } header: {
                Text("Recovery State")
            }

            if viewModel.recoveryMode == .standby {
                Section("Standby") {
                    PropertyRow(
                        title: "Standby File",
                        info: "Path to the undo file on the SQL Server. Required for STANDBY mode — stores uncommitted transactions so the database is read-only but available."
                    ) {
                        TextField("", text: $viewModel.standbyFile, prompt: Text("/var/backups/standby.tuf"))
                            .textFieldStyle(.plain)
                            .font(TypographyTokens.monospaced)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            Section("Point-in-Time") {
                PropertyRow(
                    title: "Point-in-Time (STOPAT)",
                    info: "Restore the database to its state at a specific point in time. Requires a transaction log backup."
                ) {
                    Toggle("", isOn: $viewModel.usePointInTimeRecovery)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                if viewModel.usePointInTimeRecovery {
                    PropertyRow(title: "Stop At") {
                        DatePicker("", selection: $viewModel.stopAtDate, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                    }
                }
            }
        }
    }

    private var recoveryModeDescription: String {
        switch viewModel.recoveryMode {
        case .recovery:
            return "Bring the database online after restore. Use when this is the final restore step."
        case .noRecovery:
            return "Leave the database in a restoring state. Use when you need to apply additional log or differential backups."
        case .standby:
            return "Leave the database read-only with the ability to undo uncommitted transactions. Allows querying between log restores."
        }
    }
}

// MARK: - Verify Page

extension MSSQLRestoreSidebarSheet {
    var verifyPage: some View {
        Section {
            HStack {
                Spacer()
                Button("Verify Backup") {
                    Task { await viewModel.verify() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.restoreDiskPath.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isVerifying)
            }

            switch viewModel.verifyPhase {
            case .completed(let messages):
                if messages.isEmpty {
                    Label("Backup verified successfully.", systemImage: "checkmark.circle")
                        .foregroundStyle(ColorTokens.Status.success)
                        .font(TypographyTokens.monospaced)
                        .textSelection(.enabled)
                } else {
                    ForEach(messages, id: \.self) { msg in
                        Text(msg)
                            .font(TypographyTokens.monospaced)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .textSelection(.enabled)
                    }
                }
            case .failed(let message):
                Text(message)
                    .font(TypographyTokens.monospaced)
                    .foregroundStyle(ColorTokens.Status.error)
                    .textSelection(.enabled)
            case .running:
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Verifying\u{2026}")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            case .idle:
                EmptyView()
            }
        } header: {
            Text("Verify Backup")
        } footer: {
            Text("Checks the backup file integrity without restoring. Runs RESTORE VERIFYONLY.")
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }
}

// MARK: - Output & Footer

extension MSSQLRestoreSidebarSheet {
    @ViewBuilder
    var outputSection: some View {
        if viewModel.restorePhase != .idle {
            Section("Output") {
                switch viewModel.restorePhase {
                case .completed(let messages):
                    ForEach(messages, id: \.self) { msg in
                        Text(msg)
                            .font(TypographyTokens.monospaced)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .textSelection(.enabled)
                    }
                    if messages.isEmpty {
                        Label("Restore completed successfully.", systemImage: "checkmark.circle")
                            .foregroundStyle(ColorTokens.Status.success)
                            .font(TypographyTokens.monospaced)
                    }
                case .failed(let message):
                    Text(message)
                        .font(TypographyTokens.monospaced)
                        .foregroundStyle(ColorTokens.Status.error)
                        .textSelection(.enabled)
                default:
                    EmptyView()
                }
            }
        }
    }

    var footerBar: some View {
        HStack {
            if viewModel.isRestoreRunning {
                ProgressView()
                    .controlSize(.small)
                Text("Restoring\u{2026}")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            } else if case .completed = viewModel.restorePhase {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(ColorTokens.Status.success)
                Text("Completed")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Status.success)
            } else if case .failed = viewModel.restorePhase {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(ColorTokens.Status.error)
                Text("Failed")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Status.error)
            }
            Spacer()
            if viewModel.isRestoreRunning {
                Button("Cancel") { viewModel.cancelRestore() }
                    .buttonStyle(.bordered)
            }
            Button("Close") { onDismiss() }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                .disabled(viewModel.isRestoreRunning)
            Button("Restore") {
                Task { await viewModel.executeRestore() }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!viewModel.canRestore)
        }
        .padding(SpacingTokens.md)
    }
}
