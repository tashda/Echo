import Foundation
import MySQLKit
import MySQLWire

extension MySQLSession {
    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        try await simpleQuery(sql, progressHandler: nil)
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        if QueryStatementClassifier.isLikelyMessageOnlyStatement(sql, databaseType: .mysql) {
            return try await executeSimpleQuery(sql)
        }

        guard let progressHandler else {
            return try await executeSimpleQuery(sql)
        }

        var previewRows: [[String?]] = []
        previewRows.reserveCapacity(512)
        var totalRowCount = 0

        let operationStart = CFAbsoluteTimeGetCurrent()
        let streamingPreviewLimit = 512
        let maxFlushLatency: TimeInterval = 0.015

        var columnMetadata: [MySQLProtocol.ColumnDefinition41] = []
        var columnInfo: [ColumnInfo] = []
        var worker: ResultStreamBatchWorker?
        let bridgedHandler: QueryProgressHandler = { update in
            Task { @MainActor in
                progressHandler(update)
            }
        }

        do {
            let stream = try await client.stream(sql)
            for try await row in stream {
                try Task.checkCancellation()

                if columnMetadata.isEmpty {
                    columnMetadata = row.columnDefinitions
                }
                if columnInfo.isEmpty, !columnMetadata.isEmpty {
                    columnInfo = makeColumnInfo(from: columnMetadata)
                    worker = ResultStreamBatchWorker(
                        label: "dev.echodb.echo.mysql.streamWorker",
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
                for (index, definition) in columnMetadata.enumerated() {
                    let buffer = row.values[index]
                    rawCells.append(rawCellData(from: buffer))
                    if capturePreview {
                        let data = MySQLData(
                            type: definition.columnType,
                            format: row.format,
                            buffer: buffer,
                            isUnsigned: definition.flags.contains(.COLUMN_UNSIGNED)
                        )
                        previewValues?.append(formatter.stringValue(for: data))
                    }
                }
                let decodeDuration = CFAbsoluteTimeGetCurrent() - decodeStart

                totalRowCount += 1
                if let previewRow = previewValues, previewRows.count < streamingPreviewLimit {
                    previewRows.append(previewRow)
                }

                let encodedRow = ResultBinaryRowCodec.encodeRaw(cells: rawCells)
                worker?.enqueue(
                    ResultStreamBatchWorker.Payload(
                        previewValues: previewValues,
                        storage: .encoded(encodedRow),
                        totalRowCount: totalRowCount,
                        decodeDuration: decodeDuration
                    )
                )
            }
        } catch is CancellationError {
            worker?.finish(totalRowCount: totalRowCount)
            throw CancellationError()
        } catch {
            worker?.finish(totalRowCount: totalRowCount)
            throw DatabaseError.queryError(error.localizedDescription)
        }

        worker?.finish(totalRowCount: totalRowCount)
        let resolvedColumns = columnInfo.isEmpty ? [ColumnInfo(name: "result", dataType: "text")] : columnInfo
        return QueryResultSet(columns: resolvedColumns, rows: previewRows, totalRowCount: totalRowCount)
    }

    func simpleQuery(
        _ sql: String,
        executionMode: ResultStreamingExecutionMode?,
        progressHandler: QueryProgressHandler?
    ) async throws -> QueryResultSet {
        try await simpleQuery(sql, progressHandler: progressHandler)
    }

    private func executeSimpleQuery(_ sql: String) async throws -> QueryResultSet {
        do {
            let result = try await client.query(sql)
            return makeResultSet(from: result.rows, metadata: result.metadata)
        } catch {
            throw DatabaseError.queryError(error.localizedDescription)
        }
    }

    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet {
        let pagedSQL = "\(sql) LIMIT \(limit) OFFSET \(offset)"
        return try await simpleQuery(pagedSQL)
    }

    func listDatabases() async throws -> [String] {
        try await client.metadata.listDatabases()
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

    public func currentDatabaseName() async throws -> String? {
        try await client.session.currentDatabase()
    }

    @discardableResult
    internal func performQuery(_ sql: String, binds: [MySQLData] = []) async throws -> ([MySQLRow], MySQLWireQueryMetadata?) {
        let result = try await client.query(sql, binds: binds)
        return (result.rows, result.metadata)
    }

    private func makeColumnInfo(from metadata: [MySQLProtocol.ColumnDefinition41]) -> [ColumnInfo] {
        metadata.map { column in
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

    private func makeResultSet(from rows: [MySQLRow], metadata: MySQLWireQueryMetadata? = nil) -> QueryResultSet {
        let columns = rows.first.map { makeColumnInfo(from: $0.columnDefinitions) } ?? []
        let previewRows = rows.map { row in
            row.values.indices.map { index in
                makeString(row, index: index)
            }
        }

        return QueryResultSet(
            columns: columns,
            rows: previewRows,
            totalRowCount: rows.count,
            commandTag: metadata.map(commandResponse(from:))
        )
    }

    private func commandResponse(from metadata: MySQLWireQueryMetadata) -> String {
        var segments = ["affectedRows=\(metadata.affectedRows)"]
        if let lastInsertID = metadata.lastInsertID {
            segments.append("lastInsertID=\(lastInsertID)")
        }
        return segments.joined(separator: ", ")
    }
}
