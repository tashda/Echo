import SwiftUI

// MARK: - General Page

extension PgRestoreSidebarSheet {
    var generalPage: some View {
        Group {
            Section("Source") {
                PropertyRow(title: "File") {
                    HStack(spacing: SpacingTokens.xs) {
                        TextField("", text: $viewModel.inputPath, prompt: Text("/path/to/backup.dump"))
                            .textFieldStyle(.plain)
                            .font(TypographyTokens.monospaced)
                            .truncationMode(.head)
                        Button("Browse") {
                            viewModel.selectInputFile()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                if let detected = viewModel.detectedFormat {
                    PropertyRow(title: "Detected Format") {
                        Text(detected.rawValue)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }

                if viewModel.inputURL != nil && viewModel.detectedFormat != .plain {
                    HStack {
                        Spacer()
                        Button("List Contents") {
                            Task { await viewModel.listContents(customToolPath: customToolPath) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!viewModel.canListContents)
                    }
                }
            }

            if !viewModel.dumpContents.isEmpty {
                Section("Contents (\(viewModel.dumpContents.count) items)") {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Text("Type")
                                .frame(width: 90, alignment: .leading)
                            Text("Schema")
                                .frame(width: 90, alignment: .leading)
                            Text("Name")
                            Spacer()
                        }
                        .font(TypographyTokens.detail.weight(.medium))
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .padding(.horizontal, SpacingTokens.sm)
                        .padding(.vertical, SpacingTokens.xs)

                        Divider()

                        ScrollView(.vertical) {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.dumpContents) { item in
                                    HStack(spacing: 0) {
                                        Text(item.type)
                                            .frame(width: 90, alignment: .leading)
                                        Text(item.schema ?? "")
                                            .foregroundStyle(ColorTokens.Text.secondary)
                                            .frame(width: 90, alignment: .leading)
                                        Text(item.name)
                                        Spacer()
                                    }
                                    .font(TypographyTokens.detail)
                                    .padding(.horizontal, SpacingTokens.sm)
                                    .padding(.vertical, 4)

                                    if item.id != viewModel.dumpContents.last?.id {
                                        Divider().padding(.leading, SpacingTokens.sm)
                                    }
                                }
                            }
                        }
                        .frame(height: min(CGFloat(viewModel.dumpContents.count) * 28 + 8, 220))
                    }
                    .background(ColorTokens.Background.secondary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            Section("Target") {
                PropertyRow(
                    title: "Database Name",
                    info: "The database to restore into. It must already exist. For plain SQL files, the SQL is executed directly against this database."
                ) {
                    TextField("", text: $viewModel.restoreDatabaseName, prompt: Text("e.g. my_database"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }
}

// MARK: - Options Page

extension PgRestoreSidebarSheet {
    var restoreOptionsPage: some View {
        Group {
            Section("Cleanup") {
                PropertyRow(
                    title: "Clean",
                    info: "Drop existing database objects before recreating them."
                ) {
                    Toggle("", isOn: $viewModel.restoreClean)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                PropertyRow(
                    title: "If Exists",
                    info: "Add IF EXISTS to DROP commands. Requires Clean."
                ) {
                    Toggle("", isOn: $viewModel.restoreIfExists)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(!viewModel.restoreClean)
                }
            }

            Section("Ownership & Privileges") {
                PropertyRow(
                    title: "No Owner",
                    info: "Do not restore object ownership. The restoring user will own all objects."
                ) {
                    Toggle("", isOn: $viewModel.restoreNoOwner)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                PropertyRow(
                    title: "No Privileges",
                    info: "Do not restore access privileges (GRANT/REVOKE)."
                ) {
                    Toggle("", isOn: $viewModel.restoreNoPrivileges)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                PropertyRow(
                    title: "No Tablespaces",
                    info: "Do not output commands to select tablespaces."
                ) {
                    Toggle("", isOn: $viewModel.restoreNoTablespaces)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Section("Data Selection") {
                PropertyRow(
                    title: "Schema Only",
                    info: "Restore only the schema without any row data."
                ) {
                    Toggle("", isOn: $viewModel.restoreSchemaOnly)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: viewModel.restoreSchemaOnly) { _, newVal in
                            if newVal { viewModel.restoreDataOnly = false }
                        }
                }
                PropertyRow(
                    title: "Data Only",
                    info: "Restore only the data. Target tables must already exist."
                ) {
                    Toggle("", isOn: $viewModel.restoreDataOnly)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: viewModel.restoreDataOnly) { _, newVal in
                            if newVal { viewModel.restoreSchemaOnly = false }
                        }
                }
            }

            Section("Database") {
                PropertyRow(
                    title: "Create Database",
                    info: "Create the database before restoring into it."
                ) {
                    Toggle("", isOn: $viewModel.restoreCreateDatabase)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                PropertyRow(
                    title: "SET SESSION AUTHORIZATION",
                    info: "Use SET SESSION AUTHORIZATION instead of ALTER OWNER to set object ownership."
                ) {
                    Toggle("", isOn: $viewModel.restoreUseSetSessionAuth)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                PropertyRow(
                    title: "Disable Triggers",
                    info: "Disable triggers during data-only restore. Requires superuser privileges."
                ) {
                    Toggle("", isOn: $viewModel.restoreDisableTriggers)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
        }
    }
}

// MARK: - Advanced Page

extension PgRestoreSidebarSheet {
    var advancedPage: some View {
        Group {
            Section("Parallelism") {
                PropertyRow(
                    title: "Parallel Jobs",
                    info: "Number of tables to restore simultaneously. Only effective with Custom or Directory format backups."
                ) {
                    Stepper(value: $viewModel.restoreParallelJobs, in: 1...16) {
                        Text("\(viewModel.restoreParallelJobs)")
                            .font(TypographyTokens.monospaced)
                            .frame(minWidth: 16, alignment: .trailing)
                    }
                }
            }

            Section("Output") {
                PropertyRow(
                    title: "Verbose",
                    info: "Output detailed progress information during the restore."
                ) {
                    Toggle("", isOn: $viewModel.restoreVerbose)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Section {
                PropertyRow(
                    title: "Extra Arguments",
                    info: "Additional pg_restore flags not covered by the UI. Space-separated."
                ) {
                    TextField("", text: $viewModel.restoreExtraArguments, prompt: Text("e.g. --no-comments"))
                        .textFieldStyle(.plain)
                        .font(TypographyTokens.monospaced)
                }
            } header: {
                Text("Extra Arguments")
            } footer: {
                Text("Escape hatch for any pg_restore flag not available in the UI above.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }
}

// MARK: - Output & Footer

extension PgRestoreSidebarSheet {
    @ViewBuilder
    var outputSection: some View {
        if !viewModel.restoreStderrOutput.isEmpty || viewModel.restorePhase != .idle {
            Section("Output") {
                if !viewModel.restoreStderrOutput.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(viewModel.restoreStderrOutput.enumerated()), id: \.offset) { _, line in
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

                switch viewModel.restorePhase {
                case .completed(let messages):
                    if messages.isEmpty {
                        Label("Restore completed successfully.", systemImage: "checkmark.circle")
                            .foregroundStyle(ColorTokens.Status.success)
                            .font(TypographyTokens.formDescription)
                    } else {
                        ForEach(messages, id: \.self) { msg in
                            Text(msg)
                                .font(TypographyTokens.formDescription)
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
                    }
                case .failed(let message):
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(ColorTokens.Status.error)
                        .font(TypographyTokens.formDescription)
                default:
                    EmptyView()
                }
            }
        }
    }

    @ViewBuilder
    var footerContent: some View {
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
        if viewModel.canRestore {
            Button("Restore") {
                Task { await viewModel.executeRestore(customToolPath: customToolPath) }
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.defaultAction)
        } else {
            Button("Restore") {}
                .buttonStyle(.bordered)
                .disabled(true)
                .keyboardShortcut(.defaultAction)
        }
    }
}
