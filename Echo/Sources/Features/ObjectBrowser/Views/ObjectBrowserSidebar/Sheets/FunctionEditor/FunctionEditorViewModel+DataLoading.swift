import Foundation
import PostgresKit

extension FunctionEditorViewModel {

    // MARK: - Load Existing Function

    func load(session: ConnectionSession) async {
        guard isEditing else {
            takeSnapshot()
            return
        }

        isLoading = true
        defer { isLoading = false }

        guard let pg = session.session as? PostgresSession else {
            errorMessage = "Function editing requires a PostgreSQL connection."
            takeSnapshot()
            return
        }

        do {
            try await loadFunctionMetadata(pg: pg)
            try await loadFunctionComment(pg: pg)
            takeSnapshot()
        } catch {
            errorMessage = "Failed to load function: \(error.localizedDescription)"
            takeSnapshot()
        }
    }

    // MARK: - Metadata

    private func loadFunctionMetadata(pg: PostgresSession) async throws {
        let sql = """
            SELECT
                p.proname,
                pg_catalog.pg_get_function_result(p.oid) AS return_type,
                l.lanname AS language,
                p.prosrc AS source,
                p.provolatile,
                p.proparallel,
                p.prosecdef,
                p.proisstrict,
                p.procost::text,
                p.prorows::text,
                pg_catalog.pg_get_function_arguments(p.oid) AS arguments
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            JOIN pg_language l ON l.oid = p.prolang
            WHERE n.nspname = '\(escapeSQLIdentifier(schemaName))'
              AND p.proname = '\(escapeSQLIdentifier(functionName))'
            ORDER BY p.oid LIMIT 1
            """

        let result = try await pg.simpleQuery(sql)
        guard let row = result.rows.first, row.count >= 11 else { return }

        let retType = row[1] ?? "void"
        let lang = row[2] ?? "plpgsql"
        let source = row[3] ?? ""
        let vol = row[4] ?? "v"
        let par = row[5] ?? "u"
        let secDef = row[6] ?? "false"
        let strict = row[7] ?? "false"
        let costVal = row[8] ?? "100"
        let rowsVal = row[9] ?? "1000"
        let arguments = row[10] ?? ""

        returnType = retType
        language = lang
        body = source
        cost = costVal
        estimatedRows = rowsVal
        isStrict = strict == "true" || strict == "t"

        volatility = switch vol {
        case "s": .stable
        case "i": .immutable
        default: .volatile
        }

        parallelSafety = switch par {
        case "r": .restricted
        case "s": .safe
        default: .unsafe
        }

        securityType = (secDef == "true" || secDef == "t") ? .definer : .invoker

        parameters = parseArguments(arguments)
    }

    private func loadFunctionComment(pg: PostgresSession) async throws {
        if let comment = try await pg.client.introspection.fetchFunctionComment(
            schema: schemaName,
            name: functionName
        ) {
            description = comment
        }
    }

    // MARK: - Argument Parsing

    private func parseArguments(_ argumentString: String) -> [FunctionParameterDraft] {
        let trimmed = argumentString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var drafts: [FunctionParameterDraft] = []
        let parts = splitArguments(trimmed)

        for part in parts {
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

            drafts.append(FunctionParameterDraft(
                name: name,
                dataType: dataType,
                mode: mode,
                defaultValue: defaultValue
            ))
        }

        return drafts
    }

    /// Splits a PostgreSQL argument string by commas, respecting parentheses depth.
    private func splitArguments(_ input: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0

        for char in input {
            if char == "(" { depth += 1 }
            else if char == ")" { depth -= 1 }

            if char == "," && depth == 0 {
                parts.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }

    // MARK: - SQL Escaping

    private func escapeSQLIdentifier(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }
}
