import SwiftUI
import SQLServerKit

// MARK: - Database Schemas

extension ObjectBrowserSidebarView {

    @ViewBuilder
    func dbSchemasSection(session: ConnectionSession, dbKey: String) -> some View {
        let schemas = viewModel.dbSecuritySchemasByDB[dbKey] ?? []
        let isExpanded = viewModel.dbSecuritySchemasExpandedByDB[dbKey] ?? false

        VStack(alignment: .leading, spacing: 0) {
            securitySectionHeader(
                depth: SecuritySidebarDepth.databaseSection,
                title: "Schemas",
                icon: "folder",
                count: schemas.count,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.dbSecuritySchemasExpandedByDB[dbKey] = !isExpanded
                }
            }

            if isExpanded {
                if schemas.isEmpty {
                    SidebarRow(
                        depth: SecuritySidebarDepth.databaseLeaf,
                        icon: .none,
                        label: "No schemas found",
                        labelColor: ColorTokens.Text.tertiary,
                        labelFont: TypographyTokens.detail
                    )
                } else {
                    ForEach(schemas) { schema in
                        dbSchemaRow(schema: schema, session: session)
                    }
                }
            }
        }
    }

    func dbSchemaRow(schema: ObjectBrowserSidebarViewModel.SecuritySchemaItem, session: ConnectionSession) -> some View {
        let colored = projectStore.globalSettings.sidebarIconColorMode == .colorful
        return SidebarRow(
            depth: SecuritySidebarDepth.databaseLeaf,
            icon: .system("folder"),
            label: schema.name,
            iconColor: ExplorerSidebarPalette.folderIconColor(title: "Schemas", colored: colored)
        ) {
            if let owner = schema.owner, !owner.isEmpty {
                Text(owner)
                    .font(SidebarRowConstants.trailingFont)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .lineLimit(1)
            }
        }
        .contextMenu {
            Button {
                if session.connection.databaseType == .microsoftSQL {
                    openScriptTab(
                        sql: """
                        SELECT perm.state_desc, perm.permission_name, dp.name AS grantee
                        FROM sys.database_permissions perm
                        JOIN sys.schemas s ON perm.major_id = s.schema_id
                        JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
                        WHERE s.name = N'\(schema.name)' AND perm.class = 3
                        ORDER BY dp.name, perm.permission_name;
                        """,
                        session: session
                    )
                } else {
                    openScriptTab(
                        sql: """
                        SELECT grantee, privilege_type, is_grantable
                        FROM information_schema.usage_privileges
                        WHERE object_schema = '\(schema.name)'
                        UNION ALL
                        SELECT grantee, privilege_type, is_grantable
                        FROM information_schema.role_table_grants
                        WHERE table_schema = '\(schema.name)'
                        ORDER BY 1, 2;
                        """,
                        session: session
                    )
                }
            } label: {
                Label("Show Privileges", systemImage: "lock.shield")
            }
            Divider()
            Menu("Script as", systemImage: "scroll") {
                if session.connection.databaseType == .microsoftSQL {
                    Button {
                        let auth = schema.owner.map { " AUTHORIZATION [\($0)]" } ?? ""
                        openScriptTab(sql: "CREATE SCHEMA [\(schema.name)]\(auth);", session: session)
                    } label: {
                        Label("CREATE", systemImage: "plus.rectangle.on.rectangle")
                    }
                    Divider()
                    Button {
                        openScriptTab(sql: "DROP SCHEMA [\(schema.name)];", session: session)
                    } label: {
                        Label("DROP", systemImage: "trash")
                    }
                } else if session.connection.databaseType == .postgresql {
                    Button {
                        let auth = schema.owner.map { " AUTHORIZATION \"\($0)\"" } ?? ""
                        openScriptTab(sql: "CREATE SCHEMA \"\(schema.name)\"\(auth);", session: session)
                    } label: {
                        Label("CREATE", systemImage: "plus.rectangle.on.rectangle")
                    }
                    Divider()
                    Button {
                        openScriptTab(sql: "DROP SCHEMA \"\(schema.name)\" CASCADE;", session: session)
                    } label: {
                        Label("DROP", systemImage: "trash")
                    }
                }
            }
        }
    }
}
