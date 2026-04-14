import SwiftUI
import PostgresKit

struct PostgresSchemasSection: View {
    @Bindable var viewModel: PostgresDatabaseSecurityViewModel
    var onNewSchema: () -> Void = {}
    @Environment(EnvironmentState.self) private var environmentState

    @State private var pendingDropName: String?
    @State private var pendingCascadeDropName: String?

    var body: some View {
        Table(viewModel.schemas, selection: $viewModel.selectedSchemaName) {
            TableColumn("Name") { schema in
                Text(schema.name)
                    .font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 180)

            TableColumn("Owner") { schema in
                Text(schema.owner)
                    .font(TypographyTokens.Table.secondaryName)
            }
            .width(min: 80, ideal: 140)

            TableColumn("Description") { schema in
                if let desc = schema.description, !desc.isEmpty {
                    Text(desc)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                } else {
                    Text("\u{2014}")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(min: 100, ideal: 240)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: String.self) { selection in
            if let name = selection.first {
                Button { scriptPrivileges(name: name) } label: {
                    Label("Show Privileges", systemImage: "eye")
                }

                Divider()

                Menu("Script as", systemImage: "scroll") {
                    Button {
                        openScript(ScriptingActions.scriptCreate(objectType: "SCHEMA", qualifiedName: ScriptingActions.pgQuote(name)))
                    } label: { Label("CREATE", systemImage: "plus.square") }

                    Button {
                        openScript(ScriptingActions.scriptDrop(objectType: "SCHEMA", qualifiedName: ScriptingActions.pgQuote(name)))
                    } label: { Label("DROP", systemImage: "minus.square") }
                }

                Divider()

                Button(role: .destructive) { pendingDropName = name } label: {
                    Label("Drop Schema", systemImage: "trash")
                }

                Button(role: .destructive) { pendingCascadeDropName = name } label: {
                    Label("Drop Schema (CASCADE)", systemImage: "trash.fill")
                }
            } else {
                Button {
                    Task { await viewModel.loadCurrentSection() }
                } label: { Label("Refresh", systemImage: "arrow.clockwise") }

                Button { onNewSchema() } label: {
                    Label("New Schema", systemImage: "rectangle.stack")
                }
            }
        } primaryAction: { _ in }
        .dropConfirmationAlert(objectType: "Schema", objectName: $pendingDropName) { name in
            Task { await viewModel.dropSchema(name, cascade: false) }
        }
        .dropConfirmationAlert(objectType: "Schema", objectName: $pendingCascadeDropName, cascade: true) { name in
            Task { await viewModel.dropSchema(name, cascade: true) }
        }
    }

    private func scriptPrivileges(name: String) {
        let escaped = name.replacingOccurrences(of: "'", with: "''")
        let sql = """
        SELECT grantee, privilege_type, is_grantable
        FROM information_schema.usage_privileges
        WHERE object_schema = '\(escaped)'
        UNION ALL
        SELECT grantee, privilege_type, is_grantable
        FROM information_schema.role_usage_grants
        WHERE object_schema = '\(escaped)'
        ORDER BY 1, 2;
        """
        openScript(sql)
    }

    private func openScript(_ sql: String) {
        environmentState.openScriptTab(sql: sql, connectionID: viewModel.connectionID)
    }
}

extension PostgresSchemaInfo: @retroactive Identifiable {
    public var id: String { name }
}
