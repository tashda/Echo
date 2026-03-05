import Foundation
import SQLiteNIO

extension SQLiteSession {
    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        try await simpleQuery(sql, progressHandler: nil)
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        let connection = try requireConnection()

        let rows = try await connection.query(sql)
        var resolvedColumns: [ColumnInfo] = []
        var previewRows: [[String?]] = []
        previewRows.reserveCapacity(512)
        var totalRowCount = 0

        let operationStart = CFAbsoluteTimeGetCurrent()
        let streamingPreviewLimit = 512
        let maxFlushLatency: TimeInterval = 0.015

        if let firstRow = rows.first {
            resolvedColumns = makeColumnInfo(from: firstRow)
        }

        var worker: ResultStreamBatchWorker?

        for row in rows {
            if worker == nil, let handler = progressHandler, !resolvedColumns.isEmpty {
                let bridgedHandler: QueryProgressHandler = { update in
                    Task { @MainActor in handler(update) }
                }
                worker = ResultStreamBatchWorker(
                    label: "dk.tippr.echo.sqlite.streamWorker",
                    columns: resolvedColumns,
                    streamingPreviewLimit: streamingPreviewLimit,
                    maxFlushLatency: maxFlushLatency,
                    operationStart: operationStart,
                    progressHandler: bridgedHandler
                )
            }

            let decodeStart = CFAbsoluteTimeGetCurrent()
            let rowValues = makeRow(from: row)
            let decodeDuration = CFAbsoluteTimeGetCurrent() - decodeStart
            totalRowCount += 1
            if previewRows.count < streamingPreviewLimit {
                previewRows.append(rowValues)
            }
            let previewForWorker: [String?]? = totalRowCount <= streamingPreviewLimit ? rowValues : nil
            let encodedRow = ResultBinaryRowCodec.encode(row: rowValues)
            if let worker {
                worker.enqueue(
                    .init(
                        previewValues: previewForWorker,
                        storage: .encoded(encodedRow),
                        totalRowCount: totalRowCount,
                        decodeDuration: decodeDuration
                    )
                )
            }
        }

        if resolvedColumns.isEmpty {
            resolvedColumns = resolveColumnsForEmptyResult()
        }

        if resolvedColumns.isEmpty {
            resolvedColumns = [ColumnInfo(name: "result", dataType: "TEXT")]
        }

        if worker == nil, let handler = progressHandler, !resolvedColumns.isEmpty {
            let bridgedHandler: QueryProgressHandler = { update in
                Task { @MainActor in handler(update) }
            }
            worker = ResultStreamBatchWorker(
                label: "dk.tippr.echo.sqlite.streamWorker",
                columns: resolvedColumns,
                streamingPreviewLimit: streamingPreviewLimit,
                maxFlushLatency: maxFlushLatency,
                operationStart: operationStart,
                progressHandler: bridgedHandler
            )
        }

        worker?.finish(totalRowCount: totalRowCount)

        return QueryResultSet(columns: resolvedColumns, rows: previewRows, totalRowCount: totalRowCount)
    }

    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.hasSuffix(";") ? String(trimmed.dropLast()) : trimmed
        let pagedSQL = "\(base) LIMIT \(limit) OFFSET \(offset)"
        return try await simpleQuery(pagedSQL)
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        let connection = try requireConnection()
        do {
            _ = try await connection.query(sql)
            let changeRows = try await connection.query("SELECT changes() AS changes;")
            return changeRows.first?.column("changes")?.integer ?? 0
        } catch {
            throw DatabaseError.queryError(error.localizedDescription)
        }
    }

    nonisolated func makeRow(from row: SQLiteRow) -> [String?] {
        row.columns.map { column in
            switch column.data {
            case .integer(let value):
                return String(value)
            case .float(let value):
                return formatDouble(value)
            case .text(let value):
                return value
            case .blob(let buffer):
                return Data(buffer.readableBytesView).base64EncodedString()
            case .null:
                return nil
            }
        }
    }

    nonisolated func formatDouble(_ value: Double) -> String {
        if value.rounded(.towardZero) == value {
            return String(format: "%.0f", value)
        } else {
            return String(value)
        }
    }

    nonisolated func makeColumnInfo(from row: SQLiteRow) -> [ColumnInfo] {
        let columns = row.columns
        guard !columns.isEmpty else { return [] }
        return columns.map { column in
            ColumnInfo(
                name: column.name,
                dataType: inferDataType(from: column.data),
                isPrimaryKey: false,
                isNullable: true,
                maxLength: nil
            )
        }
    }

    nonisolated func inferDataType(from data: SQLiteData) -> String {
        switch data {
        case .integer: return "INTEGER"
        case .float: return "REAL"
        case .text: return "TEXT"
        case .blob: return "BLOB"
        case .null: return "TEXT"
        }
    }

    nonisolated func resolveColumnsForEmptyResult() -> [ColumnInfo] {
        []
    }
}
