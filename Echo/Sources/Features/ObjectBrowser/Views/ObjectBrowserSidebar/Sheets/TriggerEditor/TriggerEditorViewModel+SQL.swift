import Foundation

extension TriggerEditorViewModel {

    // MARK: - SQL Generation

    func generateSQL() -> String {
        let qualifiedTable = "\(quoteIdentifier(schemaName)).\(quoteIdentifier(tableName))"
        let qualifiedFunc = functionName.contains("(") ? functionName : "\(functionName)()"

        var events: [String] = []
        if onInsert { events.append("INSERT") }
        if onUpdate { events.append("UPDATE") }
        if onDelete { events.append("DELETE") }
        if onTruncate { events.append("TRUNCATE") }

        var sql = ""

        if isEditing {
            // Drop and recreate — PostgreSQL doesn't support ALTER TRIGGER for definition changes
            sql += "DROP TRIGGER IF EXISTS \(quoteIdentifier(triggerName)) ON \(qualifiedTable);\n\n"
        }

        sql += "CREATE TRIGGER \(quoteIdentifier(triggerName))"
        sql += "\n    \(timing.rawValue) \(events.joined(separator: " OR "))"
        sql += "\n    ON \(qualifiedTable)"
        sql += "\n    FOR EACH \(forEach.rawValue)"

        let whenTrimmed = whenCondition.trimmingCharacters(in: .whitespacesAndNewlines)
        if !whenTrimmed.isEmpty {
            sql += "\n    WHEN (\(whenTrimmed))"
        }

        sql += "\n    EXECUTE FUNCTION \(qualifiedFunc);"

        if !isEnabled && isEditing {
            sql += "\n\nALTER TABLE \(qualifiedTable) DISABLE TRIGGER \(quoteIdentifier(triggerName));"
        }

        if !description.isEmpty {
            let escapedComment = description.replacingOccurrences(of: "'", with: "''")
            sql += "\n\nCOMMENT ON TRIGGER \(quoteIdentifier(triggerName)) ON \(qualifiedTable) IS '\(escapedComment)';"
        }

        return sql
    }

    // MARK: - Apply

    func apply(session: ConnectionSession) async {
        isSubmitting = true
        errorMessage = nil
        let handle = activityEngine?.begin(
            isEditing ? "Alter trigger \(triggerName)" : "Create trigger \(triggerName)",
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
