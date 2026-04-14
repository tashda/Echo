import SwiftUI
import SQLServerKit

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
