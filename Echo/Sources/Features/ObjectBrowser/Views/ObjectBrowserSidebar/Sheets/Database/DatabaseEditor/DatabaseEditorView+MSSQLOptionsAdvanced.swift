import SwiftUI
import SQLServerKit

// MARK: - MSSQL Options Page (advanced sections)

extension DatabaseEditorView {

    @ViewBuilder
    func mssqlOptionsAdvancedSections() -> some View {
        Section("ANSI Defaults") {
            PropertyRow(title: "ANSI NULL Default") {
                Toggle("", isOn: $viewModel.ansiNullDefault)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            PropertyRow(title: "ANSI NULLS Enabled") {
                Toggle("", isOn: $viewModel.ansiNulls)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            PropertyRow(title: "ANSI Padding Enabled") {
                Toggle("", isOn: $viewModel.ansiPadding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            PropertyRow(title: "ANSI Warnings Enabled") {
                Toggle("", isOn: $viewModel.ansiWarnings)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }

        Section("Arithmetic") {
            PropertyRow(title: "Arithmetic Abort Enabled") {
                Toggle("", isOn: $viewModel.arithAbort)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            PropertyRow(title: "Numeric Round-Abort") {
                Toggle("", isOn: $viewModel.numericRoundAbort)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            PropertyRow(title: "Concatenate Null Yields Null") {
                Toggle("", isOn: $viewModel.concatNullYieldsNull)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }

        Section("Identifiers & Triggers") {
            PropertyRow(title: "Quoted Identifiers Enabled") {
                Toggle("", isOn: $viewModel.quotedIdentifier)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            PropertyRow(title: "Recursive Triggers Enabled") {
                Toggle("", isOn: $viewModel.recursiveTriggers)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            PropertyRow(title: "Date Correlation Optimization") {
                Toggle("", isOn: $viewModel.dateCorrelation)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }

        Section("Cursor") {
            PropertyRow(title: "Close Cursor on Commit") {
                Toggle("", isOn: $viewModel.cursorCloseOnCommit)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            PropertyRow(title: "Default Cursor Scope") {
                Picker("", selection: $viewModel.cursorDefaultLocal) {
                    Text("GLOBAL").tag(false)
                    Text("LOCAL").tag(true)
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }

        Section("FILESTREAM") {
            PropertyRow(title: "Directory Name") {
                Text(viewModel.filestreamDirectoryName.isEmpty ? "Not configured" : viewModel.filestreamDirectoryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            PropertyRow(title: "Non-Transacted Access") {
                Text(viewModel.filestreamNonTransactedAccess)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }

        Section("Service Broker") {
            PropertyRow(title: "Broker Enabled") {
                Toggle("", isOn: $viewModel.isBrokerEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            PropertyRow(title: "Honor Broker Priority") {
                Text(viewModel.honorBrokerPriority ? "Yes" : "No")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            PropertyRow(title: "Service Broker GUID") {
                Text(viewModel.serviceBrokerGUID)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .textSelection(.enabled)
            }
        }

        Section("Miscellaneous") {
            PropertyRow(title: "Trustworthy") {
                Toggle("", isOn: $viewModel.isTrustworthy)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            PropertyRow(title: "Parameterization") {
                Picker("", selection: $viewModel.parameterization) {
                    ForEach(SQLServerDatabaseOption.ParameterizationOption.allCases, id: \.self) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
    }
}
