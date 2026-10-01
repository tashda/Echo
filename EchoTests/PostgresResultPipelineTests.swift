//
// Drives Echo's real result pipeline exactly like PostgresSession.streamQueryUsingSimpleProtocol does:
// 200 preview rows (encoded + preview strings), the rest binary-only, through ResultStreamBatchWorker,
// the driver's MainActor hop, the tab's MainActor hop, consumeFinalResult, finishExecution, the spool
// and progressive materialization. It needs no database.
//
// Before the Echo fixes (2026-09-30):
//   - Echo main: N in 201...499 shows 200 rows (E1).
//   - every branch: row 251's id reads "00 00 00 fb" instead of "251" (E2).

import XCTest
@testable import Echo

@MainActor
final class PostgresResultPipelineTests: XCTestCase {
    private var retained: [AnyObject] = []

    /// One row in Echo's binary row format: per cell 0x01 + UInt32-LE length + Postgres binary bytes.
    nonisolated private static func encodeRow(id: Int32, name: String) -> Data {
        var data = Data()
        func appendCell(_ bytes: [UInt8]) {
            data.append(0x01)
            var length = UInt32(bytes.count).littleEndian
            withUnsafeBytes(of: &length) { data.append(contentsOf: $0) }
            data.append(contentsOf: bytes)
        }
        appendCell(withUnsafeBytes(of: id.bigEndian) { Array($0) })
        appendCell(Array(name.utf8))
        return data
    }

    private func runPipeline(total: Int) async throws -> QueryEditorState {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PostgresResultPipelineTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let spoolManager = ResultSpooler(configuration: .defaultConfiguration(rootDirectory: tempRoot))
        // Same defaults as a real query tab (resultsInitialRowLimit 500).
        let state = QueryEditorState(sql: "SELECT * FROM t", initialVisibleRowBatch: 500, previewRowLimit: 512, spoolManager: spoolManager)
        retained.append(state)
        state.startExecution()

        let columns = [ColumnInfo(name: "id", dataType: "INTEGER(23)"), ColumnInfo(name: "name", dataType: "TEXT(25)")]
        let preview = 200

        // WorkspaceTabContainerView+Execution: second MainActor hop.
        let tabHandler: QueryProgressHandler = { [weak state] update in
            guard let state else { return }
            Task { @MainActor in state.applyStreamUpdate(update) }
        }
        // PostgresSession bridgedHandler: first MainActor hop.
        let bridged: QueryProgressHandler = { update in
            Task { @MainActor in tabHandler(update) }
        }

        let result: QueryResultSet = await Task.detached {
            let worker = ResultStreamBatchWorker(
                label: "test.postgres.pipeline", columns: columns, streamingPreviewLimit: preview,
                maxFlushLatency: 0.015, operationStart: CFAbsoluteTimeGetCurrent(), progressHandler: bridged)
            var previewRows: [[String?]] = []
            var pending: [ResultStreamBatchWorker.Payload] = []
            for i in 1...total {
                let row = ResultBinaryRow(data: Self.encodeRow(id: Int32(i), name: "row\(i)"))
                let previewValues: [String?]? = i <= preview ? ["\(i)", "row\(i)"] : nil
                if let previewValues { previewRows.append(previewValues) }
                pending.append(.init(previewValues: previewValues, storage: .encoded(row), totalRowCount: i, decodeDuration: 0))
                if pending.count >= 512 { worker.enqueueBatch(pending); pending.removeAll() }
            }
            if !pending.isEmpty { worker.enqueueBatch(pending) }
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                worker.finish(totalRowCount: total) { Task { @MainActor in continuation.resume() } }
            }
            return QueryResultSet(columns: columns, rows: previewRows, totalRowCount: total)
        }.value

        state.consumeFinalResult(result)
        state.finishExecution()

        for _ in 0..<100 where state.displayedRowCount < total {
            try await Task.sleep(for: .milliseconds(50))
        }
        return state
    }

    func testEveryRowIsShownAndDecoded() async throws {
        for total in [150, 201, 250, 499, 501, 1_500, 10_000] {
            let state = try await runPipeline(total: total)
            XCTAssertEqual(state.displayedRowCount, total, "rows shown for \(total)")
            XCTAssertEqual(state.rowProgress.totalReported, total)
            for index in [0, 199, 200, total - 1] where index < total {
                XCTAssertEqual(state.displayedRow(at: index), ["\(index + 1)", "row\(index + 1)"], "row \(index) of \(total)")
            }
        }
    }
}
