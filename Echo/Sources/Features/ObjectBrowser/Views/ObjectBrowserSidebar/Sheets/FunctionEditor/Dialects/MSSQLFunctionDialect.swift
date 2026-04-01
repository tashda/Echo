import Foundation
import SQLServerKit

/// MSSQL implementation of the function editor dialect.
/// Uses sqlserver-nio typed metadata APIs — no raw SQL in Echo.
struct MSSQLFunctionDialect: FunctionEditorDialect, Sendable {

    var supportsLanguage: Bool { false }
    var supportsVolatility: Bool { false }
    var supportsParallelSafety: Bool { false }
    var supportsSecurityType: Bool { true }
    var supportsStrict: Bool { false }
    var supportsCost: Bool { false }
    var supportsEstimatedRows: Bool { false }
    var supportsComments: Bool { true }
    var supportsCreateOrReplace: Bool { false }
    var defaultLanguage: String { "T-SQL" }

    func loadMetadata(session: any DatabaseSession, schema: String, name: String) async throws -> FunctionEditorMetadata {
        guard let mssql = session as? SQLServerSessionAdapter else {
            throw ViewEditorDialectError.unsupportedSession
        }

        var metadata = FunctionEditorMetadata(
            name: name, language: "T-SQL", returnType: "INT", body: "",
            volatility: .volatile, parallelSafety: .unsafe, securityType: .invoker,
            isStrict: false, cost: "100", estimatedRows: "1000", description: "",
            parameters: []
        )

        // Load definition via typed API
        let fullDefinition = try await session.getObjectDefinition(
            objectName: name, schemaName: schema, objectType: .function, database: nil
        )
        metadata.body = extractFunctionBody(from: fullDefinition)
        metadata.returnType = extractReturnType(from: fullDefinition)

        // Load parameters via typed API
        let params = try await mssql.client.metadata.listParameters(schema: schema, object: name)
        metadata.parameters = params.compactMap { (param) -> FunctionParameterDraft? in
            let paramName = param.name.hasPrefix("@") ? String(param.name.dropFirst()) : param.name
            guard !paramName.isEmpty else { return nil }
            return FunctionParameterDraft(
                name: paramName,
                dataType: param.typeName,
                mode: param.isOutput ? .out : .in,
                defaultValue: ""
            )
        }

        // Load description via typed API
        metadata.description = try await mssql.client.metadata.objectComment(schema: schema, name: name) ?? ""

        return metadata
    }

    func generateSQL(context: FunctionEditorSQLContext) -> String {
        let qualified = "\(quoteIdentifier(context.schema)).\(quoteIdentifier(context.name))"

        let paramList = context.parameters.map { p in
            let prefix = p.mode == .out ? "OUTPUT" : ""
            let atName = "@\(p.name)"
            return "\(atName) \(p.dataType)\(prefix.isEmpty ? "" : " \(prefix)")"
        }.joined(separator: ",\n    ")

        var sql: String
        if context.isEditing {
            sql = "CREATE OR ALTER FUNCTION \(qualified)(\n    \(paramList)\n)\nRETURNS \(context.returnType)\nAS\nBEGIN\n\(context.body)\nEND;"
        } else {
            sql = "CREATE FUNCTION \(qualified)(\n    \(paramList)\n)\nRETURNS \(context.returnType)\nAS\nBEGIN\n\(context.body)\nEND;"
        }

        if !context.description.isEmpty {
            let escaped = esc(context.description)
            sql += "\n\nGO\n\nEXEC sp_addextendedproperty\n    @name = N'MS_Description',\n    @value = N'\(escaped)',\n    @level0type = N'SCHEMA', @level0name = N'\(esc(context.schema))',\n    @level1type = N'FUNCTION', @level1name = N'\(esc(context.name))';"
        }

        return sql
    }

    func quoteIdentifier(_ identifier: String) -> String {
        let escaped = identifier.replacingOccurrences(of: "]", with: "]]")
        return "[\(escaped)]"
    }

    private func esc(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }

    private func extractFunctionBody(from definition: String) -> String {
        guard let beginRange = definition.range(of: "BEGIN", options: .caseInsensitive),
              let endRange = definition.range(of: "END", options: [.caseInsensitive, .backwards]) else {
            return definition
        }
        return String(definition[beginRange.upperBound..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractReturnType(from definition: String) -> String {
        guard let returnsRange = definition.range(of: "RETURNS", options: .caseInsensitive) else { return "INT" }
        let afterReturns = definition[returnsRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        if let asRange = afterReturns.range(of: "\nAS", options: .caseInsensitive) {
            return String(afterReturns[..<asRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return afterReturns.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "INT"
    }
}
