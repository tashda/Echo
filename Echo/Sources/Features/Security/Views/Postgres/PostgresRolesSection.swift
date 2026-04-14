import SwiftUI
import PostgresKit

struct PostgresRolesSection: View {
    @Bindable var viewModel: PostgresDatabaseSecurityViewModel
    var onNewRole: () -> Void = {}
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(\.openWindow) private var openWindow

    @State private var pendingDropName: String?
    @State private var pendingReassignRole: String?
    @State private var reassignTargetRole = ""
    @State private var pendingDropOwnedRole: String?

    var body: some View {
        Table(viewModel.roles, selection: $viewModel.selectedRoleName) {
            TableColumn("Name") { role in
                HStack(spacing: SpacingTokens.xs) {
                    Image(systemName: role.canLogin ? "person.fill" : "person.2.fill")
                        .foregroundStyle(role.isSuperuser ? ColorTokens.Status.warning : ColorTokens.Text.tertiary)
                        .font(TypographyTokens.detail)
                    Text(role.name)
                        .font(TypographyTokens.Table.name)
                }
            }
            .width(min: 100, ideal: 180)

            TableColumn("Login") { role in
                Image(systemName: role.canLogin ? "checkmark" : "minus")
                    .foregroundStyle(role.canLogin ? ColorTokens.Status.success : ColorTokens.Text.tertiary)
                    .font(TypographyTokens.detail)
            }
            .width(50)

            TableColumn("Superuser") { role in
                Image(systemName: role.isSuperuser ? "checkmark" : "minus")
                    .foregroundStyle(role.isSuperuser ? ColorTokens.Status.warning : ColorTokens.Text.tertiary)
                    .font(TypographyTokens.detail)
            }
            .width(70)

            TableColumn("Create DB") { role in
                Image(systemName: role.canCreateDB ? "checkmark" : "minus")
                    .foregroundStyle(role.canCreateDB ? ColorTokens.Status.info : ColorTokens.Text.tertiary)
                    .font(TypographyTokens.detail)
            }
            .width(70)

            TableColumn("Create Role") { role in
                Image(systemName: role.canCreateRole ? "checkmark" : "minus")
                    .foregroundStyle(role.canCreateRole ? ColorTokens.Status.info : ColorTokens.Text.tertiary)
                    .font(TypographyTokens.detail)
            }
            .width(80)

            TableColumn("Replication") { role in
                Image(systemName: role.isReplication ? "checkmark" : "minus")
                    .foregroundStyle(role.isReplication ? ColorTokens.Status.info : ColorTokens.Text.tertiary)
                    .font(TypographyTokens.detail)
            }
            .width(80)

            TableColumn("Conn. Limit") { role in
                Text(role.connectionLimit == -1 ? "Unlimited" : "\(role.connectionLimit)")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 70, ideal: 90)

            TableColumn("Valid Until") { role in
                if let validUntil = role.validUntil, !validUntil.isEmpty {
                    Text(validUntil)
                        .font(TypographyTokens.detail)
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
                Button { openRoleEditor(name: name) } label: {
                    Label("Edit Role", systemImage: "pencil")
                }

                Divider()

                Menu("Script as", systemImage: "scroll") {
                    Button { scriptCreate(name: name) } label: {
                        Label("CREATE ROLE", systemImage: "plus.square")
                    }
                    Button { scriptDrop(name: name) } label: {
                        Label("DROP ROLE", systemImage: "minus.square")
                    }
                }

                Divider()

                Button {
                    reassignTargetRole = ""
                    pendingReassignRole = name
                } label: {
                    Label("Reassign Owned", systemImage: "arrow.right.arrow.left")
                }

                Button(role: .destructive) {
                    pendingDropOwnedRole = name
                } label: {
                    Label("Drop Owned", systemImage: "xmark.bin")
                }

                Divider()

                Button(role: .destructive) {
                    pendingDropName = name
                } label: {
                    Label("Drop Role", systemImage: "trash")
                }
            } else {
                Button { onNewRole() } label: {
                    Label("New Role", systemImage: "person.badge.plus")
                }

                Divider()

                Button {
                    Task { await viewModel.loadCurrentSection() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        } primaryAction: { selection in
            if let name = selection.first {
                openRoleEditor(name: name)
            }
        }
        .dropConfirmationAlert(objectType: "Role", objectName: $pendingDropName) { name in
            Task { await viewModel.dropRole(name) }
        }
        .dropConfirmationAlert(objectType: "Owned Objects", objectName: $pendingDropOwnedRole, cascade: true) { role in
            Task { await viewModel.dropOwned(by: role) }
        }
        .alert("Reassign Owned Objects", isPresented: Binding(
            get: { pendingReassignRole != nil },
            set: { if !$0 { pendingReassignRole = nil } }
        )) {
            TextField("Target role", text: $reassignTargetRole, prompt: Text("e.g. postgres"))
            Button("Cancel", role: .cancel) {}
            Button("Reassign") {
                let target = reassignTargetRole.trimmingCharacters(in: .whitespacesAndNewlines)
                if let source = pendingReassignRole, !target.isEmpty {
                    Task { await viewModel.reassignOwned(from: source, to: target) }
                }
            }
        } message: {
            Text("Transfer all objects owned by \"\(pendingReassignRole ?? "")\" to another role.")
        }
    }

    private func openRoleEditor(name: String) {
        let value = environmentState.preparePgRoleEditorWindow(
            connectionSessionID: viewModel.connectionID,
            existingRole: name
        )
        openWindow(id: PgRoleEditorWindow.sceneID, value: value)
    }

    private func scriptCreate(name: String) {
        let quoted = quoteIdentifier(name)
        openScriptTab(sql: "CREATE ROLE \(quoted);")
    }

    private func scriptDrop(name: String) {
        let quoted = quoteIdentifier(name)
        openScriptTab(sql: "DROP ROLE IF EXISTS \(quoted);")
    }

    private func quoteIdentifier(_ name: String) -> String {
        let escaped = name.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func openScriptTab(sql: String) {
        if let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) {
            environmentState.openQueryTab(for: session, presetQuery: sql)
        }
    }
}

// MARK: - Table conformance for PostgresRoleInfo

extension PostgresRoleInfo: @retroactive Identifiable {
    public var id: String { name }
}
