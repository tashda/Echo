import SwiftUI
import SQLServerKit

struct MSSQLSecurityUsersSection: View {
    @Bindable var viewModel: DatabaseSecurityViewModel
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(\.openWindow) private var openWindow

    @State private var sortOrder = [KeyPathComparator(\UserInfo.name)]
    @State private var showDropAlert = false
    @State private var pendingDropName: String?

    private var sortedUsers: [UserInfo] {
        viewModel.users.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedUsers, selection: $viewModel.selectedUserName, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { user in
                Text(user.name)
                    .font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 160)

            TableColumn("Type", value: \.type) { user in
                Text(user.type)
                    .font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 80, ideal: 120)

            TableColumn("Default Schema") { user in
                if let schema = user.defaultSchema, !schema.isEmpty {
                    Text(schema)
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                } else {
                    Text("\u{2014}")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(min: 60, ideal: 100)

            TableColumn("Login") { user in
                if let login = user.loginName, !login.isEmpty {
                    Text(login)
                        .font(TypographyTokens.Table.secondaryName)
                } else {
                    Text("\u{2014}")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(min: 80, ideal: 120)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: String.self) { selection in
            if let name = selection.first {
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

                // Group 9: Destructive
                Button(role: .destructive) {
                    pendingDropName = name
                    showDropAlert = true
                } label: {
                    Label("Drop User", systemImage: "trash")
                }

                Divider()

                // Group 10: Properties
                Button { openUserEditor(name: name) } label: {
                    Label("Properties", systemImage: "info.circle")
                }
            } else {
                // Empty-space menu
                Button {
                    Task { await viewModel.loadCurrentSection() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button { openUserEditor(name: nil) } label: {
                    Label("New User", systemImage: "person.badge.plus")
                }
            }
        } primaryAction: { selection in
            if let name = selection.first {
                openUserEditor(name: name)
            }
        }
        .alert("Drop User?", isPresented: $showDropAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Drop", role: .destructive) {
                if let name = pendingDropName {
                    Task { await viewModel.dropUser(name) }
                }
            }
        } message: {
            Text("Are you sure you want to drop the user \(pendingDropName ?? "")? This action cannot be undone.")
        }
    }

    private func openUserEditor(name: String?) {
        guard let db = viewModel.selectedDatabase else { return }
        let value = environmentState.prepareUserEditorWindow(
            connectionSessionID: viewModel.connectionID,
            database: db,
            existingUser: name
        )
        openWindow(id: UserEditorWindow.sceneID, value: value)
    }

    private func scriptCreate(name: String) {
        let escaped = "[\(name.replacingOccurrences(of: "]", with: "]]"))]"
        openScriptTab(sql: "CREATE USER \(escaped) WITHOUT LOGIN\nWITH DEFAULT_SCHEMA = [dbo];\nGO")
    }

    private func scriptDrop(name: String) {
        let escaped = "[\(name.replacingOccurrences(of: "]", with: "]]"))]"
        openScriptTab(sql: "DROP USER \(escaped);\nGO")
    }

    private func openScriptTab(sql: String) {
        if let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) {
            environmentState.openQueryTab(for: session, presetQuery: sql)
        }
    }
}
