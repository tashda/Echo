import SwiftUI
import SQLServerKit

struct MSSQLMaintenanceHealthView: View {
    @Bindable var viewModel: MSSQLMaintenanceViewModel
    @Environment(EnvironmentState.self) private var environmentState

    private var session: ConnectionSession? {
        environmentState.sessionGroup.sessionForConnection(viewModel.connectionID)
    }

    var body: some View {
        Form {
            informationSection
            integritySection
            shrinkDatabaseSection
            shrinkFileSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .task {
            await viewModel.loadDatabaseFiles()
        }
    }

    // MARK: - Information

    @ViewBuilder
    private var informationSection: some View {
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
    }

    // MARK: - Integrity

    @ViewBuilder
    private var integritySection: some View {
        Section("Integrity") {
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
        }
    }

    // MARK: - Shrink Database

    @ViewBuilder
    private var shrinkDatabaseSection: some View {
        Section("Shrink Database") {
            PropertyRow(title: "Target %", subtitle: "Minimum free space percentage after shrink.") {
                Stepper("\(viewModel.shrinkTargetPercent)%", value: $viewModel.shrinkTargetPercent, in: 0...99)
                    .frame(width: 120)
            }

            PropertyRow(title: "Option") {
                Picker("", selection: $viewModel.shrinkOption) {
                    ForEach(ShrinkOptionChoice.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
            }

            PropertyRow(
                title: "Shrink",
                subtitle: "Recover unused space from data and log files.",
                info: "Recovers space by moving data pages. Use sparingly as it causes index fragmentation."
            ) {
                Button {
                    Task { await viewModel.runShrinkWithOptions() }
                } label: {
                    if viewModel.isShrinking {
                        ProgressView().controlSize(.small)
                            .frame(width: 120)
                    } else {
                        Text("Shrink Database")
                    }
                }
                .disabled(viewModel.isShrinking || !(session?.permissions?.canBackupRestore ?? true))
            }
        }
    }

    // MARK: - Shrink File

    @ViewBuilder
    private var shrinkFileSection: some View {
        Section("Shrink File") {
            if viewModel.isLoadingFiles {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading files...")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            } else if viewModel.databaseFiles.isEmpty {
                Text("No database files available.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            } else {
                PropertyRow(title: "File") {
                    Picker("", selection: $viewModel.shrinkFileName) {
                        ForEach(viewModel.databaseFiles, id: \.name) { file in
                            Text("\(file.name) (\(file.typeDescription))")
                                .tag(file.name)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }

                PropertyRow(title: "Target Size (MB)", subtitle: "Enter 0 to shrink as much as possible.") {
                    TextField("", value: $viewModel.shrinkFileTargetMB, format: .number, prompt: Text("0"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }

                PropertyRow(
                    title: "Shrink",
                    subtitle: "Shrink the selected file to the target size."
                ) {
                    Button {
                        Task { await viewModel.runShrinkFile() }
                    } label: {
                        if viewModel.isShrinkingFile {
                            ProgressView().controlSize(.small)
                                .frame(width: 80)
                        } else {
                            Text("Shrink File")
                        }
                    }
                    .disabled(viewModel.isShrinkingFile || viewModel.shrinkFileName.isEmpty || !(session?.permissions?.canBackupRestore ?? true))
                }
            }
        }
    }

    // MARK: - Helpers

    private func statusColor(_ status: String) -> Color {
        switch status.uppercased() {
        case "ONLINE": return ColorTokens.Status.success
        case "OFFLINE": return ColorTokens.Status.error
        default: return ColorTokens.Text.secondary
        }
    }
}
