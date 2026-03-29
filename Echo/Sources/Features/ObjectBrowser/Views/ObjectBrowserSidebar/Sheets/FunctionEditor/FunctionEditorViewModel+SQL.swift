import Foundation

extension FunctionEditorViewModel {

    // MARK: - SQL Generation

    func generateSQL() -> String {
        let qualifiedName = "\(quoteIdentifier(schemaName)).\(quoteIdentifier(functionName))"
        var sql = "CREATE OR REPLACE FUNCTION \(qualifiedName)"

        // Parameters
        let paramList = parameters.map { param in
            var parts: [String] = []
            if param.mode != .in {
                parts.append(param.mode.rawValue)
            }
            if !param.name.isEmpty {
                parts.append(quoteIdentifier(param.name))
            }
            parts.append(param.dataType)
            if !param.defaultValue.isEmpty {
                parts.append("DEFAULT \(param.defaultValue)")
            }
            return parts.joined(separator: " ")
        }
        sql += "(\(paramList.joined(separator: ", ")))\n"

        // Return type
        sql += "RETURNS \(returnType)\n"

        // Language
        sql += "LANGUAGE \(language)\n"

        // Volatility
        sql += "\(volatility.rawValue)\n"

        // Parallel safety
        if parallelSafety != .unsafe {
            sql += "PARALLEL \(parallelSafety.rawValue)\n"
        }

        // Security
        if securityType == .definer {
            sql += "SECURITY DEFINER\n"
        }

        // Strict
        if isStrict {
            sql += "STRICT\n"
        }

        // Cost
        if let costNum = Int(cost), costNum != 100 {
            sql += "COST \(costNum)\n"
        }

        // Estimated rows (only for set-returning functions)
        let lowerReturn = returnType.lowercased()
        if lowerReturn.hasPrefix("setof") || lowerReturn.contains("table") {
            if let rowsNum = Int(estimatedRows), rowsNum != 1000 {
                sql += "ROWS \(rowsNum)\n"
            }
        }

        // Body
        sql += "AS $$\n\(body)\n$$;"

        // Comment
        if !description.isEmpty {
            let escapedComment = description.replacingOccurrences(of: "'", with: "''")
            sql += "\n\nCOMMENT ON FUNCTION \(qualifiedName) IS '\(escapedComment)';"
        }

        return sql
    }

    // MARK: - Apply

    func apply(session: ConnectionSession) async {
        isSubmitting = true
        errorMessage = nil
        let handle = activityEngine?.begin(
            isEditing ? "Alter function \(functionName)" : "Create function \(functionName)",
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
        let needsQuoting = identifier.contains(" ")
            || identifier.contains("-")
            || identifier.uppercased() != identifier && identifier.lowercased() != identifier
            || isReservedWord(identifier)

        if needsQuoting {
            let escaped = identifier.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return identifier
    }

    private func isReservedWord(_ word: String) -> Bool {
        let reserved: Set<String> = [
            "select", "from", "where", "insert", "update", "delete", "create",
            "drop", "alter", "table", "index", "view", "function", "trigger",
            "grant", "revoke", "user", "role", "schema", "database", "order",
            "group", "by", "having", "limit", "offset", "join", "on", "as",
            "and", "or", "not", "in", "is", "null", "true", "false", "default"
        ]
        return reserved.contains(word.lowercased())
    }
}
