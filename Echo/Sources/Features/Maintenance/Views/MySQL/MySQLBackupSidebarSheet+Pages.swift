import SwiftUI

extension MySQLBackupSidebarSheet {
    var generalPage: some View {
        Group {
            Section("Destination") {
                PropertyRow(title: "File", info: "mysqldump writes the generated SQL script to this location.") {
                    HStack(spacing: SpacingTokens.xs) {
                        TextField("", text: $viewModel.outputPath, prompt: Text("/path/to/backup.sql"))
                            .textFieldStyle(.plain)
                            .font(TypographyTokens.monospaced)
                            .truncationMode(.head)
                        Button("Browse") { viewModel.selectBackupFile() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        if let url = viewModel.backupDestinationURL {
                            Button("Open") { viewModel.openFile(url) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            Button("Reveal") { viewModel.revealInFinder(url) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }

                PropertyRow(title: "Database") {
                    Text(viewModel.databaseName)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            Section("Tooling") {
                PropertyRow(title: "mysqldump", info: "Echo resolves mysqldump from a custom path, app support tools, Homebrew installs, or your shell PATH.") {
                    if let url = MySQLToolLocator.mysqldumpURL(customPath: customToolPath) {
                        Text(url.path)
                            .font(TypographyTokens.monospaced)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text("Not Found")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Status.error)
                    }
                }
            }
        }
    }

    var optionsPage: some View {
        Group {
            Section("Contents") {
                PropertyRow(title: "Include Data", info: "Include INSERT statements for table rows in the dump.") {
                    Toggle("", isOn: $viewModel.includeData)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                PropertyRow(title: "Include Routines", info: "Include stored procedures and functions.") {
                    Toggle("", isOn: $viewModel.includeRoutines)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                PropertyRow(title: "Include Triggers", info: "Include trigger definitions for dumped tables.") {
                    Toggle("", isOn: $viewModel.includeTriggers)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                PropertyRow(title: "Include Events", info: "Include MySQL event scheduler objects.") {
                    Toggle("", isOn: $viewModel.includeEvents)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Section("Consistency") {
                PropertyRow(title: "Single Transaction", info: "Use a single consistent snapshot for transactional tables during the backup.") {
                    Toggle("", isOn: $viewModel.singleTransaction)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
        }
    }

    @ViewBuilder
    var outputSection: some View {
        if !viewModel.backupOutput.isEmpty || viewModel.backupPhase != .idle {
            Section("Output") {
                if !viewModel.backupOutput.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(viewModel.backupOutput.enumerated()), id: \.offset) { _, line in
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
                case .completed(let message):
                    Label(message, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(ColorTokens.Status.success)
                        .font(TypographyTokens.formDescription)
                case .failed(let message):
                    Label(message, systemImage: "xmark.circle.fill")
                        .foregroundStyle(ColorTokens.Status.error)
                        .font(TypographyTokens.formDescription)
                case .running:
                    ProgressView("Running mysqldump…")
                case .idle:
                    Text("Ready to run mysqldump.")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
    }

    @ViewBuilder
    var footerContent: some View {
        if viewModel.isBackupRunning {
            ProgressView()
                .controlSize(.small)
            Text("Backing up…")
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
}
