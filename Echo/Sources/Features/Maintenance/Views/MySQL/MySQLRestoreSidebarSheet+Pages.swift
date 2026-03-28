import SwiftUI

extension MySQLRestoreSidebarSheet {
    var generalPage: some View {
        Group {
            Section("Source") {
                PropertyRow(title: "File", info: "The SQL script that Echo will pipe into the mysql client.") {
                    HStack(spacing: SpacingTokens.xs) {
                        TextField("", text: $viewModel.inputPath, prompt: Text("/path/to/backup.sql"))
                            .textFieldStyle(.plain)
                            .font(TypographyTokens.monospaced)
                            .truncationMode(.head)
                        Button("Browse") { viewModel.selectRestoreFile() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        if let url = viewModel.restoreSourceURL {
                            Button("Open") { viewModel.openFile(url) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            Button("Reveal") { viewModel.revealInFinder(url) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }

                PropertyRow(title: "Database", info: "The target database the restore will run against.") {
                    TextField("", text: $viewModel.databaseName, prompt: Text("e.g. my_database"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Tooling") {
                PropertyRow(title: "mysql", info: "Echo resolves the mysql client from a custom path, app support tools, Homebrew installs, or your shell PATH.") {
                    if let url = MySQLToolLocator.mysqlURL(customPath: customToolPath) {
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
            Section("Execution") {
                PropertyRow(title: "Continue On Error", info: "Pass --force so mysql continues executing the script after an error.") {
                    Toggle("", isOn: $viewModel.forceRestore)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
        }
    }

    @ViewBuilder
    var outputSection: some View {
        if !viewModel.restoreOutput.isEmpty || viewModel.restorePhase != .idle {
            Section("Output") {
                if !viewModel.restoreOutput.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(viewModel.restoreOutput.enumerated()), id: \.offset) { _, line in
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
                case .completed(let message):
                    Label(message, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(ColorTokens.Status.success)
                        .font(TypographyTokens.formDescription)
                case .failed(let message):
                    Label(message, systemImage: "xmark.circle.fill")
                        .foregroundStyle(ColorTokens.Status.error)
                        .font(TypographyTokens.formDescription)
                case .running:
                    ProgressView("Running mysql…")
                case .idle:
                    Text("Ready to restore SQL into \(viewModel.databaseName).")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
    }

    @ViewBuilder
    var footerContent: some View {
        if viewModel.isRestoreRunning {
            ProgressView()
                .controlSize(.small)
            Text("Restoring…")
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

        Button("Close") { onDismiss() }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)
            .disabled(viewModel.isRestoreRunning)

        Button("Restore") {
            Task { await viewModel.executeRestore(customToolPath: customToolPath) }
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
        .disabled(!viewModel.canRestore)
    }
}
