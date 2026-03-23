import SwiftUI

struct MSSQLMaintenanceHealthView: View {
    @Bindable var viewModel: MSSQLMaintenanceViewModel
    @Environment(EnvironmentState.self) private var environmentState

    private var session: ConnectionSession? {
        environmentState.sessionGroup.sessionForConnection(viewModel.connectionID)
    }

    var body: some View {
        Form {
            Section("Information") {
                if let permissionError = viewModel.healthPermissionError {
                    Label {
                        Text(permissionError)
                            .font(TypographyTokens.formDescription)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    } icon: {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                } else if let health = viewModel.healthStats {
                    PropertyRow(title: "Status") {
                        Text(health.status)
                            .foregroundStyle(statusColor(health.status))
                    }

                    PropertyRow(title: "Size") {
                        Text(String(format: "%.2f MB", health.sizeMB))
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }

                    PropertyRow(title: "Recovery Model") {
                        Text(health.recoveryModel)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }

                    PropertyRow(title: "Collation") {
                        Text(health.collationName ?? "—")
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                } else {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Retrieving status...")
                            .font(TypographyTokens.formDescription)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
            }

            Section("Integrity & Performance") {
                PropertyRow(
                    title: "Check Integrity",
                    subtitle: "Verify physical and logical integrity of all objects.",
                    info: "Runs DBCC CHECKDB. Recommended after hardware failures or before major migrations."
                ) {
                    Button {
                        Task { await viewModel.runIntegrityCheck() }
                    } label: {
                        if viewModel.isCheckingIntegrity {
                            ProgressView().controlSize(.small)
                                .frame(width: 80)
                        } else {
                            Text("Check Integrity")
                        }
                    }
                    .disabled(viewModel.isCheckingIntegrity || !(session?.permissions?.canBackupRestore ?? true))
                }

                PropertyRow(
                    title: "Shrink Database",
                    subtitle: "Recover unused space from data and log files.",
                    info: "Recovers space by moving data pages. Use sparingly as it causes index fragmentation."
                ) {
                    Button {
                        Task { await viewModel.runShrink() }
                    } label: {
                        if viewModel.isShrinking {
                            ProgressView().controlSize(.small)
                                .frame(width: 80)
                        } else {
                            Text("Shrink")
                        }
                    }
                    .disabled(viewModel.isShrinking || !(session?.permissions?.canBackupRestore ?? true))
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func statusColor(_ status: String) -> Color {
        switch status.uppercased() {
        case "ONLINE": return ColorTokens.Status.success
        case "OFFLINE": return ColorTokens.Status.error
        default: return ColorTokens.Text.secondary
        }
    }
}
