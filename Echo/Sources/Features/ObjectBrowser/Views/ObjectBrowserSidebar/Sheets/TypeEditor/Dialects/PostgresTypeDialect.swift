import Foundation
import PostgresKit

/// PostgreSQL implementation of the type editor dialect.
/// Uses postgres-wire typed metadata APIs — no raw SQL in Echo.
struct PostgresTypeDialect: TypeEditorDialect, Sendable {

    var supportsComposite: Bool { true }
    var supportsEnum: Bool { true }
    var supportsRange: Bool { true }
    var supportsDomain: Bool { true }
    var supportsOwnership: Bool { true }
    var supportsComments: Bool { true }

    func loadMetadata(session: any DatabaseSession, schema: String, name: String, category: TypeCategory) async throws -> TypeEditorMetadata {
        guard let pg = session as? PostgresSession else {
            throw ViewEditorDialectError.unsupportedSession
        }

        var metadata = TypeEditorMetadata(
            name: name, owner: "", description: "",
            attributes: [TypeAttributeDraft()], enumValues: [EnumValueDraft()],
            subtype: "", subtypeOpClass: "", collation: "",
            baseDataType: "", defaultValue: "", isNotNull: false, domainConstraints: []
        )

        switch category {
        case .composite:
            let composites = try await pg.client.metadata.listCompositeTypes(schema: schema)
            if let composite = composites.first(where: { $0.name == name }) {
                metadata.attributes = composite.attributes.map { TypeAttributeDraft(name: $0.name, dataType: $0.dataType) }
                if metadata.attributes.isEmpty { metadata.attributes = [TypeAttributeDraft()] }
            }
        case .enum:
            let values = try await pg.client.metadata.enumValues(schema: schema, name: name)
            metadata.enumValues = values.map { EnumValueDraft(value: $0) }
            if metadata.enumValues.isEmpty { metadata.enumValues = [EnumValueDraft()] }
        case .range:
            let ranges = try await pg.client.metadata.listRangeTypes(schema: schema)
            if let range = ranges.first(where: { $0.name == name }) {
                metadata.subtype = range.subtype
                metadata.subtypeOpClass = range.subtypeOpClass ?? ""
                metadata.collation = range.collation ?? ""
            }
        case .domain:
            let domains = try await pg.client.metadata.listDomains(schema: schema)
            if let domain = domains.first(where: { $0.name == name }) {
                metadata.baseDataType = domain.dataType
                metadata.defaultValue = domain.defaultValue ?? ""
                metadata.isNotNull = domain.isNotNull
                metadata.domainConstraints = domain.constraints.map {
                    DomainConstraintDraft(name: $0.name, expression: $0.expression)
                }
            }
        }

        metadata.owner = try await pg.client.metadata.typeOwner(schema: schema, name: name) ?? ""
        metadata.description = try await pg.client.metadata.fetchTypeComment(schema: schema, name: name) ?? ""

        return metadata
    }

    func generateSQL(context: TypeEditorSQLContext) -> String {
        switch context.category {
        case .composite: return generateCompositeSQL(context: context)
        case .enum: return generateEnumSQL(context: context)
        case .range: return generateRangeSQL(context: context)
        case .domain: return generateDomainSQL(context: context)
        }
    }

