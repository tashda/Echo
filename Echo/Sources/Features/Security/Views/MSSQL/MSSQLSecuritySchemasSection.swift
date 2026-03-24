import SwiftUI
import SQLServerKit

struct MSSQLSecuritySchemasSection: View {
    @Bindable var viewModel: DatabaseSecurityViewModel
    var onNewSchema: () -> Void = {}
    @Environment(EnvironmentState.self) private var environmentState

    @State private var showDropAlert = false
    @State private var pendingDropName: String?

    var body: some View {
        Table(viewModel.schemas, selection: $viewModel.selectedSchemaName) {
            TableColumn("Name") { schema in
                Text(schema.name)
                    .font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 180)

            TableColumn("Owner") { schema in
                if let owner = schema.owner, !owner.isEmpty {
                    Text(owner)
                        .font(TypographyTokens.Table.secondaryName)
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
                // Group 3: View
                Button { scriptPrivileges(name: name) } label: {
                    Label("Show Privileges", systemImage: "eye")
                }

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
                    Label("Drop Schema", systemImage: "trash")
                }
            } else {
                // Empty-space menu
                Button {
                    Task { await viewModel.loadCurrentSection() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button { onNewSchema() } label: {
                    Label("New Schema", systemImage: "rectangle.stack")
                }
            }
        } primaryAction: { _ in }
        .alert("Drop Schema?", isPresented: $showDropAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Drop", role: .destructive) {
                if let name = pendingDropName {
                    Task { await viewModel.dropSchema(name) }
                }
            }
        } message: {
            Text("Are you sure you want to drop the schema \(pendingDropName ?? "")? This action cannot be undone.")
        }
    }

    private func scriptPrivileges(name: String) {
        let escaped = name.replacingOccurrences(of: "'", with: "''")
        let sql = """
        SELECT
            dp.state_desc + ' ' + dp.permission_name AS permission,
            dp.class_desc,
            SCHEMA_NAME(dp.major_id) AS on_schema,
            pr.name AS grantee
        FROM sys.database_permissions dp
        JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
        WHERE dp.class = 3 AND SCHEMA_NAME(dp.major_id) = N'\(escaped)'
        ORDER BY pr.name, dp.permission_name;
        """
        openScriptTab(sql: sql)
    }

    private func scriptCreate(name: String) {
        let escaped = "[\(name.replacingOccurrences(of: "]", with: "]]"))]"
        openScriptTab(sql: "CREATE SCHEMA \(escaped);\nGO")
    }

    private func scriptDrop(name: String) {
        let escaped = "[\(name.replacingOccurrences(of: "]", with: "]]"))]"
        openScriptTab(sql: "DROP SCHEMA \(escaped);\nGO")
    }

    private func openScriptTab(sql: String) {
        if let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) {
            environmentState.openQueryTab(for: session, presetQuery: sql)
        }
    }
}
