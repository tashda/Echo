import SwiftUI
import SQLServerKit

struct MSSQLSecurityLoginsSection: View {
    @Bindable var viewModel: ServerSecurityViewModel
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(\.openWindow) private var openWindow

    @State private var sortOrder = [KeyPathComparator(\ServerLoginInfo.name)]
    @State private var showDropAlert = false
    @State private var pendingDropName: String?

    private var sortedLogins: [ServerLoginInfo] {
        viewModel.logins.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedLogins, selection: $viewModel.selectedLoginName, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { login in
                Text(login.name)
                    .font(TypographyTokens.Table.name)
                    .foregroundStyle(login.isDisabled ? ColorTokens.Text.tertiary : ColorTokens.Text.primary)
            }
            .width(min: 100, ideal: 180)

            TableColumn("Type") { login in
                Text(login.type.tSqlTypeDesc)
                    .font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 80, ideal: 120)

            TableColumn("Default Database") { login in
                if let db = login.defaultDatabase, !db.isEmpty {
                    Text(db)
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                } else {
                    Text("\u{2014}")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(min: 80, ideal: 120)

            TableColumn("Status") { login in
                Text(login.isDisabled ? "Disabled" : "Enabled")
                    .font(TypographyTokens.Table.status)
                    .foregroundStyle(login.isDisabled ? ColorTokens.Status.error : ColorTokens.Status.success)
            }
            .width(min: 60, ideal: 80)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: String.self) { selection in
            if let name = selection.first {
                let login = viewModel.logins.first { $0.name == name }

                // Group 6: Script as
                Menu("Script as", systemImage: "scroll") {
                    Button { scriptCreate(name: name) } label: {
                        Label("CREATE", systemImage: "plus.square")
                    }
                    Button { scriptDrop(name: name) } label: {
                        Label("DROP", systemImage: "minus.square")
                    }
                }

                Divider()

                // Group 8: Enable/Disable
                if let login {
                    Button {
                        Task { await viewModel.toggleLogin(name, enabled: login.isDisabled) }
                    } label: {
                        if login.isDisabled {
                            Label("Enable", systemImage: "checkmark.circle")
                        } else {
                            Label("Disable", systemImage: "nosign")
                        }
                    }
                }

                Divider()

                // Group 9: Destructive
                Button(role: .destructive) {
                    pendingDropName = name
                    showDropAlert = true
                } label: {
                    Label("Drop Login", systemImage: "trash")
                }

                Divider()

                // Group 10: Properties (always last)
                Button { openLoginEditor(name: name) } label: {
                    Label("Properties", systemImage: "info.circle")
                }
            } else {
                // Empty-space menu
                Button {
                    Task { await viewModel.loadCurrentSection() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    let value = environmentState.prepareLoginEditorWindow(
                        connectionSessionID: viewModel.connectionID,
                        existingLogin: nil
                    )
                    openWindow(id: LoginEditorWindow.sceneID, value: value)
                } label: {
                    Label("New Login", systemImage: "person.badge.plus")
                }
            }
        } primaryAction: { selection in
            if let name = selection.first {
                openLoginEditor(name: name)
            }
        }
        .alert("Drop Login?", isPresented: $showDropAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Drop", role: .destructive) {
                if let name = pendingDropName {
                    Task { await viewModel.dropLogin(name) }
                }
            }
        } message: {
            Text("Are you sure you want to drop the login \(pendingDropName ?? "")? This action cannot be undone.")
        }
    }

    private func openLoginEditor(name: String) {
        let value = environmentState.prepareLoginEditorWindow(
            connectionSessionID: viewModel.connectionID,
            existingLogin: name
        )
        openWindow(id: LoginEditorWindow.sceneID, value: value)
    }

    private func scriptCreate(name: String) {
        let escaped = "[\(name.replacingOccurrences(of: "]", with: "]]"))]"
        openScriptTab(sql: "CREATE LOGIN \(escaped)\nWITH PASSWORD = N'<password>',\n     DEFAULT_DATABASE = [master],\n     CHECK_POLICY = ON;\nGO")
    }

    private func scriptDrop(name: String) {
        let escaped = "[\(name.replacingOccurrences(of: "]", with: "]]"))]"
        openScriptTab(sql: "DROP LOGIN \(escaped);\nGO")
    }

    private func openScriptTab(sql: String) {
        if let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) {
            environmentState.openQueryTab(for: session, presetQuery: sql)
        }
    }
}