    func quoteIdentifier(_ identifier: String) -> String {
        let escaped = identifier.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    // MARK: - SQL Generation

    private func generateCompositeSQL(context: TypeEditorSQLContext) -> String {
        let qualified = qualifiedName(context)
        let validAttrs = context.attributes.filter {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !$0.dataType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if context.isEditing {
            var sql = "-- Alter composite type \(qualified)\n-- Note: PostgreSQL requires individual ALTER TYPE statements for each change.\n\n"
            for attr in validAttrs { sql += "ALTER TYPE \(qualified) ADD ATTRIBUTE \(quoteIdentifier(attr.name)) \(attr.dataType);\n" }
            sql += ownerAndComment(qualified: qualified, keyword: "TYPE", context: context)
            return sql
        } else {
            let attrList = validAttrs.map { "    \(quoteIdentifier($0.name)) \($0.dataType)" }.joined(separator: ",\n")
            var sql = "CREATE TYPE \(qualified) AS (\n\(attrList)\n);"
            sql += ownerAndComment(qualified: qualified, keyword: "TYPE", context: context)
            return sql
        }
    }

    private func generateEnumSQL(context: TypeEditorSQLContext) -> String {
        let qualified = qualifiedName(context)
        let validValues = context.enumValues.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        if context.isEditing {
            var sql = "-- Add new values to enum \(qualified)\n"
            for val in validValues {
                let escaped = val.value.replacingOccurrences(of: "'", with: "''")
                sql += "ALTER TYPE \(qualified) ADD VALUE IF NOT EXISTS '\(escaped)';\n"
            }
            sql += ownerAndComment(qualified: qualified, keyword: "TYPE", context: context)
            return sql
        } else {
            let valueList = validValues.map { "'\($0.value.replacingOccurrences(of: "'", with: "''"))'" }
            var sql = "CREATE TYPE \(qualified) AS ENUM (\n    \(valueList.joined(separator: ",\n    "))\n);"
            sql += ownerAndComment(qualified: qualified, keyword: "TYPE", context: context)
            return sql
        }
    }

    private func generateRangeSQL(context: TypeEditorSQLContext) -> String {
        let qualified = qualifiedName(context)
        if context.isEditing {
            var sql = "-- Range types cannot be altered after creation.\n-- To change the subtype, drop and recreate the type.\n"
            sql += ownerAndComment(qualified: qualified, keyword: "TYPE", context: context)
            return sql
        } else {
            var parts: [String] = ["    subtype = \(context.subtype)"]
            let opClass = context.subtypeOpClass.trimmingCharacters(in: .whitespacesAndNewlines)
            if !opClass.isEmpty { parts.append("    subtype_opclass = \(opClass)") }
            let coll = context.collation.trimmingCharacters(in: .whitespacesAndNewlines)
            if !coll.isEmpty { parts.append("    collation = \(coll)") }
            var sql = "CREATE TYPE \(qualified) AS RANGE (\n\(parts.joined(separator: ",\n"))\n);"
            sql += ownerAndComment(qualified: qualified, keyword: "TYPE", context: context)
            return sql
        }
    }

    private func generateDomainSQL(context: TypeEditorSQLContext) -> String {
        let qualified = qualifiedName(context)
        if context.isEditing {
            var sql = "-- Alter domain \(qualified)\n"
            if !context.defaultValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sql += "ALTER DOMAIN \(qualified) SET DEFAULT \(context.defaultValue);\n"
            } else {
                sql += "ALTER DOMAIN \(qualified) DROP DEFAULT;\n"
            }
            sql += context.isNotNull ? "ALTER DOMAIN \(qualified) SET NOT NULL;\n" : "ALTER DOMAIN \(qualified) DROP NOT NULL;\n"
            for constraint in context.domainConstraints {
                let name = constraint.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let expr = constraint.expression.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty && !expr.isEmpty {
                    sql += "ALTER DOMAIN \(qualified) ADD CONSTRAINT \(quoteIdentifier(name)) CHECK (\(expr));\n"
                }
            }
            sql += ownerAndComment(qualified: qualified, keyword: "DOMAIN", context: context)
            return sql
        } else {
            var sql = "CREATE DOMAIN \(qualified) AS \(context.baseDataType)"
            if !context.defaultValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { sql += "\n    DEFAULT \(context.defaultValue)" }
            if context.isNotNull { sql += "\n    NOT NULL" }
            for constraint in context.domainConstraints {
                let name = constraint.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let expr = constraint.expression.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty && !expr.isEmpty { sql += "\n    CONSTRAINT \(quoteIdentifier(name)) CHECK (\(expr))" }
            }
            sql += ";"
            sql += ownerAndComment(qualified: qualified, keyword: "DOMAIN", context: context)
            return sql
        }
    }

    private func qualifiedName(_ context: TypeEditorSQLContext) -> String {
        "\(quoteIdentifier(context.schema)).\(quoteIdentifier(context.name))"
    }

    private func ownerAndComment(qualified: String, keyword: String, context: TypeEditorSQLContext) -> String {
        var sql = ""
        if !context.owner.isEmpty && context.isEditing {
            sql += "\n\nALTER \(keyword) \(qualified) OWNER TO \(quoteIdentifier(context.owner));"
        }
        if !context.description.isEmpty {
            let escaped = context.description.replacingOccurrences(of: "'", with: "''")
            sql += "\n\nCOMMENT ON \(keyword) \(qualified) IS '\(escaped)';"
        }
        return sql
    }
}
