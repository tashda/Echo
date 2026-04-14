import SwiftUI

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
