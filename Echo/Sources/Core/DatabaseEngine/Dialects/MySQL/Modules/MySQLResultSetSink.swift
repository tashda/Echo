import Foundation
import MySQLKit

/// One result set of a MySQL or MariaDB run on its way to the tab, as for SQL Server (round 22,
/// BG1): each row goes to a `ResultStreamBatchWorker` as its display text (the spool keeps the
/// text, so spooled rows read like the preview), and the first 512 also as preview strings. Extra
/// result sets (several statements, a procedure's SELECTs) get their own sink, tagged with their
/// index, so they show as their own grids and spool like the first.
nonisolated final class MySQLResultSetSink {
    static let previewLimit = 512

    let columns: [MySQLColumn]
    let columnInfo: [ColumnInfo]
    private(set) var previewRows: [[String?]] = []
    private(set) var rowCount = 0
    private let formatter: MySQLCellFormatter
    private let worker: ResultStreamBatchWorker

    /// `resultSetIndex` 0 is the first result set; later sets tag their updates with their index.
    init(
        columns: [MySQLColumn],
        resultSetIndex: Int,
        formatter: MySQLCellFormatter,
        operationStart: CFAbsoluteTime,
        progressHandler: @escaping QueryProgressHandler
    ) {
        self.columns = columns
        self.formatter = formatter
        columnInfo = MySQLSession.columnInfo(for: columns)
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
            label: "dev.echodb.echo.mysql.streamWorker",
            columns: columnInfo,
            streamingPreviewLimit: Self.previewLimit,
            maxFlushLatency: 0.015,
            operationStart: operationStart,
            progressHandler: handler
        )
    }

    /// One batch of rows, as the connection read them.
    func append(_ rows: [MySQLRow]) {
        var payloads: [ResultStreamBatchWorker.Payload] = []
        payloads.reserveCapacity(rows.count)
        for row in rows {
            let decodeStart = CFAbsoluteTimeGetCurrent()
            let values = columns.indices.map { formatter.stringValue(bytes: row.value(at: $0).bytes, column: columns[$0]) }
            rowCount += 1
            let capturePreview = rowCount <= Self.previewLimit
            if capturePreview { previewRows.append(values) }
            payloads.append(ResultStreamBatchWorker.Payload(
                previewValues: capturePreview ? values : nil,
                storage: .encoded(ResultBinaryRowCodec.encodeRaw(cells: values.map { $0.map { Data($0.utf8) } })),
                totalRowCount: rowCount,
                decodeDuration: CFAbsoluteTimeGetCurrent() - decodeStart
            ))
        }
        worker.enqueueBatch(payloads)
    }

    /// Waits until the worker has handed everything to the tab, and returns the set as the tab's
    /// final result: preview rows and the real total.
    func finish() async -> QueryResultSet {
        let total = rowCount
        let worker = worker
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            worker.finish(totalRowCount: total) {
                Task { @MainActor in continuation.resume() }
            }
        }
        return QueryResultSet(columns: columnInfo, rows: previewRows, totalRowCount: total)
    }

    /// A run that failed or was cancelled: sends what arrived, without waiting.
    func abandon() {
        worker.finish(totalRowCount: rowCount)
    }
}
