import SwiftUI
import SQLServerKit

struct MSSQLSecurityAppRolesSection: View {
    @Bindable var viewModel: DatabaseSecurityViewModel
    var onNewAppRole: () -> Void = {}
    @Environment(EnvironmentState.self) private var environmentState

    @State private var showDropAlert = false
    @State private var pendingDropName: String?

    var body: some View {
        Table(viewModel.appRoles, selection: $viewModel.selectedAppRoleName) {
            TableColumn("Name") { role in
                Text(role.name)
                    .font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 180)

            TableColumn("Default Schema") { role in
                if let schema = role.defaultSchema, !schema.isEmpty {
                    Text(schema)
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                } else {
                    Text("\u{2014}")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(min: 80, ideal: 120)

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
                    Label("Drop Application Role", systemImage: "trash")
                }
            } else {
                // Empty-space menu
                Button {
                    Task { await viewModel.loadCurrentSection() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button { onNewAppRole() } label: {
                    Label("New Application Role", systemImage: "person.badge.key")
                }
            }
        } primaryAction: { _ in }
        .alert("Drop Application Role?", isPresented: $showDropAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Drop", role: .destructive) {
                if let name = pendingDropName {
                    Task { await viewModel.dropAppRole(name) }
                }
            }
        } message: {
            Text("Are you sure you want to drop the application role \(pendingDropName ?? "")? This action cannot be undone.")
        }
    }

    private func scriptCreate(name: String) {
        let escaped = "[\(name.replacingOccurrences(of: "]", with: "]]"))]"
        openScriptTab(sql: "CREATE APPLICATION ROLE \(escaped)\nWITH PASSWORD = N'<password>',\n     DEFAULT_SCHEMA = [dbo];\nGO")
    }

    private func scriptDrop(name: String) {
        let escaped = "[\(name.replacingOccurrences(of: "]", with: "]]"))]"
        openScriptTab(sql: "DROP APPLICATION ROLE \(escaped);\nGO")
    }

    private func openScriptTab(sql: String) {
        if let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) {
            environmentState.openQueryTab(for: session, presetQuery: sql)
        }
    }
}
