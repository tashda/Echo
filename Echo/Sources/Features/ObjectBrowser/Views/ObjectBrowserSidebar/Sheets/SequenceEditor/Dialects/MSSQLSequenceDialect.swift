import Foundation
import SQLServerKit

struct MSSQLSequenceDialect: SequenceEditorDialect, Sendable {

    var supportsOwnership: Bool { false }
    var supportsOwnedBy: Bool { false }
    var supportsCache: Bool { true }
    var supportsComments: Bool { true }

    func loadMetadata(session: any DatabaseSession, schema: String, name: String) async throws -> SequenceEditorMetadata {
        guard let mssql = session as? SQLServerSessionAdapter else {
            throw ViewEditorDialectError.unsupportedSession
        }

        var metadata = SequenceEditorMetadata(
            name: name, startWith: "1", incrementBy: "1", minValue: "", maxValue: "",
            cache: "0", cycle: false, owner: "", ownedBy: "", lastValue: "", description: ""
        )

        if let details = try await mssql.client.metadata.sequenceDetails(schema: schema, name: name) {
            metadata.startWith = details.startValue
            metadata.incrementBy = details.incrementBy
            metadata.minValue = details.minValue
            metadata.maxValue = details.maxValue
            metadata.cycle = details.isCycling
            metadata.cache = String(details.cacheSize)
            metadata.lastValue = details.currentValue ?? "\u{2014}"
            metadata.description = details.comment ?? ""
        }

        return metadata
    }

    func generateSQL(context: SequenceEditorSQLContext) -> String {
        let qualified = "\(quoteIdentifier(context.schema)).\(quoteIdentifier(context.name))"

        if context.isEditing {
            return generateAlterSQL(qualified: qualified, context: context)
        } else {
            return generateCreateSQL(qualified: qualified, context: context)
        }
    }

    func quoteIdentifier(_ identifier: String) -> String {
        let escaped = identifier.replacingOccurrences(of: "]", with: "]]")
        return "[\(escaped)]"
    }

    private func generateCreateSQL(qualified: String, context: SequenceEditorSQLContext) -> String {
        var parts: [String] = ["CREATE SEQUENCE \(qualified)"]
        parts.append("    AS BIGINT")
        if let start = Int(context.startWith) { parts.append("    START WITH \(start)") }
        if let inc = Int(context.incrementBy), inc != 1 { parts.append("    INCREMENT BY \(inc)") }
        if let min = Int(context.minValue) { parts.append("    MINVALUE \(min)") }
        if let max = Int(context.maxValue) { parts.append("    MAXVALUE \(max)") }
        if let c = Int(context.cache), c > 0 { parts.append("    CACHE \(c)") } else { parts.append("    NO CACHE") }
        if context.cycle { parts.append("    CYCLE") } else { parts.append("    NO CYCLE") }
        var sql = parts.joined(separator: "\n") + ";"

        if !context.description.isEmpty {
            let escaped = context.description.replacingOccurrences(of: "'", with: "''")
            sql += "\n\nGO\n\nEXEC sp_addextendedproperty\n    @name = N'MS_Description',\n    @value = N'\(escaped)',\n    @level0type = N'SCHEMA', @level0name = N'\(esc(context.schema))',\n    @level1type = N'SEQUENCE', @level1name = N'\(esc(context.name))';"
        }

        return sql
    }

    private func generateAlterSQL(qualified: String, context: SequenceEditorSQLContext) -> String {
        var alterParts: [String] = []
        if let inc = Int(context.incrementBy) { alterParts.append("INCREMENT BY \(inc)") }
        if let min = Int(context.minValue) { alterParts.append("MINVALUE \(min)") } else { alterParts.append("NO MINVALUE") }
        if let max = Int(context.maxValue) { alterParts.append("MAXVALUE \(max)") } else { alterParts.append("NO MAXVALUE") }
        if let start = Int(context.startWith) { alterParts.append("RESTART WITH \(start)") }
        if let c = Int(context.cache), c > 0 { alterParts.append("CACHE \(c)") } else { alterParts.append("NO CACHE") }
        alterParts.append(context.cycle ? "CYCLE" : "NO CYCLE")

        var sql = "ALTER SEQUENCE \(qualified)\n    " + alterParts.joined(separator: "\n    ") + ";"

        if !context.description.isEmpty {
            let escaped = context.description.replacingOccurrences(of: "'", with: "''")
            sql += "\n\nGO\n\nEXEC sp_addextendedproperty\n    @name = N'MS_Description',\n    @value = N'\(escaped)',\n    @level0type = N'SCHEMA', @level0name = N'\(esc(context.schema))',\n    @level1type = N'SEQUENCE', @level1name = N'\(esc(context.name))';"
        }

        return sql
    }

    private func esc(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }
}
