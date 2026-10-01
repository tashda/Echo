import Foundation
import SQLServerKit

/// One result set of a SQL Server run on its way to the tab. Every row goes to a
/// `ResultStreamBatchWorker` as wire bytes (zero-copy buffer references; the spool formats them
/// with the driver's `SQLServerCellFormatter` from each column's `wireType`, round 22 DF1), and the
/// first 200 also as preview strings. Extra result sets get their own sink, tagged with their index,
/// so they spool like the first set instead of staying in memory (round 22, BG1).
nonisolated final class SQLServerResultSetSink {
    static let previewLimit = 200
    private static let batchEnqueueSize = 512

    let columns: [ColumnInfo]
    private(set) var previewRows: [[String?]] = []
    private(set) var rowCount = 0
    private let worker: ResultStreamBatchWorker
    private var pending: [ResultStreamBatchWorker.Payload] = []

    /// `resultSetIndex` 0 is the first result set; later sets tag their updates with their index.
    init(
        columnDescriptions: [SQLServerColumnDescription],
        resultSetIndex: Int,
        operationStart: CFAbsoluteTime,
        progressHandler: @escaping QueryProgressHandler
    ) {
        columns = Self.columns(from: columnDescriptions)
        let handler: QueryProgressHandler
        if resultSetIndex == 0 {
            handler = progressHandler
        } else {
            handler = { @Sendable (update: QueryStreamUpdate) in
                var tagged = update
                tagged.resultSetIndex = resultSetIndex
                progressHandler(tagged)
            }
        }
        worker = ResultStreamBatchWorker(
            label: "dev.echodb.echo.mssql.streamWorker",
            columns: columns,
            streamingPreviewLimit: Self.previewLimit,
            maxFlushLatency: 0.015,
            operationStart: operationStart,
            progressHandler: handler
        )
        pending.reserveCapacity(Self.batchEnqueueSize)
    }

    static func columns(from descriptions: [SQLServerColumnDescription]) -> [ColumnInfo] {
        descriptions.map { column in
            ColumnInfo(
                name: column.name,
                dataType: column.typeName,
                isPrimaryKey: false,
                isNullable: (column.flags & 0x01) != 0,
                maxLength: column.length > 0 ? column.length : nil,
                wireType: column.cellType.encoded
            )
        }
    }

    func append(_ row: SQLServerRow) {
        rowCount += 1
        var previewValues: [String?]?
        if rowCount <= Self.previewLimit {
            let stringValues = row.toStringArray()
            previewRows.append(stringValues)
            previewValues = stringValues
        }
        let (buffers, lengths, totalLength) = row.rawColumnBuffers()
        pending.append(ResultStreamBatchWorker.Payload(
            previewValues: previewValues,
            storage: .raw(ResultStreamBatchWorker.RawRow(buffers: buffers, lengths: lengths, totalLength: totalLength)),
            totalRowCount: rowCount,
            decodeDuration: 0
        ))
        if pending.count >= Self.batchEnqueueSize {
            worker.enqueueBatch(pending)
            pending.removeAll(keepingCapacity: true)
        }
    }

    /// Sends the last rows, waits until the worker has handed everything to the tab, and returns
    /// the set as the tab's final result: preview rows and the real total.
    func finish() async -> QueryResultSet {
        if !pending.isEmpty {
            worker.enqueueBatch(pending)
            pending.removeAll()
        }
        let total = rowCount
        let worker = worker
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            worker.finish(totalRowCount: total) {
                Task { @MainActor in continuation.resume() }
            }
        }
        return QueryResultSet(columns: columns, rows: previewRows, totalRowCount: total)
    }
}
