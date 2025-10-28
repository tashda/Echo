import Foundation
import Logging

public struct PostgresAdmin {
    private let client: PostgresDatabaseClient
    private let logger: Logger

    public init(client: PostgresDatabaseClient, logger: Logger) {
        self.client = client
        self.logger = logger
    }

    @discardableResult
    public func vacuum(schema: String? = nil, table: String? = nil, analyze: Bool = false, full: Bool = false, verbose: Bool = false) async throws -> Int {
        var parts: [String] = ["VACUUM"]
        if full { parts.append("FULL") }
        if analyze { parts.append("ANALYZE") }
        if verbose { parts.append("VERBOSE") }
        if let table {
            if let schema {
                parts.append("\"\(schema)\".\"\(table)\"")
            } else {
                parts.append("\"\(table)\"")
            }
        }
        let sql = parts.joined(separator: " ")
        return try await execUpdate(sql)
    }

    @discardableResult
    public func analyze(schema: String? = nil, table: String? = nil, verbose: Bool = false) async throws -> Int {
        var parts: [String] = ["ANALYZE"]
        if verbose { parts.append("VERBOSE") }
        if let table {
            if let schema {
                parts.append("\"\(schema)\".\"\(table)\"")
            } else {
                parts.append("\"\(table)\"")
            }
        }
        let sql = parts.joined(separator: " ")
        return try await execUpdate(sql)
    }

    @discardableResult
    public func reindex(database: String? = nil, schema: String? = nil, table: String? = nil, index: String? = nil, verbose: Bool = false) async throws -> Int {
        var parts: [String] = ["REINDEX"]
        if verbose { parts.append("(VERBOSE)") }
        if let index { parts.append("INDEX \(quoteIdent(index))") }
        else if let table {
            if let schema { parts.append("TABLE \(quoteIdent(schema)).\(quoteIdent(table))") }
            else { parts.append("TABLE \(quoteIdent(table))") }
        } else if let schema { parts.append("SCHEMA \(quoteIdent(schema))") }
        else if let database { parts.append("DATABASE \(quoteIdent(database))") }
        let sql = parts.joined(separator: " ")
        return try await execUpdate(sql)
    }

    @discardableResult
    public func createExtension(_ name: String, ifNotExists: Bool = true, schema: String? = nil) async throws -> Int {
        var parts: [String] = ["CREATE EXTENSION"]
        if ifNotExists { parts.append("IF NOT EXISTS") }
        parts.append(quoteIdent(name))
        if let schema { parts.append("WITH SCHEMA \(quoteIdent(schema))") }
        let sql = parts.joined(separator: " ")
        return try await execUpdate(sql)
    }

    public func set(_ parameter: String, value: String) async throws {
        let sql = "SET \(quoteIdent(parameter)) TO \(quoteLiteral(value))"
        _ = try await execUpdate(sql)
    }

    public func show(_ parameter: String) async throws -> String? {
        let sql = "SHOW \(quoteIdent(parameter))"
        let rows = try await client.simpleQuery(sql)
        for try await value in rows.decode(String?.self) { return value }
        return nil
    }

    // MARK: - Helpers
    private func execUpdate(_ sql: String) async throws -> Int {
        try await client.withConnection { conn in
            var count = 0
            let rows = try await conn.simpleQuery(sql)
            for try await _ in rows { count += 1 }
            return count
        }
    }

    private func quoteIdent(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func quoteLiteral(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "'", with: "''")
        return "'\(escaped)'"
    }
}

