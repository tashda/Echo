import Foundation
import Logging
import MySQLNIO
import NIOCore

extension MySQLSession {
    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        try await simpleQuery(sql, progressHandler: nil)
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        var previewRows: [[String?]] = []
        previewRows.reserveCapacity(512)
        var totalRowCount = 0

        let operationStart = CFAbsoluteTimeGetCurrent()
        let streamingPreviewLimit = 512
        let maxFlushLatency: TimeInterval = 0.015

        var columnMetadata: [MySQLProtocol.ColumnDefinition41] = []
        var columnInfo: [ColumnInfo] = []
        var encounteredError: Error?
        var wasCancelled = false
        var worker: ResultStreamBatchWorker?

        let future = connection.simpleQuery(sql) { row in
            if Task.isCancelled {
                wasCancelled = true
                return
            }

            if columnMetadata.isEmpty {
                columnMetadata = row.columnDefinitions
            }

            if columnInfo.isEmpty, !columnMetadata.isEmpty {
                columnInfo = columnMetadata.map { column in
                    let typeName = String(describing: column.columnType).lowercased()
                    let dataType: String
                    if typeName.hasPrefix("mysql_type_") {
                        dataType = String(typeName.dropFirst("mysql_type_".count))
                    } else {
                        dataType = typeName
                    }
                    
                    return ColumnInfo(
                        name: column.name,
                        dataType: dataType,
                        isPrimaryKey: column.flags.contains(.PRIMARY_KEY),
                        isNullable: !column.flags.contains(.COLUMN_NOT_NULL),
                        maxLength: column.columnLength == 0 ? nil : Int(column.columnLength)
                    )
                }
            }

            if worker == nil, let handler = progressHandler, !columnInfo.isEmpty {
                let bridgedHandler: QueryProgressHandler = { update in
                    Task { @MainActor in
                        handler(update)
                    }
                }
                worker = ResultStreamBatchWorker(
                    label: "dk.tippr.echo.mysql.streamWorker",
                    columns: columnInfo,
                    streamingPreviewLimit: streamingPreviewLimit,
                    maxFlushLatency: maxFlushLatency,
                    operationStart: operationStart,
                    progressHandler: bridgedHandler
                )
            }

            let capturePreview = totalRowCount < streamingPreviewLimit
            var previewValues: [String?]? = capturePreview ? [] : nil
            previewValues?.reserveCapacity(columnMetadata.count)
            var rawCells: [Data?] = []
            rawCells.reserveCapacity(columnMetadata.count)

            let decodeStart = CFAbsoluteTimeGetCurrent()
            for (definition, buffer) in zip(columnMetadata, row.values) {
                rawCells.append(self.rawCellData(from: buffer))
                if capturePreview {
                    let data = MySQLData(
                        type: definition.columnType,
                        format: row.format,
                        buffer: buffer,
                        isUnsigned: definition.flags.contains(.COLUMN_UNSIGNED)
                    )
                    previewValues?.append(self.formatter.stringValue(for: data))
                }
            }
            let decodeDuration = CFAbsoluteTimeGetCurrent() - decodeStart

            totalRowCount += 1
            if let previewRow = previewValues {
                if previewRows.count < streamingPreviewLimit {
                    previewRows.append(previewRow)
                }
            }

            let encodedRow = ResultBinaryRowCodec.encodeRaw(cells: rawCells)

            if let worker {
                let payload = ResultStreamBatchWorker.Payload(
                    previewValues: previewValues,
                    storage: .encoded(encodedRow),
                    totalRowCount: totalRowCount,
                    decodeDuration: decodeDuration
                )
                worker.enqueue(payload)
            }
        }

        do {
            try await future.get()
        } catch {
            encounteredError = error
        }

        worker?.finish(totalRowCount: totalRowCount)

        if wasCancelled {
            throw CancellationError()
        }

        if let error = encounteredError {
            throw DatabaseError.queryError(error.localizedDescription)
        }

        if columnInfo.isEmpty, !columnMetadata.isEmpty {
            columnInfo = columnMetadata.map { column in
                let typeName = String(describing: column.columnType).lowercased()
                let dataType: String
                if typeName.hasPrefix("mysql_type_") {
                    dataType = String(typeName.dropFirst("mysql_type_".count))
                } else {
                    dataType = typeName
                }
                
                return ColumnInfo(
                    name: column.name,
                    dataType: dataType,
                    isPrimaryKey: column.flags.contains(.PRIMARY_KEY),
                    isNullable: !column.flags.contains(.COLUMN_NOT_NULL),
                    maxLength: column.columnLength == 0 ? nil : Int(column.columnLength)
                )
            }
        }

