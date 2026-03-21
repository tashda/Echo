import SwiftUI

// MARK: - General Page

extension PgBackupSidebarSheet {
    var generalPage: some View {
        Group {
            Section("Database") {
                PropertyRow(title: "Name") {
                    Text(viewModel.databaseName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    PropertyRow(title: "Format") {
                        Picker("", selection: $viewModel.outputFormat) {
                            ForEach(PgDumpFormat.allCases) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .onChange(of: viewModel.outputFormat) { _, _ in
                            viewModel.outputURL = nil
                            viewModel.outputPath = ""
                        }
                    }

                    Text(formatDescription)
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }

                PropertyRow(title: "Destination") {
                    HStack(spacing: SpacingTokens.xs) {
                        TextField("", text: $viewModel.outputPath, prompt: Text("/path/to/backup.dump"))
                            .textFieldStyle(.plain)
                            .font(TypographyTokens.monospaced)
                            .truncationMode(.head)
                        Button("Browse") {
                            viewModel.selectOutputFile()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                if viewModel.outputFormat != .plain {
                    PropertyRow(
                        title: "Compression",
                        info: "Compression level from 0 (none) to 9 (maximum). Higher values produce smaller files but take longer."
                    ) {
                        Stepper(value: $viewModel.compression, in: 0...9) {
                            Text("\(viewModel.compression)")
                                .font(TypographyTokens.monospaced)
                                .frame(minWidth: 16, alignment: .trailing)
                        }
                    }
                }
            } header: {
                Text("Output")
            }

            Section("Connection") {
                PropertyRow(
                    title: "Encoding",
                    info: "Override the character encoding for the dump. Leave empty to use the database encoding. Common values: UTF8, LATIN1, SQL_ASCII."
                ) {
                    TextField("", text: $viewModel.encoding, prompt: Text("e.g. UTF8"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }

                PropertyRow(
                    title: "Role",
                    info: "Use SET ROLE to assume this role before dumping. Useful when the connecting user has multiple roles with different permissions."
                ) {
                    TextField("", text: $viewModel.roleName, prompt: Text("e.g. backup_role"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private var formatDescription: String {
        switch viewModel.outputFormat {
        case .plain: return "Readable SQL script (.sql). Cannot be used with pg_restore."
        case .custom: return "Compressed archive. Supports selective restore with pg_restore."
        case .tar: return "Portable tar archive. Compatible with standard tools."
        case .directory: return "Directory of files. Enables parallel dump and restore."
        }
    }
}

// MARK: - Scope Page

extension PgBackupSidebarSheet {
    var scopePage: some View {
        Group {
            Section("Data Selection") {
                PropertyRow(
                    title: "Schema Only",
                    info: "Dump only the object definitions (tables, views, functions) without any row data."
                ) {
                    Toggle("", isOn: $viewModel.schemaOnly)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: viewModel.schemaOnly) { _, newVal in
                            if newVal { viewModel.dataOnly = false }
                        }
                }

                PropertyRow(
                    title: "Data Only",
                    info: "Dump only the table data, not the schema. The target database must already have the tables."
                ) {
                    Toggle("", isOn: $viewModel.dataOnly)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: viewModel.dataOnly) { _, newVal in
                            if newVal { viewModel.schemaOnly = false }
                        }
                }

                PropertyRow(
                    title: "Include Blobs",
                    info: "Include large objects (BLOBs) in the dump. Enabled by default. Disable to exclude large objects and reduce dump size."
                ) {
                    Toggle("", isOn: $viewModel.includeBlobs)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Section {
                PropertyRow(
                    title: "Include Tables",
                    info: "Comma-separated list of table patterns to include. Supports wildcards (*). Example: public.users, public.orders*"
                ) {
                    TextField("", text: $viewModel.includeTables, prompt: Text("e.g. public.users, public.orders*"))
                        .textFieldStyle(.plain)
                        .font(TypographyTokens.monospaced)
                }

                PropertyRow(
                    title: "Exclude Tables",
                    info: "Comma-separated list of table patterns to exclude."
                ) {
                    TextField("", text: $viewModel.excludeTables, prompt: Text("e.g. public.temp_*"))
                        .textFieldStyle(.plain)
                        .font(TypographyTokens.monospaced)
                }

                PropertyRow(
                    title: "Include Schemas",
                    info: "Comma-separated list of schema patterns to include."
                ) {
                    TextField("", text: $viewModel.includeSchemas, prompt: Text("e.g. public, app"))
                        .textFieldStyle(.plain)
                        .font(TypographyTokens.monospaced)
                }

                PropertyRow(
                    title: "Exclude Schemas",
                    info: "Comma-separated list of schema patterns to exclude."
                ) {
                    TextField("", text: $viewModel.excludeSchemas, prompt: Text("e.g. pg_catalog"))
                        .textFieldStyle(.plain)
                        .font(TypographyTokens.monospaced)
                }

                PropertyRow(
                    title: "Exclude Table Data",
                    info: "Comma-separated list of tables whose data should be excluded (schema is still dumped)."
                ) {
                    TextField("", text: $viewModel.excludeTableData, prompt: Text("e.g. public.audit_log"))
                        .textFieldStyle(.plain)
                        .font(TypographyTokens.monospaced)
                }
            } header: {
                Text("Filters")
            } footer: {
                Text("Use comma-separated patterns. Wildcards (*) are supported.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }
}

// MARK: - Options Page

extension PgBackupSidebarSheet {
    var optionsPage: some View {
        Group {
            Section("Ownership & Privileges") {
                PropertyRow(
                    title: "No Owner",
                    info: "Do not output commands to set ownership. The restoring user will own all objects."
                ) {
                    Toggle("", isOn: $viewModel.noOwner)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                PropertyRow(
                    title: "No Privileges",
                    info: "Do not dump access privileges (GRANT/REVOKE)."
                ) {
                    Toggle("", isOn: $viewModel.noPrivileges)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                PropertyRow(
                    title: "No Tablespaces",
                    info: "Do not output commands to select tablespaces. All objects will be created in the default tablespace."
                ) {
                    Toggle("", isOn: $viewModel.noTablespaces)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Section("Restore Behavior") {
                PropertyRow(
                    title: "Clean",
                    info: "Output DROP commands before CREATE commands for a clean restore."
                ) {
                    Toggle("", isOn: $viewModel.clean)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                PropertyRow(
                    title: "If Exists",
                    info: "Add IF EXISTS to DROP commands. Requires Clean to be enabled."
                ) {
                    Toggle("", isOn: $viewModel.ifExists)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(!viewModel.clean)
                }
                PropertyRow(
                    title: "Create Database",
                    info: "Include commands to create the database itself, then reconnect to it."
                ) {
                    Toggle("", isOn: $viewModel.createDatabase)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Section("INSERT Mode") {
                PropertyRow(
                    title: "Use INSERTs",
                    info: "Dump data as INSERT commands instead of COPY. Slower but more portable across database systems."
                ) {
                    Toggle("", isOn: $viewModel.useInserts)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                if viewModel.useInserts {
                    PropertyRow(
                        title: "Column INSERTs",
                        info: "Include column names in INSERT statements. Makes the dump self-documenting and order-independent."
                    ) {
                        Toggle("", isOn: $viewModel.columnInserts)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    PropertyRow(
                        title: "Rows per INSERT",
                        info: "Bundle multiple rows into each INSERT statement. 0 means one row per INSERT. Higher values improve restore speed."
                    ) {
                        Stepper(value: $viewModel.rowsPerInsert, in: 0...10000, step: 100) {
                            Text("\(viewModel.rowsPerInsert)")
                                .font(TypographyTokens.monospaced)
                                .frame(minWidth: 40, alignment: .trailing)
                        }
                    }

                    PropertyRow(
                        title: "On Conflict Do Nothing",
                        info: "Add ON CONFLICT DO NOTHING to INSERT statements. Allows restoring into a table that already has some rows."
                    ) {
                        Toggle("", isOn: $viewModel.onConflictDoNothing)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
            }
        }
    }
}

// MARK: - Advanced Page

extension PgBackupSidebarSheet {
    var advancedPage: some View {
        Group {
            if viewModel.outputFormat == .directory {
                Section("Parallelism") {
                    PropertyRow(
                        title: "Parallel Jobs",
                        info: "Number of tables to dump simultaneously. Only available with Directory format."
                    ) {
                        Stepper(value: $viewModel.parallelJobs, in: 1...16) {
                            Text("\(viewModel.parallelJobs)")
                                .font(TypographyTokens.monospaced)
                                .frame(minWidth: 16, alignment: .trailing)
                        }
                    }
                }
            }

            Section("Output Control") {
                PropertyRow(
                    title: "Verbose",
                    info: "Output detailed progress information to stderr during the dump."
                ) {
                    Toggle("", isOn: $viewModel.verbose)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                PropertyRow(
                    title: "Disable Triggers",
                    info: "Include commands to temporarily disable triggers during data-only restore. Requires superuser privileges."
                ) {
                    Toggle("", isOn: $viewModel.disableTriggers)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                PropertyRow(
                    title: "Disable Dollar Quoting",
                    info: "Disable dollar quoting for function bodies, using SQL standard string syntax instead."
                ) {
                    Toggle("", isOn: $viewModel.disableDollarQuoting)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                PropertyRow(
                    title: "Force Double Quotes",
                    info: "Quote all identifiers with double quotes, even if they are not reserved words."
                ) {
                    Toggle("", isOn: $viewModel.forceDoubleQuotes)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                PropertyRow(
                    title: "SET SESSION AUTHORIZATION",
                    info: "Use SET SESSION AUTHORIZATION instead of ALTER OWNER to set object ownership."
                ) {
                    Toggle("", isOn: $viewModel.useSetSessionAuth)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Section("Timeouts") {
                PropertyRow(
                    title: "Lock Wait Timeout",
                    info: "Maximum time (in milliseconds) to wait for table locks at the beginning of the dump."
                ) {
                    TextField("", text: $viewModel.lockWaitTimeout, prompt: Text("e.g. 5000"))
                        .textFieldStyle(.plain)
                        .font(TypographyTokens.monospaced)
                        .multilineTextAlignment(.trailing)
                }

                PropertyRow(
                    title: "Extra Float Digits",
                    info: "Override the extra_float_digits setting. Use 3 for maximum precision."
                ) {
                    TextField("", text: $viewModel.extraFloatDigits, prompt: Text("e.g. 3"))
                        .textFieldStyle(.plain)
                        .font(TypographyTokens.monospaced)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section {
                PropertyRow(
                    title: "Extra Arguments",
                    info: "Additional pg_dump flags not covered by the UI. Space-separated. Example: --no-comments --no-publications"
                ) {
                    TextField("", text: $viewModel.extraArguments, prompt: Text("e.g. --no-comments"))
                        .textFieldStyle(.plain)
                        .font(TypographyTokens.monospaced)
                }
            } header: {
                Text("Extra Arguments")
            } footer: {
                Text("Escape hatch for any pg_dump flag not available in the UI above.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }
}

// MARK: - Output & Footer

extension PgBackupSidebarSheet {
    @ViewBuilder
    var outputSection: some View {
        if !viewModel.backupStderrOutput.isEmpty || viewModel.backupPhase != .idle {
            Section("Output") {
                if !viewModel.backupStderrOutput.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(viewModel.backupStderrOutput.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(TypographyTokens.monospaced)
                                    .foregroundStyle(ColorTokens.Text.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)
                }

                switch viewModel.backupPhase {
                case .completed(let messages):
                    if messages.isEmpty {
                        Label("Backup completed successfully.", systemImage: "checkmark.circle")
                            .foregroundStyle(ColorTokens.Status.success)
                            .font(TypographyTokens.monospaced)
                            .textSelection(.enabled)
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
            if viewModel.isBackupRunning {
                ProgressView()
                    .controlSize(.small)
                Text("Backing up\u{2026}")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            } else if case .completed = viewModel.backupPhase {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(ColorTokens.Status.success)
                Text("Completed")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Status.success)
            } else if case .failed = viewModel.backupPhase {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(ColorTokens.Status.error)
                Text("Failed")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Status.error)
            }
            Spacer()
            if viewModel.isBackupRunning {
                Button("Cancel") { viewModel.cancelBackup() }
                    .buttonStyle(.bordered)
            }
            Button("Close") { onDismiss() }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                .disabled(viewModel.isBackupRunning)
            Button("Back Up") {
                Task { await viewModel.executeBackup(customToolPath: customToolPath) }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!viewModel.canBackup)
        }
        .padding(SpacingTokens.md)
    }
}
