import SwiftUI

struct MySQLServerControlSection: View {
    @Bindable var viewModel: ServerPropertiesViewModel
    let customToolPath: String?

    var body: some View {
        VStack(spacing: 0) {
            TabSectionToolbar {
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text("Server Control")
                        .font(TypographyTokens.prominent.weight(.semibold))
                    Text(statusText)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(statusColor)
                }
            } controls: {
                Button("Refresh") {
                    Task { await viewModel.loadCurrentSection() }
                }
                .buttonStyle(.borderless)

                Button("Start") {
                    Task { await viewModel.startLocalMySQLServer(customToolPath: customToolPath) }
                }
                .buttonStyle(.bordered)
                .disabled(!canStart)

                Button("Stop") {
                    Task { await viewModel.stopLocalMySQLServer(customToolPath: customToolPath) }
                }
                .buttonStyle(.bordered)
                .disabled(!canStop)

                Button("Restart") {
                    Task { await viewModel.restartLocalMySQLServer(customToolPath: customToolPath) }
                }
                .buttonStyle(.bordered)
                .disabled(!canRestart)
            }

            Divider()

            Form {
                Section("Status") {
                    PropertyRow(title: "Connection Host") {
                        Text(viewModel.isLocalMySQLHost ? "Local" : "Remote")
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }

                    PropertyRow(title: "Current State") {
                        Text(statusText)
                            .foregroundStyle(statusColor)
                    }

                    PropertyRow(title: "mysqladmin") {
                        Text(MySQLToolLocator.mysqladminURL(customPath: customToolPath)?.path ?? "Not found")
                            .font(TypographyTokens.Table.path)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .textSelection(.enabled)
                    }

                    PropertyRow(title: "mysql.server") {
                        Text(MySQLToolLocator.mysqlServerScriptURL(customPath: customToolPath)?.path ?? "Not found")
                            .font(TypographyTokens.Table.path)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .textSelection(.enabled)
                    }

                    PropertyRow(title: "mysqld_safe") {
                        Text(MySQLToolLocator.mysqldSafeURL(customPath: customToolPath)?.path ?? "Not found")
                            .font(TypographyTokens.Table.path)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .textSelection(.enabled)
                    }

                    PropertyRow(title: "mysqld") {
                        Text(MySQLToolLocator.mysqldURL(customPath: customToolPath)?.path ?? "Not found")
                            .font(TypographyTokens.Table.path)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .textSelection(.enabled)
                    }
                }

                if let selectedConfig = viewModel.selectedConfigFile {
                    Section("Startup") {
                        PropertyRow(title: "Defaults File") {
                            Text(selectedConfig.path)
                                .font(TypographyTokens.Table.path)
                                .foregroundStyle(ColorTokens.Text.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }

                Section("Command Output") {
                    if viewModel.serverControlOutput.isEmpty {
                        Text("No command output yet.")
                            .foregroundStyle(ColorTokens.Text.secondary)
                    } else {
                        ScrollView {
                            Text(viewModel.serverControlOutput.joined(separator: "\n"))
                                .font(TypographyTokens.code)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(minHeight: 180)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
    }

    private var canStart: Bool {
        if case .running = viewModel.serverControlState { return false }
        return viewModel.isLocalMySQLHost &&
            (MySQLToolLocator.mysqlServerScriptURL(customPath: customToolPath) != nil ||
                MySQLToolLocator.mysqldURL(customPath: customToolPath) != nil)
    }

    private var canStop: Bool {
        if case .running = viewModel.serverControlState {
            return viewModel.isLocalMySQLHost && MySQLToolLocator.mysqladminURL(customPath: customToolPath) != nil
        }
        return false
    }

    private var canRestart: Bool {
        viewModel.isLocalMySQLHost &&
            (
                MySQLToolLocator.mysqlServerScriptURL(customPath: customToolPath) != nil ||
                (
                    MySQLToolLocator.mysqladminURL(customPath: customToolPath) != nil &&
                    MySQLServerControlPlan.start(
                        customToolPath: customToolPath,
                        defaultsFilePath: viewModel.selectedConfigFile?.path
                    ) != nil
                )
            )
    }

    private var statusText: String {
        switch viewModel.serverControlState {
        case .unknown:
            "Unknown"
        case .running:
            "Running"
        case .stopped:
            "Stopped"
        case .unavailable(let message):
            message
        }
    }

    private var statusColor: Color {
        switch viewModel.serverControlState {
        case .running:
            ColorTokens.Status.success
        case .stopped:
            ColorTokens.Status.warning
        case .unknown:
            ColorTokens.Text.secondary
        case .unavailable:
            ColorTokens.Status.error
        }
    }
}
