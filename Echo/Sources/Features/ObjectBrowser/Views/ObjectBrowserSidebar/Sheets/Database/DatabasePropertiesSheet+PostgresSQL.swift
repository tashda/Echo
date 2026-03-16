import SwiftUI
import PostgresKit

// MARK: - PostgreSQL SQL Page

extension DatabasePropertiesSheet {

    @ViewBuilder
    func postgresSQLPage() -> some View {
        let sql = pgGenerateFullSQL()
        Section("SQL") {
            if sql.isEmpty {
                Text("No database-level configuration.")
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .font(TypographyTokens.detail)
            } else {
                Text(sql)
                    .font(TypographyTokens.monospaced)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SpacingTokens.xs)
            }
        }
    }

    /// Generate SQL representing all current database-level configuration.
    func pgGenerateFullSQL() -> String {
        var statements: [String] = []
        let db = pgQuoteIdent(databaseName)

        // Parameters
        for param in pgParams {
            statements.append("ALTER DATABASE \(db) SET \(param.name) = '\(pgEscape(param.value))';")
        }

        // ACL grants
        for entry in pgACLEntries {
            let grantee = entry.grantee.isEmpty ? "PUBLIC" : pgQuoteIdent(entry.grantee)
            let privs = entry.privileges.map(\.privilege.rawValue).joined(separator: ", ")
            if !privs.isEmpty {
                statements.append("GRANT \(privs) ON DATABASE \(db) TO \(grantee);")
            }
        }

        // Default privileges
        for entry in pgDefaultPrivileges {
            let schema = entry.schema.isEmpty ? "public" : entry.schema
            let grantee = entry.grantee.isEmpty ? "PUBLIC" : pgQuoteIdent(entry.grantee)
            let privs = entry.privileges.map(\.privilege.rawValue).joined(separator: ", ")
            if !privs.isEmpty {
                statements.append("ALTER DEFAULT PRIVILEGES IN SCHEMA \(pgQuoteIdent(schema)) GRANT \(privs) ON \(entry.objectType.rawValue) TO \(grantee);")
            }
        }

        return statements.joined(separator: "\n\n")
    }

    private func pgQuoteIdent(_ name: String) -> String {
        "\"\(name.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private func pgEscape(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }
}
