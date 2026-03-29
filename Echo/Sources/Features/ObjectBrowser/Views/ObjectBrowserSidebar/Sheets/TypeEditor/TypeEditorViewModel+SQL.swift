import Foundation

extension TypeEditorViewModel {

    // MARK: - SQL Generation

    func generateSQL() -> String {
        switch typeCategory {
        case .composite: return generateCompositeSQL()
        case .enum: return generateEnumSQL()
        case .range: return generateRangeSQL()
        case .domain: return generateDomainSQL()
        }
    }

    // MARK: - Composite

    private func generateCompositeSQL() -> String {
        let qualified = qualifiedName()
        let validAttrs = attributes.filter {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !$0.dataType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if isEditing {
            // ALTER TYPE for composites: add/drop attributes
            var sql = "-- Alter composite type \(qualified)\n"
            sql += "-- Note: PostgreSQL requires individual ALTER TYPE statements for each change.\n"
            sql += "-- New attributes are added; removed attributes must be dropped separately.\n\n"

            for attr in validAttrs {
                sql += "ALTER TYPE \(qualified) ADD ATTRIBUTE \(quote(attr.name)) \(attr.dataType);\n"
            }

            sql += appendOwnerAndComment(qualified: qualified, keyword: "TYPE")
            return sql
        } else {
            let attrList = validAttrs.map { "    \(quote($0.name)) \($0.dataType)" }.joined(separator: ",\n")
            var sql = "CREATE TYPE \(qualified) AS (\n\(attrList)\n);"
            sql += appendOwnerAndComment(qualified: qualified, keyword: "TYPE")
            return sql
        }
    }

    // MARK: - Enum

    private func generateEnumSQL() -> String {
        let qualified = qualifiedName()
        let validValues = enumValues.filter {
            !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if isEditing {
            var sql = "-- Add new values to enum \(qualified)\n"
            for val in validValues {
                let escaped = val.value.replacingOccurrences(of: "'", with: "''")
                sql += "ALTER TYPE \(qualified) ADD VALUE IF NOT EXISTS '\(escaped)';\n"
            }
            sql += appendOwnerAndComment(qualified: qualified, keyword: "TYPE")
            return sql
        } else {
            let valueList = validValues.map { "'\($0.value.replacingOccurrences(of: "'", with: "''"))'" }
            var sql = "CREATE TYPE \(qualified) AS ENUM (\n    \(valueList.joined(separator: ",\n    "))\n);"
            sql += appendOwnerAndComment(qualified: qualified, keyword: "TYPE")
            return sql
        }
    }

    // MARK: - Range

    private func generateRangeSQL() -> String {
        let qualified = qualifiedName()

        if isEditing {
            var sql = "-- Range types cannot be altered after creation.\n"
            sql += "-- To change the subtype, drop and recreate the type.\n"
            sql += appendOwnerAndComment(qualified: qualified, keyword: "TYPE")
            return sql
        } else {
            var parts: [String] = ["    subtype = \(subtype)"]
            let opClass = subtypeOpClass.trimmingCharacters(in: .whitespacesAndNewlines)
            if !opClass.isEmpty { parts.append("    subtype_opclass = \(opClass)") }
            let coll = collation.trimmingCharacters(in: .whitespacesAndNewlines)
            if !coll.isEmpty { parts.append("    collation = \(coll)") }

            var sql = "CREATE TYPE \(qualified) AS RANGE (\n\(parts.joined(separator: ",\n"))\n);"
            sql += appendOwnerAndComment(qualified: qualified, keyword: "TYPE")
            return sql
        }
    }

    // MARK: - Domain

    private func generateDomainSQL() -> String {
        let qualified = qualifiedName()

        if isEditing {
            var sql = "-- Alter domain \(qualified)\n"
            if !defaultValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sql += "ALTER DOMAIN \(qualified) SET DEFAULT \(defaultValue);\n"
            } else {
                sql += "ALTER DOMAIN \(qualified) DROP DEFAULT;\n"
            }
            if isNotNull {
                sql += "ALTER DOMAIN \(qualified) SET NOT NULL;\n"
            } else {
                sql += "ALTER DOMAIN \(qualified) DROP NOT NULL;\n"
            }
            for constraint in domainConstraints {
                let name = constraint.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let expr = constraint.expression.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty && !expr.isEmpty {
                    sql += "ALTER DOMAIN \(qualified) ADD CONSTRAINT \(quote(name)) CHECK (\(expr));\n"
                }
            }
            sql += appendOwnerAndComment(qualified: qualified, keyword: "DOMAIN")
            return sql
        } else {
            var sql = "CREATE DOMAIN \(qualified) AS \(baseDataType)"
            if !defaultValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sql += "\n    DEFAULT \(defaultValue)"
            }
            if isNotNull { sql += "\n    NOT NULL" }
            for constraint in domainConstraints {
                let name = constraint.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let expr = constraint.expression.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty && !expr.isEmpty {
                    sql += "\n    CONSTRAINT \(quote(name)) CHECK (\(expr))"
                }
            }
            sql += ";"
            sql += appendOwnerAndComment(qualified: qualified, keyword: "DOMAIN")
            return sql
        }
    }

    // MARK: - Apply

    func apply(session: ConnectionSession) async {
        isSubmitting = true
        errorMessage = nil
        let handle = activityEngine?.begin(
            isEditing ? "Alter \(typeCategory.title.lowercased()) \(typeName)" : "Create \(typeCategory.title.lowercased()) \(typeName)",
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

    // MARK: - Helpers

    private func qualifiedName() -> String {
        "\(quote(schemaName)).\(quote(typeName))"
    }

    private func quote(_ identifier: String) -> String {
        let escaped = identifier.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func appendOwnerAndComment(qualified: String, keyword: String) -> String {
        var sql = ""
        if !owner.isEmpty && isEditing {
            sql += "\n\nALTER \(keyword) \(qualified) OWNER TO \(quote(owner));"
        }
        if !description.isEmpty {
            let escapedComment = description.replacingOccurrences(of: "'", with: "''")
            sql += "\n\nCOMMENT ON \(keyword) \(qualified) IS '\(escapedComment)';"
        }
        return sql
    }
}
