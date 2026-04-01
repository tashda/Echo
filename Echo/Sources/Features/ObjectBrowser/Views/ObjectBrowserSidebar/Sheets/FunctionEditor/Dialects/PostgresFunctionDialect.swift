import Foundation
import PostgresKit

/// PostgreSQL implementation of the function editor dialect.
/// Uses postgres-wire typed metadata APIs — no raw SQL in Echo.
struct PostgresFunctionDialect: FunctionEditorDialect, Sendable {

    var supportsLanguage: Bool { true }
    var supportsVolatility: Bool { true }
    var supportsParallelSafety: Bool { true }
    var supportsSecurityType: Bool { true }
    var supportsStrict: Bool { true }
    var supportsCost: Bool { true }
    var supportsEstimatedRows: Bool { true }
    var supportsComments: Bool { true }
    var supportsCreateOrReplace: Bool { true }
    var defaultLanguage: String { "plpgsql" }

    func loadMetadata(session: any DatabaseSession, schema: String, name: String) async throws -> FunctionEditorMetadata {
        guard let pg = session as? PostgresSession else {
            throw ViewEditorDialectError.unsupportedSession
        }

        var metadata = FunctionEditorMetadata(
            name: name, language: "plpgsql", returnType: "void", body: "",
            volatility: .volatile, parallelSafety: .unsafe, securityType: .invoker,
            isStrict: false, cost: "100", estimatedRows: "1000", description: "",
            parameters: []
        )

        guard let details = try await pg.client.metadata.functionDetails(schema: schema, name: name) else {
            return metadata
        }

        metadata.returnType = details.returnType
        metadata.language = details.language
        metadata.body = details.source
        metadata.cost = details.cost
        metadata.estimatedRows = details.estimatedRows
        metadata.isStrict = details.isStrict
        metadata.description = details.comment ?? ""

        metadata.volatility = switch details.volatility {
        case "s": .stable
        case "i": .immutable
        default: .volatile
        }

        metadata.parallelSafety = switch details.parallelSafety {
        case "r": .restricted
        case "s": .safe
        default: .unsafe
        }

        metadata.securityType = details.isSecurityDefiner ? .definer : .invoker
        metadata.parameters = parseArguments(details.arguments)

        return metadata
    }

    func generateSQL(context: FunctionEditorSQLContext) -> String {
        let qualifiedName = "\(quoteIdentifier(context.schema)).\(quoteIdentifier(context.name))"
        var sql = "CREATE OR REPLACE FUNCTION \(qualifiedName)"

        let paramList = context.parameters.map { param in
            var parts: [String] = []
            if param.mode != .in { parts.append(param.mode.rawValue) }
            if !param.name.isEmpty { parts.append(quoteIdentifier(param.name)) }
            parts.append(param.dataType)
            if !param.defaultValue.isEmpty { parts.append("DEFAULT \(param.defaultValue)") }
            return parts.joined(separator: " ")
        }
        sql += "(\(paramList.joined(separator: ", ")))\n"
        sql += "RETURNS \(context.returnType)\n"
        sql += "LANGUAGE \(context.language)\n"
        sql += "\(context.volatility.rawValue)\n"
        if context.parallelSafety != .unsafe { sql += "PARALLEL \(context.parallelSafety.rawValue)\n" }
        if context.securityType == .definer { sql += "SECURITY DEFINER\n" }
        if context.isStrict { sql += "STRICT\n" }
        if let costNum = Int(context.cost), costNum != 100 { sql += "COST \(costNum)\n" }
        let lowerReturn = context.returnType.lowercased()
        if lowerReturn.hasPrefix("setof") || lowerReturn.contains("table") {
            if let rowsNum = Int(context.estimatedRows), rowsNum != 1000 { sql += "ROWS \(rowsNum)\n" }
        }
        sql += "AS $$\n\(context.body)\n$$;"

        if !context.description.isEmpty {
            let escaped = context.description.replacingOccurrences(of: "'", with: "''")
            sql += "\n\nCOMMENT ON FUNCTION \(qualifiedName) IS '\(escaped)';"
        }

        return sql
    }

    func quoteIdentifier(_ identifier: String) -> String {
        let needsQuoting = identifier.contains(" ") || identifier.contains("-")
            || (identifier.uppercased() != identifier && identifier.lowercased() != identifier)
            || pgReservedWords.contains(identifier.lowercased())
        if needsQuoting {
            let escaped = identifier.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return identifier
    }

    // MARK: - Argument Parsing

    private func parseArguments(_ argumentString: String) -> [FunctionParameterDraft] {
        let trimmed = argumentString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var drafts: [FunctionParameterDraft] = []
        for part in splitArguments(trimmed) {
            let tokens = part.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            guard !tokens.isEmpty else { continue }

            var mode: ParameterMode = .in
            var nameIndex = 0

            if let first = tokens.first?.uppercased() {
                switch first {
                case "IN": mode = .in; nameIndex = 1
                case "OUT": mode = .out; nameIndex = 1
                case "INOUT": mode = .inout; nameIndex = 1
                case "VARIADIC": mode = .variadic; nameIndex = 1
                default: break
                }
            }

            let remaining = Array(tokens[nameIndex...])
            let name: String
            let dataType: String
            var defaultValue = ""

            if remaining.count >= 2 {
                if let defaultIdx = remaining.firstIndex(where: { $0.uppercased() == "DEFAULT" || $0 == "=" }) {
                    name = remaining[0]
                    dataType = remaining[1..<defaultIdx].joined(separator: " ")
                    let afterDefault = remaining.index(after: defaultIdx)
                    if afterDefault < remaining.endIndex {
                        defaultValue = remaining[afterDefault...].joined(separator: " ")
                    }
                } else {
                    name = remaining[0]
                    dataType = remaining[1...].joined(separator: " ")
                }
            } else if remaining.count == 1 {
                name = ""
                dataType = remaining[0]
            } else {
                continue
            }

            drafts.append(FunctionParameterDraft(name: name, dataType: dataType, mode: mode, defaultValue: defaultValue))
        }

        return drafts
    }

    private func splitArguments(_ input: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0
        for char in input {
            if char == "(" { depth += 1 } else if char == ")" { depth -= 1 }
            if char == "," && depth == 0 { parts.append(current); current = "" } else { current.append(char) }
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }

    private let pgReservedWords: Set<String> = [
        "select", "from", "where", "insert", "update", "delete", "create",
        "drop", "alter", "table", "index", "view", "function", "trigger",
        "grant", "revoke", "user", "role", "schema", "database", "order",
        "group", "by", "having", "limit", "offset", "join", "on", "as",
        "and", "or", "not", "in", "is", "null", "true", "false", "default"
    ]
}
