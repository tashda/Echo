import Foundation

extension ViewEditorViewModel {

    // MARK: - SQL Generation

    func generateSQL() -> String {
        let qualifiedName = "\(quoteIdentifier(schemaName)).\(quoteIdentifier(viewName))"
        var sql = ""

        if isMaterialized {
            if isEditing {
                sql += "DROP MATERIALIZED VIEW IF EXISTS \(qualifiedName);\n\n"
                sql += "CREATE MATERIALIZED VIEW \(qualifiedName) AS\n\(definition);"
            } else {
                sql += "CREATE MATERIALIZED VIEW \(qualifiedName) AS\n\(definition);"
            }
        } else {
            sql += "CREATE OR REPLACE VIEW \(qualifiedName) AS\n\(definition);"
        }

        if !owner.isEmpty && isEditing {
            let keyword = isMaterialized ? "MATERIALIZED VIEW" : "VIEW"
            sql += "\n\nALTER \(keyword) \(qualifiedName) OWNER TO \(quoteIdentifier(owner));"
        }

        if !description.isEmpty {
            let keyword = isMaterialized ? "MATERIALIZED VIEW" : "VIEW"
            let escapedComment = description.replacingOccurrences(of: "'", with: "''")
            sql += "\n\nCOMMENT ON \(keyword) \(qualifiedName) IS '\(escapedComment)';"
        }

        return sql
    }

    // MARK: - Apply

    func apply(session: ConnectionSession) async {
        isSubmitting = true
        errorMessage = nil
        let objectType = isMaterialized ? "materialized view" : "view"
        let handle = activityEngine?.begin(
            isEditing ? "Alter \(objectType) \(viewName)" : "Create \(objectType) \(viewName)",
            connectionSessionID: connectionSessionID
        )

        do {
            let sql = generateSQL()
            _ = try await session.session.simpleQuery(sql)
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
}
