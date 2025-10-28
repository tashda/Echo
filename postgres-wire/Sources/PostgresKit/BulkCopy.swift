import Foundation
import Logging
import PostgresWire

public struct PostgresBulkCopy: @unchecked Sendable {
    public struct Options: Sendable {
        public var chunkSizeBytes: Int = 64 * 1024
        public var insertBatchSize: Int = 500
        public var nullString: String? = nil
        public init(chunkSizeBytes: Int = 64*1024, insertBatchSize: Int = 500, nullString: String? = nil) {
            self.chunkSizeBytes = chunkSizeBytes
            self.insertBatchSize = insertBatchSize
            self.nullString = nullString
        }
    }

    private let client: PostgresDatabaseClient
    private let logger: Logger
    private let options: Options

    public init(client: PostgresDatabaseClient, logger: Logger, options: Options = .init()) {
        self.client = client
        self.logger = logger
        self.options = options
    }

    // COPY ... TO STDOUT wrapper. Returns an async byte stream.
    public func copyOut(sql: String) async throws -> AsyncThrowingStream<Data, Error> {
        let parsed = try CopyStatement.parse(sql: sql)
        guard parsed.direction == .out else {
            throw PostgresKitError.notSupported("Expected COPY ... TO STDOUT")
        }
        guard parsed.format == .csv else {
            throw PostgresKitError.notSupported("Only CSV format supported in PostgresWire COPY OUT fallback")
        }

        let chunkSize = max(16 * 1024, options.chunkSizeBytes)
        return AsyncThrowingStream<Data, Error> { continuation in
            Task {
                do {
                    var buffer = Data(); buffer.reserveCapacity(chunkSize)
                    var wroteHeader = false
                    let selectSQL = try await parsed.selectSQL(usingClient: client)
                    let rows = try await client.simpleQuery(selectSQL)
                    for try await row in rows {
                        if parsed.header && !wroteHeader {
                            var cols: [String] = []
                            cols.reserveCapacity(row.count)
                            for cell in row { cols.append(cell.columnName) }
                            buffer.append(Self.csvLine(cols))
                            wroteHeader = true
                        }

                        var fields: [String] = []
                        fields.reserveCapacity(row.count)
                        for cell in row {
                            if var byteBuffer = cell.bytes, let data = byteBuffer.readData(length: byteBuffer.readableBytes) {
                                if let s = String(data: data, encoding: .utf8) { fields.append(s) } else { fields.append(options.nullString ?? "") }
                            } else {
                                fields.append(options.nullString ?? "")
                            }
                        }
                        buffer.append(Self.csvLine(fields))
                        if buffer.count >= chunkSize {
                            continuation.yield(buffer)
                            buffer.removeAll(keepingCapacity: true)
                        }
                    }
                    if !buffer.isEmpty { continuation.yield(buffer) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // COPY ... FROM STDIN wrapper. Consumes an async byte stream.
    public func copyIn<S: AsyncSequence>(sql: String, source: S) async throws where S.Element == Data {
        var parsed = try CopyStatement.parse(sql: sql)
        guard parsed.direction == .`in` else {
            throw PostgresKitError.notSupported("Expected COPY ... FROM STDIN")
        }
        guard parsed.format == .csv else {
            throw PostgresKitError.notSupported("Only CSV format supported in PostgresWire COPY IN fallback")
        }

        let (schema, table) = try parsed.resolveTable()
        let columns = try await PostgresMetadata().listColumns(using: client, schema: schema ?? "public", table: table)
        let columnList = columns.map { CopyStatement.quoteIdent($0.name) }.joined(separator: ", ")
        let insertPrefix = "INSERT INTO \(CopyStatement.qualify(schema: schema, table: table)) (\(columnList)) VALUES "

        var accumulator = Data()
        var rows: [[String?]] = []
        let batchSize = max(50, options.insertBatchSize)

        func flushBatch() async throws {
            guard !rows.isEmpty else { return }
            var binds: [PGData] = []
            var valuesSQL: [String] = []
            var paramIndex = 1
            for row in rows {
                var placeholders: [String] = []
                for value in row {
                    placeholders.append("$\(paramIndex)")
                    if let v = value { binds.append(PGData(string: v)) } else { binds.append(PGData.null) }
                    paramIndex += 1
                }
                valuesSQL.append("(\(placeholders.joined(separator: ", ")))\n")
            }
            let sql = insertPrefix + valuesSQL.joined(separator: ", ")
            let localBinds = binds
            try await client.withConnection { conn in
                _ = try await conn.query(sql, binds: localBinds)
            }
            rows.removeAll(keepingCapacity: true)
        }

        let parser = CSVParser(delimiter: parsed.delimiter, nullString: parsed.nullString ?? options.nullString, quote: parsed.quote)
        for try await chunk in source {
            accumulator.append(chunk)
            while let lineRange = accumulator.firstLineRange() {
                let lineData = accumulator[lineRange]
                accumulator.removeSubrange(lineRange)
                if parsed.header { parsed.header = false; continue }
                let line = String(data: lineData, encoding: .utf8) ?? ""
                let fields = parser.parseLine(line)
                rows.append(fields)
                if rows.count >= batchSize {
                    try await flushBatch()
                }
            }
        }
        if !rows.isEmpty { try await flushBatch() }
    }
}

// MARK: - Helpers

private extension AsyncSequence where Element == PostgresRow {
    // Pulls only the first row of a PostgresRowSequence if available
    func first() async throws -> PostgresRow? {
        var it = self.makeAsyncIterator()
        return try await it.next()
    }
}

private struct CopyStatement {
    enum Direction { case `in`, out }
    enum Format { case csv, text }
    var direction: Direction
    var relation: String? // schema-qualified or unqualified table
    var selectClause: String? // if COPY (SELECT ...)
    var format: Format = .csv
    var header: Bool = false
    var delimiter: Character = ","
    var nullString: String? = nil
    var quote: Character = "\""

    static func parse(sql: String) throws -> CopyStatement {
        // Extremely lightweight parser for forms:
        // COPY table [ (columns) ] FROM STDIN WITH (FORMAT csv, HEADER)
        // COPY (SELECT ...) TO STDOUT WITH (FORMAT csv, HEADER)
        var s = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.uppercased().hasPrefix("COPY ") else { throw PostgresKitError.notSupported("Not a COPY statement") }
        s.removeFirst(5)
        var stmt = CopyStatement(direction: .out, relation: nil, selectClause: nil)
        if s.first == "(" {
            // COPY (SELECT ... ) ...
            guard let end = s.firstIndex(of: ")") else { throw PostgresKitError.notSupported("Malformed COPY SELECT") }
            let inside = s[s.index(after: s.startIndex)..<end]
            stmt.selectClause = String(inside)
            s = String(s[s.index(after: end)...]).trimmingCharacters(in: .whitespaces)
        } else {
            // relation form: up to FROM/TO
            let upper = s.uppercased()
            if let range = upper.range(of: " FROM ") ?? upper.range(of: " TO ") {
                let rel = String(s[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                stmt.relation = rel
                s = String(s[range.lowerBound...])
            }
        }
        let upper = s.uppercased()
        if upper.contains(" FROM STDIN") { stmt.direction = .in }
        if upper.contains(" TO STDOUT") { stmt.direction = .out }
        if let withRange = upper.range(of: " WITH ") {
            let options = s[withRange.upperBound...].trimmingCharacters(in: .whitespaces)
            if options.range(of: "CSV", options: .caseInsensitive) != nil { stmt.format = .csv }
            if options.range(of: "HEADER", options: .caseInsensitive) != nil { stmt.header = true }
            if let delimRange = options.range(of: "DELIMITER", options: .caseInsensitive) {
                if let quote = options[delimRange.upperBound...].firstIndex(of: "'"), let quote2 = options[options.index(after: quote)...].firstIndex(of: "'") {
                    let ch = options[options.index(after: quote)..<quote2]
                    if let c = ch.first { stmt.delimiter = c }
                }
            }
            if let nullRange = options.range(of: "NULL", options: .caseInsensitive) {
                if let q1 = options[nullRange.upperBound...].firstIndex(of: "'"), let q2 = options[options.index(after: q1)...].firstIndex(of: "'") {
                    let content = options[options.index(after: q1)..<q2]
                    stmt.nullString = String(content)
                }
            }
            if let quoteRange = options.range(of: "QUOTE", options: .caseInsensitive) {
                if let q1 = options[quoteRange.upperBound...].firstIndex(of: "'"), let q2 = options[options.index(after: q1)...].firstIndex(of: "'") {
                    let content = options[options.index(after: q1)..<q2]
                    if let c = content.first { stmt.quote = c }
                }
            }
        }
        return stmt
    }

    func resolveTable() throws -> (schema: String?, table: String) {
        guard let relation else { throw PostgresKitError.notSupported("COPY SELECT requires SELECT fallback, not relation") }
        let parts = relation.split(separator: ".", maxSplits: 1).map(String.init)
        if parts.count == 2 { return (schema: parts[0].trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"")), table: parts[1].trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\""))) }
        return (schema: nil, table: parts[0])
    }

    func selectSQL(usingClient client: PostgresDatabaseClient) async throws -> String {
        if let selectClause { return selectClause }
        // Build SELECT for relation copying
        let (schema, table) = try resolveTable()
        let schemaName = schema ?? "public"
        let columns = try await PostgresMetadata().listColumns(using: client, schema: schemaName, table: table)
        let colList = columns.map { CopyStatement.quoteIdent($0.name) }.joined(separator: ", ")
        return "SELECT \(colList) FROM \(CopyStatement.qualify(schema: schema, table: table))"
    }

    static func quoteIdent(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
    static func qualify(schema: String?, table: String) -> String {
        if let schema { return "\(quoteIdent(schema)).\(quoteIdent(table))" }
        return quoteIdent(table)
    }
}

private struct CSVParser {
    let delimiter: Character
    let nullString: String?
    let quote: Character

    init(delimiter: Character, nullString: String?, quote: Character) {
        self.delimiter = delimiter
        self.nullString = nullString
        self.quote = quote
    }

    func parseLine(_ line: String) -> [String?] {
        var result: [String?] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()
        while let ch = iterator.next() {
            if ch == quote { // quote
                if inQuotes {
                    if let next = iterator.next() {
                        if next == quote { current.append(quote) } // escaped quote
                        else {
                            inQuotes = false
                            if next == delimiter { result.append(tokenToField(current)); current = "" }
                            else { current.append(next) }
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
            } else if ch == delimiter && !inQuotes {
                result.append(tokenToField(current))
                current = ""
            } else {
                current.append(ch)
            }
        }
        result.append(tokenToField(current))
        return result
    }

    private func tokenToField(_ token: String) -> String? {
        if let nullString, token == nullString { return nil }
        return token
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let d = string.data(using: .utf8) { append(d) }
    }

    mutating func appendLine() { self.append("\n") }
}

private extension Data {
    func firstLineRange() -> Range<Data.Index>? {
        if let idx = self.firstIndex(of: 0x0A) { // '\n'
            let start = self.startIndex
            let end = self.index(after: idx)
            return start..<end
        }
        return nil
    }
}

private extension PostgresBulkCopy {
    static func csvEscape(_ field: String) -> String {
        if field.isEmpty { return "" }
        let needsQuotes = field.contains(",") || field.contains("\n") || field.contains("\r") || field.contains("\"")
        var s = field.replacingOccurrences(of: "\"", with: "\"\"")
        if needsQuotes { s = "\"" + s + "\"" }
        return s
    }

    static func csvLine(_ fields: [String]) -> Data {
        let line = fields.map { csvEscape($0) }.joined(separator: ",") + "\n"
        return Data(line.utf8)
    }
}
