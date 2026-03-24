import SwiftUI
import SQLServerKit

struct MSSQLSecurityRolesSection: View {
    @Bindable var viewModel: DatabaseSecurityViewModel
    var onNewRole: () -> Void = {}
    @Environment(EnvironmentState.self) private var environmentState

    @State private var sortOrder = [KeyPathComparator(\RoleInfo.name)]
    @State private var showDropAlert = false
    @State private var pendingDropName: String?

    private var sortedRoles: [RoleInfo] {
        viewModel.roles.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedRoles, selection: $viewModel.selectedRoleName, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { role in
                Text(role.name)
                    .font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 180)

            TableColumn("Type") { role in
                Text(role.isFixedRole ? "Fixed" : "Custom")
                    .font(TypographyTokens.Table.category)
                    .foregroundStyle(role.isFixedRole ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
            }
            .width(min: 60, ideal: 80)

            TableColumn("Created") { role in
                if let date = role.createDate, !date.isEmpty {
                    Text(date)
                        .font(TypographyTokens.Table.date)
                        .foregroundStyle(ColorTokens.Text.secondary)
                } else {
                    Text("\u{2014}")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(min: 80, ideal: 140)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: String.self) { selection in
            if let name = selection.first {
                let role = viewModel.roles.first { $0.name == name }
                let isFixed = role?.isFixedRole ?? false

                // Group 3: View
                Button {
                    Task { await loadMembersToInspector(roleName: name) }
                } label: {
                    Label("Show Members", systemImage: "person.2")
                }

                if !isFixed {
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

                    Divider()

                    // Group 9: Destructive
                    Button(role: .destructive) {
                        pendingDropName = name
                        showDropAlert = true
                    } label: {
                        Label("Drop Role", systemImage: "trash")
                    }
                }
            } else {
                // Empty-space menu
                Button {
                    Task { await viewModel.loadCurrentSection() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button { onNewRole() } label: {
                    Label("New Role\u{2026}", systemImage: "person.badge.plus")
                }
            }
        } primaryAction: { selection in
            if let name = selection.first {
                Task { await loadMembersToInspector(roleName: name) }
            }
        }
        .alert("Drop Role?", isPresented: $showDropAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Drop", role: .destructive) {
                if let name = pendingDropName {
                    Task { await viewModel.dropRole(name) }
                }
            }
        } message: {
            Text("Are you sure you want to drop the role \(pendingDropName ?? "")? This action cannot be undone.")
        }
    }

    // MARK: - Inspector

    private func loadMembersToInspector(roleName: String) async {
        guard let mssql = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID)?.session as? MSSQLSession else { return }
        do {
            _ = try? await mssql.security.listRoles() // ensure DB context
            let members = try await mssql.security.listRoleMembers(role: roleName)
            let role = viewModel.roles.first { $0.name == roleName }
            var fields: [DatabaseObjectInspectorContent.Field] = [
                .init(label: "Type", value: role?.isFixedRole == true ? "Fixed" : "Custom")
            ]
            for member in members {
                fields.append(.init(label: "Member", value: member))
            }
            if members.isEmpty {
                fields.append(.init(label: "Members", value: "None"))
            }
            environmentState.dataInspectorContent = .databaseObject(
                DatabaseObjectInspectorContent(title: roleName, subtitle: "Database Role", fields: fields)
            )
        } catch { }
    }

    // MARK: - Scripts

    private func scriptCreate(name: String) {
        let escaped = "[\(name.replacingOccurrences(of: "]", with: "]]"))]"
        openScriptTab(sql: "CREATE ROLE \(escaped);\nGO")
    }

    private func scriptDrop(name: String) {
        let escaped = "[\(name.replacingOccurrences(of: "]", with: "]]"))]"
        openScriptTab(sql: "DROP ROLE \(escaped);\nGO")
    }

    private func openScriptTab(sql: String) {
        if let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) {
            environmentState.openQueryTab(for: session, presetQuery: sql)
        }
    }
}
