import SwiftUI

struct MySQLServerControlSection: View {
    @Bindable var viewModel: ServerPropertiesViewModel
    let customToolPath: String?

    var body: some View {
        // Start, Stop and Restart in the window toolbar (37.5), the state after the server (37.2).
        VStack(spacing: 0) {
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
        .toolTabHeaderDetail(statusText)
        // Round 37.5: Start is the special button; Stop, Restart and Refresh the group.
        .tabToolbar(
            special: TabToolbarItem(id: "start", title: "Start", symbol: "play.fill", isDisabled: !canStart) { [viewModel, customToolPath] in
                Task { await viewModel.startLocalMySQLServer(customToolPath: customToolPath) }
            },
            groups: [[
                TabToolbarItem(id: "stop", title: "Stop", symbol: "stop.fill", isDisabled: !canStop) { [viewModel, customToolPath] in
                    Task { await viewModel.stopLocalMySQLServer(customToolPath: customToolPath) }
                },
                TabToolbarItem(id: "restart", title: "Restart", symbol: "arrow.clockwise.circle", isDisabled: !canRestart) { [viewModel, customToolPath] in
                    Task { await viewModel.restartLocalMySQLServer(customToolPath: customToolPath) }
                },
                .refresh { [viewModel] in Task { await viewModel.loadCurrentSection() } },
            ]]
        )
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
