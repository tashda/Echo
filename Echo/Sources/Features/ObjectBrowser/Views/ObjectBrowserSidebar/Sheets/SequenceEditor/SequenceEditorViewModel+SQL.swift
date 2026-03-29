import Foundation

extension SequenceEditorViewModel {

    // MARK: - SQL Generation

    func generateSQL() -> String {
        let qualifiedName = "\(quoteIdentifier(schemaName)).\(quoteIdentifier(sequenceName))"

        if isEditing {
            return generateAlterSQL(qualifiedName: qualifiedName)
        } else {
            return generateCreateSQL(qualifiedName: qualifiedName)
        }
    }

    private func generateCreateSQL(qualifiedName: String) -> String {
        var parts: [String] = ["CREATE SEQUENCE \(qualifiedName)"]
        if let start = Int(startWith), start != 1 { parts.append("    START WITH \(start)") }
        if let inc = Int(incrementBy), inc != 1 { parts.append("    INCREMENT BY \(inc)") }
        if let min = Int(minValue) { parts.append("    MINVALUE \(min)") }
        if let max = Int(maxValue) { parts.append("    MAXVALUE \(max)") }
        if let c = Int(cache), c != 1 { parts.append("    CACHE \(c)") }
        if cycle { parts.append("    CYCLE") }

        var sql = parts.joined(separator: "\n") + ";"

        if !description.isEmpty {
            let escapedComment = description.replacingOccurrences(of: "'", with: "''")
            sql += "\n\nCOMMENT ON SEQUENCE \(qualifiedName) IS '\(escapedComment)';"
        }

        return sql
    }

    private func generateAlterSQL(qualifiedName: String) -> String {
        var alterParts: [String] = []

        if let inc = Int(incrementBy) { alterParts.append("INCREMENT BY \(inc)") }
        if let min = Int(minValue) {
            alterParts.append("MINVALUE \(min)")
        } else {
            alterParts.append("NO MINVALUE")
        }
        if let max = Int(maxValue) {
            alterParts.append("MAXVALUE \(max)")
        } else {
            alterParts.append("NO MAXVALUE")
        }
        if let start = Int(startWith) { alterParts.append("START WITH \(start)") }
        if let c = Int(cache), c != 1 { alterParts.append("CACHE \(c)") }
        alterParts.append(cycle ? "CYCLE" : "NO CYCLE")

        var sql = "ALTER SEQUENCE \(qualifiedName)\n    " + alterParts.joined(separator: "\n    ") + ";"

        if !owner.isEmpty {
            sql += "\n\nALTER SEQUENCE \(qualifiedName) OWNER TO \(quoteIdentifier(owner));"
        }

        if !description.isEmpty {
            let escapedComment = description.replacingOccurrences(of: "'", with: "''")
            sql += "\n\nCOMMENT ON SEQUENCE \(qualifiedName) IS '\(escapedComment)';"
        }

        return sql
    }

    // MARK: - Apply

    func apply(session: ConnectionSession) async {
        isSubmitting = true
        errorMessage = nil
        let handle = activityEngine?.begin(
            isEditing ? "Alter sequence \(sequenceName)" : "Create sequence \(sequenceName)",
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
