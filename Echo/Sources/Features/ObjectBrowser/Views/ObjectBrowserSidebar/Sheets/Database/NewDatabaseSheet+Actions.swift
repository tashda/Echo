import SwiftUI
import PostgresKit
import SQLServerKit

// MARK: - Data Loading & Create Actions

extension NewDatabaseSheet {

    func loadOptions() async {
        do {
            if isPostgres {
                try await loadPostgresOptions()
            } else if isMSSQL {
                try await loadMSSQLOptions()
            }
        } catch {
            // Non-fatal — the form is still usable without lookup data
        }
        isLoadingOptions = false
    }

    private func loadPostgresOptions() async throws {
        guard let pgSession = session.session as? PostgresSession else { return }
        let client = pgSession.client

        let roles = (try? await client.security.listRoles()) ?? []
        pgRoles = roles.map(\.name).sorted()

        pgTemplates = (try? await client.metadata.listDatabaseTemplates()) ?? ["template0", "template1"]
        pgEncodings = (try? await client.metadata.listEncodings()) ?? ["UTF8"]
        pgCollations = (try? await client.metadata.listCollations()) ?? []
        pgTablespaces = (try? await client.metadata.listTablespaces()) ?? ["pg_default"]
    }

    private func loadMSSQLOptions() async throws {
        guard let adapter = session.session as? SQLServerSessionAdapter else { return }
        mssqlCollations = (try? await adapter.client.admin.listCollations()) ?? []
    }

    // MARK: - Create

