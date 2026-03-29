import SwiftUI
import SQLServerKit

struct MSSQLSecurityServerRolesSection: View {
    @Bindable var viewModel: ServerSecurityViewModel
    var onNewRole: () -> Void
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState

    @State private var sortOrder = [KeyPathComparator(\ServerRoleInfo.name)]

    private var sortedRoles: [ServerRoleInfo] {
        viewModel.serverRoles.sorted(using: sortOrder)
    }

    var body: some View {
        rolesTable
        .onChange(of: viewModel.selectedServerRoleName) { _, newSelection in
            if let name = newSelection.first {
                Task { await loadMembersToInspector(roleName: name, toggle: false) }
            }
        }
    }

    private var rolesTable: some View {
        Table(sortedRoles, selection: $viewModel.selectedServerRoleName, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { role in
                Text(role.name)
                    .font(TypographyTokens.Table.name)
                    .foregroundStyle(isFixedOrSystem(role) ? ColorTokens.Text.secondary : ColorTokens.Text.primary)
            }
            .width(min: 100, ideal: 200)

            TableColumn("Type") { role in
                Text(roleTypeLabel(role))
                    .font(TypographyTokens.Table.category)
                    .foregroundStyle(isFixedOrSystem(role) ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
            }
            .width(min: 60, ideal: 100)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: String.self) { selection in
            if let name = selection.first {
                Button {
                    Task { await loadMembersToInspector(roleName: name, toggle: false) }
                } label: {
                    Label("Show Members", systemImage: "person.2")
                }

                if !isFixedOrSystemByName(name) {
                    Divider()

                    // Group 6: Script as
                    Menu("Script as", systemImage: "scroll") {
                        Button { scriptCreate(name: name) } label: {
                            Label("CREATE", systemImage: "plus.square")
                        }
                        Button { scriptDrop(name: name) } label: {
                            Label("DROP", systemImage: "minus.square")
                        }
                    }
                }
            } else {
                // Empty space context menu
                Button {
                    Task { await viewModel.loadCurrentSection() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button { onNewRole() } label: {
                    Label("New Server Role", systemImage: "shield.badge.plus")
                }
            }
        } primaryAction: { selection in
            if let name = selection.first {
                Task { await loadMembersToInspector(roleName: name, toggle: true) }
            }
        }
    }

    // MARK: - Role Classification

    private func isFixedOrSystem(_ role: ServerRoleInfo) -> Bool {
        role.isFixed || role.name == "public" || role.name.hasPrefix("##MS_")
    }

    private func isFixedOrSystemByName(_ name: String) -> Bool {
        if let role = viewModel.serverRoles.first(where: { $0.name == name }) {
            return isFixedOrSystem(role)
        }
        return name == "public" || name.hasPrefix("##MS_")
    }

    private func roleTypeLabel(_ role: ServerRoleInfo) -> String {
        if role.isFixed || role.name == "public" || role.name.hasPrefix("##MS_") {
            return "Fixed"
        }
        return "Custom"
    }

    // MARK: - Inspector

    private func loadMembersToInspector(roleName: String, toggle: Bool) async {
        if toggle {
            appState.showInfoSidebar.toggle()
            guard appState.showInfoSidebar else { return }
        } else if !appState.showInfoSidebar {
            appState.showInfoSidebar = true
        }

        guard let mssql = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID)?.session as? MSSQLSession else { return }
        do {
            let members = try await mssql.serverSecurity.listServerRoleMembers(role: roleName)
            let role = viewModel.serverRoles.first { $0.name == roleName }
            var fields: [DatabaseObjectInspectorContent.Field] = [
                .init(label: "Type", value: role.map { roleTypeLabel($0) } ?? "Unknown")
            ]
            for member in members {
                fields.append(.init(label: "Member", value: member))
            }
            if members.isEmpty {
                fields.append(.init(label: "Members", value: "None"))
            }
            environmentState.dataInspectorContent = .databaseObject(
                DatabaseObjectInspectorContent(
                    title: roleName,
                    subtitle: "Server Role",
                    fields: fields
                )
            )
        } catch { }
    }

    // MARK: - Scripts

    private func scriptCreate(name: String) {
        let escaped = "[\(name.replacingOccurrences(of: "]", with: "]]"))]"
        openScriptTab(sql: "CREATE SERVER ROLE \(escaped);\nGO")
    }

    private func scriptDrop(name: String) {
        let escaped = "[\(name.replacingOccurrences(of: "]", with: "]]"))]"
        openScriptTab(sql: "DROP SERVER ROLE \(escaped);\nGO")
    }

    private func openScriptTab(sql: String) {
        if let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) {
            environmentState.openQueryTab(for: session, presetQuery: sql)
        }
    }
}
