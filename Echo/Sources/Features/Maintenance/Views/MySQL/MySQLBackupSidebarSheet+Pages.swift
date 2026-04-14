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
                PropertyRow(title: "mysqlpump", info: "mysqlpump is discovered alongside mysqldump so the configured tools directory already supports future logical backup workflows.") {
                    if let url = MySQLToolLocator.mysqlpumpURL(customPath: customToolPath) {
                        Text(url.path)
                            .font(TypographyTokens.monospaced)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text("Optional")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
            }
        }
    }

    var scopePage: some View {
        Group {
            Section("Dump Contents") {
                PropertyRow(title: "Include Schema", info: "Emit CREATE statements and other object definitions into the backup.") {
                    Toggle("", isOn: $viewModel.includeSchema)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                PropertyRow(title: "Include Data", info: "Emit INSERT statements for table rows in the backup.") {
                    Toggle("", isOn: $viewModel.includeData)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                PropertyRow(title: "Tables", info: "Optionally limit the dump to a comma-separated list of tables in the selected database.") {
                    TextField("", text: $viewModel.selectedTables, prompt: Text("e.g. users, orders, audit_log"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    var optionsPage: some View {
        Group {
            Section("Contents") {
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
                PropertyRow(title: "Lock Tables", info: "Use table locks during the dump for non-transactional engines such as MyISAM.") {
                    Toggle("", isOn: $viewModel.lockTables)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Section("Transfer") {
                PropertyRow(title: "Compress Connection", info: "Ask the MySQL protocol to compress traffic during the backup.") {
                    Toggle("", isOn: $viewModel.compressConnection)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                PropertyRow(title: "Extended INSERT", info: "Use multi-row INSERT statements for more compact dumps and faster restores.") {
                    Toggle("", isOn: $viewModel.useExtendedInsert)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
        }
    }

    var advancedPage: some View {
        Group {
            Section("Behavior") {
                Text("Transactional servers usually prefer single-transaction backups. Lock tables is more appropriate for MyISAM or mixed-engine environments that need explicit read locks.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }
}
