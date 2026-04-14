import SwiftUI

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
