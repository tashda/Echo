import SwiftUI
import SQLServerKit

// MARK: - MSSQL Options Page (top sections)

extension DatabaseEditorView {

    @ViewBuilder
    func mssqlOptionsPage() -> some View {
        mssqlOptionsCoreSections()
        mssqlOptionsAdvancedSections()
    }

    @ViewBuilder
    func mssqlOptionsCoreSections() -> some View {
        Section("Recovery") {
            PropertyRow(title: "Recovery Model") {
                Picker("", selection: $viewModel.recoveryModel) {
                    ForEach(SQLServerDatabaseOption.RecoveryModel.allCases, id: \.self) { model in
                        Text(model.rawValue).tag(model)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            PropertyRow(title: "Page Verify") {
                Picker("", selection: $viewModel.pageVerify) {
                    ForEach(SQLServerDatabaseOption.PageVerifyOption.allCases, id: \.self) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            PropertyRow(title: "Target Recovery Time", subtitle: "seconds") {
                TextField("", value: $viewModel.targetRecoveryTime, format: .number, prompt: Text("60"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Delayed Durability") {
                Picker("", selection: $viewModel.delayedDurability) {
                    ForEach(SQLServerDatabaseOption.DelayedDurabilityOption.allCases, id: \.self) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }

        Section("Compatibility") {
            PropertyRow(title: "Compatibility Level") {
                Picker("", selection: $viewModel.compatibilityLevel) {
                    ForEach(viewModel.compatibilityLevels, id: \.value) { level in
                        Text(level.label).tag(level.value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }

        Section("State") {
            PropertyRow(title: "Read Only") {
                Toggle("", isOn: $viewModel.isReadOnly)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            PropertyRow(title: "User Access") {
                Picker("", selection: $viewModel.userAccess) {
                    ForEach(SQLServerDatabaseOption.UserAccessOption.allCases, id: \.self) { opt in
                        Text(opt.displayName).tag(opt)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            PropertyRow(title: "Encryption") {
                Toggle("", isOn: $viewModel.isEncrypted)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }

        Section("Isolation") {
            PropertyRow(title: "Allow Snapshot Isolation") {
                Toggle("", isOn: $viewModel.allowSnapshotIsolation)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            PropertyRow(title: "Read Committed Snapshot") {
                Toggle("", isOn: $viewModel.readCommittedSnapshot)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }

        Section("Statistics") {
            PropertyRow(title: "Auto Create Statistics") {
                Toggle("", isOn: $viewModel.autoCreateStats)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            PropertyRow(title: "Auto Update Statistics") {
                Toggle("", isOn: $viewModel.autoUpdateStats)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            PropertyRow(title: "Auto Update Statistics Asynchronously") {
                Toggle("", isOn: $viewModel.autoUpdateStatsAsync)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }

        Section("Storage") {
            PropertyRow(title: "Auto Close") {
                Toggle("", isOn: $viewModel.autoClose)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            PropertyRow(title: "Auto Shrink") {
                Toggle("", isOn: $viewModel.autoShrink)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
    }
}