    func createDatabase() {
        let trimmedName = databaseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                if isPostgres {
                    try await createPostgresDatabase(name: trimmedName)
                } else if isMSSQL {
                    try await createMSSQLDatabase(name: trimmedName)
                }

                environmentState.notificationEngine?.post(
                    category: .databaseCreated,
                    message: "Database \"\(trimmedName)\" created."
                )
                Task {
                    await environmentState.refreshDatabaseStructure(for: session.id, scope: .full)
                }
                onDismiss()
            } catch {
                isCreating = false
                errorMessage = error.localizedDescription
                environmentState.notificationEngine?.post(
                    category: .databaseCreationFailed,
                    message: error.localizedDescription
                )
            }
        }
    }

    private func createPostgresDatabase(name: String) async throws {
        guard let pgSession = session.session as? PostgresSession else { return }
        let client = pgSession.client

        try await client.admin.createDatabase(
            name: name,
            owner: owner.isEmpty ? nil : owner,
            template: pgTemplate,
            encoding: pgEncoding.isEmpty ? nil : pgEncoding,
            lcCollate: pgCollation.isEmpty ? nil : pgCollation,
            lcCtype: pgCtype.isEmpty ? nil : pgCtype,
            icuLocale: pgIcuLocale.isEmpty ? nil : pgIcuLocale,
            icuRules: pgIcuRules.isEmpty ? nil : pgIcuRules,
            localeProvider: pgLocaleProvider == "libc" ? nil : pgLocaleProvider,
            tablespace: pgTablespace == "pg_default" ? nil : pgTablespace,
            allowConnections: pgAllowConnections ? nil : false,
            connectionLimit: pgConnectionLimit == -1 ? nil : pgConnectionLimit,
            isTemplate: pgIsTemplate ? true : nil,
            strategy: pgStrategy == "wal_log" ? nil : pgStrategy
        )

        // Add comment if provided
        if !pgComment.isEmpty {
            try await client.admin.addDatabaseComment(name: name, comment: pgComment)
        }
    }

    private func createMSSQLDatabase(name: String) async throws {
        guard let adapter = session.session as? SQLServerSessionAdapter else { return }

        let options = SQLServerCreateDatabaseOptions(
            collation: mssqlCollation.isEmpty ? nil : mssqlCollation,
            containment: mssqlContainment == "NONE" ? nil : mssqlContainment,
            dataFileName: mssqlDataFileName.isEmpty ? nil : mssqlDataFileName,
            dataFileSize: mssqlDataFileSize == 8 ? nil : mssqlDataFileSize,
            dataFileMaxSize: mssqlDataFileMaxSize == 0 ? nil : mssqlDataFileMaxSize,
            dataFileGrowth: mssqlDataFileGrowth == 64 ? nil : mssqlDataFileGrowth,
            logFileName: mssqlLogFileName.isEmpty ? nil : mssqlLogFileName,
            logFileSize: mssqlLogFileSize == 8 ? nil : mssqlLogFileSize,
            logFileMaxSize: mssqlLogFileMaxSize == 0 ? nil : mssqlLogFileMaxSize,
            logFileGrowth: mssqlLogFileGrowth == 64 ? nil : mssqlLogFileGrowth
        )
        try await adapter.client.admin.createDatabase(
            name: name,
            options: options
        )

        // Change owner if specified
        if !owner.isEmpty {
            let escapedDb = "[" + name.replacingOccurrences(of: "]", with: "]]") + "]"
            let escapedOwner = owner.replacingOccurrences(of: "'", with: "''")
            _ = try await adapter.client.execute("ALTER AUTHORIZATION ON DATABASE::\(escapedDb) TO [\(escapedOwner)]")
        }
    }

    // MARK: - SQL Preview

    @ViewBuilder
    func sqlPage() -> some View {
        let sql = generateSQL()
        Section("SQL") {
            if sql.isEmpty {
                Text("Enter a database name to preview SQL.")
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

    func generateSQL() -> String {
        let trimmedName = databaseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return "" }

        if isPostgres {
            return generatePostgresSQL(name: trimmedName)
        } else if isMSSQL {
            return generateMSSQLSQL(name: trimmedName)
        }
        return ""
    }

    private func generatePostgresSQL(name: String) -> String {
        var sql = "CREATE DATABASE \(pgQuoteIdent(name))"
        var options: [String] = []

        if !owner.isEmpty { options.append("    OWNER = \(pgQuoteIdent(owner))") }
        if let template = pgTemplate { options.append("    TEMPLATE = \(pgQuoteIdent(template))") }
        if !pgEncoding.isEmpty { options.append("    ENCODING = '\(pgEncoding)'") }
        if pgLocaleProvider != "libc" { options.append("    LOCALE_PROVIDER = \(pgLocaleProvider)") }

        if pgLocaleProvider == "libc" {
            if !pgCollation.isEmpty { options.append("    LC_COLLATE = '\(pgCollation)'") }
            if !pgCtype.isEmpty { options.append("    LC_CTYPE = '\(pgCtype)'") }
        } else {
            if !pgIcuLocale.isEmpty { options.append("    ICU_LOCALE = '\(pgIcuLocale)'") }
            if !pgIcuRules.isEmpty { options.append("    ICU_RULES = '\(pgIcuRules)'") }
        }

        if pgTablespace != "pg_default" { options.append("    TABLESPACE = \(pgQuoteIdent(pgTablespace))") }
        if pgConnectionLimit != -1 { options.append("    CONNECTION LIMIT = \(pgConnectionLimit)") }
        if pgIsTemplate { options.append("    IS_TEMPLATE = true") }
        if !pgAllowConnections { options.append("    ALLOW_CONNECTIONS = false") }
        if pgStrategy != "wal_log" { options.append("    STRATEGY = \(pgStrategy)") }

        if !options.isEmpty {
            sql += "\n    WITH\n" + options.joined(separator: "\n")
        }
        sql += ";"

        if !pgComment.isEmpty {
            let escaped = pgComment.replacingOccurrences(of: "'", with: "''")
            sql += "\n\nCOMMENT ON DATABASE \(pgQuoteIdent(name)) IS '\(escaped)';"
        }

        return sql
    }

    private func generateMSSQLSQL(name: String) -> String {
        let escaped = "[\(name.replacingOccurrences(of: "]", with: "]]"))]"
        var sql = "CREATE DATABASE \(escaped)"

        if !mssqlCollation.isEmpty {
            sql += "\n    COLLATE \(mssqlCollation)"
        }

        if mssqlContainment != "NONE" {
            sql += "\n    WITH CONTAINMENT = \(mssqlContainment)"
        }

        // Data file
        let hasDataSpec = !mssqlDataFileName.isEmpty || mssqlDataFileSize != 8
        if hasDataSpec {
            let logicalName = mssqlDataFileName.isEmpty ? name : mssqlDataFileName
            let escapedLogical = logicalName.replacingOccurrences(of: "'", with: "''")
            var parts = ["NAME = N'\(escapedLogical)'"]
            if mssqlDataFileSize != 8 { parts.append("SIZE = \(mssqlDataFileSize)MB") }
            if mssqlDataFileMaxSize > 0 { parts.append("MAXSIZE = \(mssqlDataFileMaxSize)MB") }
            if mssqlDataFileGrowth != 64 { parts.append("FILEGROWTH = \(mssqlDataFileGrowth)MB") }
            sql += "\n    ON PRIMARY (\(parts.joined(separator: ", ")))"
        }

        // Log file
        let hasLogSpec = !mssqlLogFileName.isEmpty || mssqlLogFileSize != 8
        if hasLogSpec {
            let logicalName = mssqlLogFileName.isEmpty ? "\(name)_log" : mssqlLogFileName
            let escapedLogical = logicalName.replacingOccurrences(of: "'", with: "''")
            var parts = ["NAME = N'\(escapedLogical)'"]
            if mssqlLogFileSize != 8 { parts.append("SIZE = \(mssqlLogFileSize)MB") }
            if mssqlLogFileMaxSize > 0 { parts.append("MAXSIZE = \(mssqlLogFileMaxSize)MB") }
            if mssqlLogFileGrowth != 64 { parts.append("FILEGROWTH = \(mssqlLogFileGrowth)MB") }
            sql += "\n    LOG ON (\(parts.joined(separator: ", ")))"
        }

        sql += ";"

        if !owner.isEmpty {
            let escapedOwner = owner.replacingOccurrences(of: "]", with: "]]")
            sql += "\n\nALTER AUTHORIZATION ON DATABASE::\(escaped) TO [\(escapedOwner)];"
        }

        return sql
    }

    private func pgQuoteIdent(_ name: String) -> String {
        "\"\(name.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