        let resolvedColumns = columnInfo.isEmpty ? [ColumnInfo(name: "result", dataType: "text")] : columnInfo
        return QueryResultSet(columns: resolvedColumns, rows: previewRows, totalRowCount: totalRowCount)
    }

    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet {
        let pagedSQL = "\(sql) LIMIT \(limit) OFFSET \(offset)"
        return try await simpleQuery(pagedSQL)
    }

    func listDatabases() async throws -> [String] {
        let rows = try await connection.simpleQuery("SHOW DATABASES").get()
        let excludedSchemas: Set<String> = ["information_schema", "mysql", "performance_schema", "sys"]
        return rows.compactMap { makeString($0, index: 0)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !excludedSchemas.contains($0.lowercased()) }
    }

    func listSchemas() async throws -> [String] {
        if let current = try await currentDatabaseName() {
            return [current]
        }
        if let defaultDatabase, !defaultDatabase.isEmpty {
            return [defaultDatabase]
        }
        return []
    }

    internal func currentDatabaseName() async throws -> String? {
        let rows = try await connection.simpleQuery("SELECT DATABASE()").get()
        guard let row = rows.first, let value = makeString(row, index: 0) else { return nil }
        return value.isEmpty ? nil : value
    }

    @discardableResult
    internal func performQuery(_ sql: String, binds: [MySQLData] = []) async throws -> ([MySQLRow], MySQLQueryMetadata?) {
        let renderedSQL: String
        if binds.isEmpty {
            renderedSQL = sql
        } else {
            renderedSQL = try renderSQL(sql, with: binds)
        }

        let rows = try await connection.simpleQuery(renderedSQL).get()
        return (rows, nil)
    }

    private func renderSQL(_ sql: String, with binds: [MySQLData]) throws -> String {
        var result = String()
        result.reserveCapacity(sql.count + binds.count * 8)

        enum QuoteContext {
            case none
            case single
            case double
            case backtick
        }

        var context: QuoteContext = .none
        var bindIndex = 0
        var index = sql.startIndex

        while index < sql.endIndex {
            let character = sql[index]

            switch context {
            case .none:
                switch character {
                case "'":
                    context = .single
                    result.append(character)
                case "\"":
                    context = .double
                    result.append(character)
                case "`":
                    context = .backtick
                    result.append(character)
                case "?":
                    guard bindIndex < binds.count else {
                        throw DatabaseError.queryError("Missing bind value for placeholder in SQL: \(sql)")
                    }
                    result.append(try renderLiteral(from: binds[bindIndex]))
                    bindIndex += 1
                default:
                    result.append(character)
                }
            case .single:
                result.append(character)
                if character == "'" {
                    let next = sql.index(after: index)
                    if next < sql.endIndex, sql[next] == "'" {
                        index = next
                        result.append(sql[index])
                    } else {
                        context = .none
                    }
                }
            case .double:
                result.append(character)
                if character == "\"" {
                    let next = sql.index(after: index)
                    if next < sql.endIndex, sql[next] == "\"" {
                        index = next
                        result.append(sql[index])
                    } else {
                        context = .none
                    }
                }
            case .backtick:
                result.append(character)
                if character == "`" {
                    let next = sql.index(after: index)
                    if next < sql.endIndex, sql[next] == "`" {
                        index = next
                        result.append(sql[index])
                    } else {
                        context = .none
                    }
                }
            }

            index = sql.index(after: index)
        }

        guard bindIndex == binds.count else {
            throw DatabaseError.queryError("Too many bind values provided for SQL: \(sql)")
        }

        return result
    }

    private func renderLiteral(from data: MySQLData) throws -> String {
        if data.type == .null || data.buffer == nil {
            return "NULL"
        }

        if let string = data.string {
            return "'\(escapeStringLiteral(string))'"
        }

        if let int = data.int {
            return String(int)
        }

        if let double = data.double {
            return String(double)
        }

        if let bool = data.bool {
            return bool ? "1" : "0"
        }

        throw DatabaseError.queryError("Unsupported bind parameter type for MySQL query: \(data)")
    }

    private func escapeStringLiteral(_ value: String) -> String {
        var escaped = String()
        escaped.reserveCapacity(value.count)

        for character in value {
            switch character {
            case "'":
                escaped.append("''")
            case "\\":
                escaped.append("\\\\")
            default:
                escaped.append(character)
            }
        }

        return escaped
    }
}
