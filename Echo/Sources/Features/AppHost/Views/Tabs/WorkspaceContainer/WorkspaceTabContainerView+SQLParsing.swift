import SwiftUI

// MARK: - SQL Parsing & Database Switch Detection

extension WorkspaceTabContainerView {

    func inferPrimaryObjectName(from sql: String) -> String? {
        let cleanedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedSQL.isEmpty else { return nil }

        let patterns = [
            #"(?i)\bfrom\s+([A-Za-z0-9_\.\"`]+)"#,
            #"(?i)\binto\s+([A-Za-z0-9_\.\"`]+)"#,
            #"(?i)\bupdate\s+([A-Za-z0-9_\.\"`]+)"#,
            #"(?i)\bdelete\s+from\s+([A-Za-z0-9_\.\"`]+)"#
        ]

        for pattern in patterns {
            if let match = firstMatch(in: cleanedSQL, pattern: pattern) {
                return normalizeIdentifier(match)
            }
        }

        return nil
    }

    func firstMatch(in sql: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: (sql as NSString).length)
        guard let match = regex.firstMatch(in: sql, options: [], range: range), match.numberOfRanges > 1 else { return nil }
        let matchRange = match.range(at: 1)
        guard let rangeInString = Range(matchRange, in: sql) else { return nil }
        return String(sql[rangeInString])
    }

    func normalizeIdentifier(_ identifier: String) -> String {
        let trimmed = identifier.trimmingCharacters(in: CharacterSet(charactersIn: "`\"'[]"))
        return trimmed
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "].[", with: ".")
    }

    func resolveSchemaAndTable(for identifier: String?, connection: SavedConnection) -> (schema: String, table: String)? {
        guard let identifier, !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let components = parseQualifiedIdentifier(identifier)
        guard let table = components.last, !table.isEmpty else { return nil }
        let schemaCandidate = components.count >= 2 ? components[components.count - 2] : nil
        let effectiveSchema: String?
        if let schemaCandidate, !schemaCandidate.isEmpty {
            effectiveSchema = schemaCandidate
        } else {
            effectiveSchema = defaultSchema(for: connection.databaseType, connection: connection)
        }

        switch connection.databaseType {
        case .mysql, .sqlite:
            let schema = effectiveSchema ?? connection.database.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !schema.isEmpty else { return nil }
            return (schema: schema, table: table)
        default:
            guard let schema = effectiveSchema, !schema.isEmpty else { return nil }
            return (schema: schema, table: table)
        }
    }

    func parseQualifiedIdentifier(_ identifier: String) -> [String] {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let sanitized = trimmed
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
        return sanitized.split(separator: ".").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    func defaultSchema(for type: DatabaseType, connection: SavedConnection) -> String? {
        switch type {
        case .microsoftSQL:
            return "dbo"
        case .postgresql:
            return "public"
        case .mysql:
            let database = connection.database.trimmingCharacters(in: .whitespacesAndNewlines)
            return database.isEmpty ? nil : database
        case .sqlite:
            return "main"
        }
    }

    // MARK: - USE Database Detection

    /// Detects `USE [database]` statements in the executed SQL and updates the tab's active database context.
    /// Applies to MSSQL and MySQL which support switching databases on the same connection.
    func detectAndApplyDatabaseSwitch(originalSQL: String, tab: WorkspaceTab) {
        let dbType = tab.connection.databaseType
        guard dbType == .microsoftSQL || dbType == .mysql else { return }

        guard let targetDatabase = parseUseDatabaseStatement(originalSQL, databaseType: dbType) else { return }

        let previous = tab.activeDatabaseName
        guard targetDatabase != previous else { return }

        tab.activeDatabaseName = targetDatabase

        // Update the query state's clipboard metadata
        if let queryState = tab.query {
            queryState.updateClipboardContext(
                serverName: queryState.clipboardMetadata.serverName,
                databaseName: targetDatabase,
                connectionColorHex: queryState.clipboardMetadata.connectionColorHex
            )
        }

        environmentState.notificationEngine?.post(category: .databaseSwitched, message: "Switched to \(targetDatabase)")
    }

    /// Parses a `USE database` statement from SQL. Returns the database name or nil.
    private func parseUseDatabaseStatement(_ sql: String, databaseType: DatabaseType) -> String? {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)

        // Match USE [database], USE `database`, USE "database", or USE database
        // Handle MSSQL bracket syntax and MySQL backtick syntax
        let pattern: String
        switch databaseType {
        case .microsoftSQL:
            // USE [AdventureWorks] or USE AdventureWorks
            pattern = #"(?i)^\s*USE\s+(?:\[([^\]]+)\]|"([^"]+)"|(\S+?))\s*;?\s*$"#
        case .mysql:
            // USE `database` or USE database
            pattern = #"(?i)^\s*USE\s+(?:`([^`]+)`|"([^"]+)"|(\S+?))\s*;?\s*$"#
        default:
            return nil
        }

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: (trimmed as NSString).length)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: range) else { return nil }

        // Check capture groups -- first non-nil wins
        for groupIndex in 1..<match.numberOfRanges {
            let groupRange = match.range(at: groupIndex)
            if groupRange.location != NSNotFound, let swiftRange = Range(groupRange, in: trimmed) {
                let name = String(trimmed[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { return name }
            }
        }
        return nil
    }
}
