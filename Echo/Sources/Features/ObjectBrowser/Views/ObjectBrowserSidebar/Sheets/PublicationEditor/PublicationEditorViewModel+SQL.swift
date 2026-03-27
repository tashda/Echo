import Foundation
import PostgresKit

extension PublicationEditorViewModel {

    // MARK: - SQL Generation

    func generateSQL() -> String {
        let quotedName = quoteIdentifier(publicationName)

        if isEditing {
            return generateAlterSQL(quotedName: quotedName)
        }

        return generateCreateSQL(quotedName: quotedName)
    }

    private func generateCreateSQL(quotedName: String) -> String {
        var parts: [String] = ["CREATE PUBLICATION \(quotedName)"]

        if allTables {
            parts.append("FOR ALL TABLES")
        } else if !selectedTables.isEmpty {
            let tableList = selectedTables.sorted().map { quoteQualifiedName($0) }.joined(separator: ", ")
            parts.append("FOR TABLE \(tableList)")
        }

        let publishClause = buildPublishClause()
        if !publishClause.isEmpty {
            parts.append("WITH (publish = '\(publishClause)')")
        }

        return parts.joined(separator: "\n") + ";"
    }

    private func generateAlterSQL(quotedName: String) -> String {
        var statements: [String] = []

        // Recreate via DROP + CREATE for simplicity
        statements.append("DROP PUBLICATION IF EXISTS \(quotedName);")
        statements.append(generateCreateSQL(quotedName: quotedName))

        return statements.joined(separator: "\n\n")
    }

    private func buildPublishClause() -> String {
        var ops: [String] = []
        if publishInsert { ops.append("insert") }
        if publishUpdate { ops.append("update") }
        if publishDelete { ops.append("delete") }
        if publishTruncate { ops.append("truncate") }
        return ops.joined(separator: ", ")
    }

    // MARK: - Apply

    func apply(session: ConnectionSession) async {
        guard let pg = session.session as? PostgresSession else {
            errorMessage = "Publication editing requires a PostgreSQL connection."
            return
        }

        isSubmitting = true
        errorMessage = nil
        let handle = activityEngine?.begin(
            isEditing ? "Alter publication \(publicationName)" : "Create publication \(publicationName)",
            connectionSessionID: connectionSessionID
        )

        do {
            if isEditing {
                try await pg.client.admin.dropPublication(name: publicationName, ifExists: true)
            }

            var operations: [String] = []
            if publishInsert { operations.append("insert") }
            if publishUpdate { operations.append("update") }
            if publishDelete { operations.append("delete") }
            if publishTruncate { operations.append("truncate") }

            try await pg.client.admin.createPublication(
                name: publicationName,
                forAllTables: allTables,
                tables: allTables ? nil : Array(selectedTables.sorted()),
                operations: operations
            )

            handle?.succeed()
            takeSnapshot()
        } catch {
            let message = "Failed to apply: \(error.localizedDescription)"
            errorMessage = message
            handle?.fail(message)
        }

        isSubmitting = false
    }

    func saveAndClose(session: ConnectionSession) async {
        await apply(session: session)
        if errorMessage == nil {
            didComplete = true
        }
    }

    // MARK: - Identifier Quoting

    private func quoteIdentifier(_ identifier: String) -> String {
        let escaped = identifier.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func quoteQualifiedName(_ qualifiedName: String) -> String {
        let parts = qualifiedName.split(separator: ".", maxSplits: 1)
        if parts.count == 2 {
            return "\(quoteIdentifier(String(parts[0]))).\(quoteIdentifier(String(parts[1])))"
        }
        return quoteIdentifier(qualifiedName)
    }
}
