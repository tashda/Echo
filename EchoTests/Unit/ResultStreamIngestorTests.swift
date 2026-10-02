import Foundation
import Testing
@testable import Echo

/// Updates that reach the ingestor at the same time go to one spool, and the tab is told about
/// the spool that gets finished (a second result set's tab used to stop at its 200 preview rows).
@MainActor
@Suite("Result stream ingestor")
struct ResultStreamIngestorTests {
    @MainActor final class ReadySpools {
        var handles: [ResultSpoolHandle] = []
    }

    @Test func concurrentUpdatesShareOneFinishedSpool() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ResultStreamIngestorTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let ready = ReadySpools()
        let ingestor = ResultStreamIngestor(
            spoolManager: ResultSpooler(configuration: .defaultConfiguration(rootDirectory: root)),
            rowCache: ResultSpoolRowCache()
        ) { handle in ready.handles.append(handle) }

        let columns = [ColumnInfo(name: "i", dataType: "int")]
        let batches = 20, batchSize = 100, total = batches * batchSize
        await withTaskGroup(of: Void.self) { group in
            for batch in 0..<batches {
                group.addTask {
                    let start = batch * batchSize
                    let rows = (start..<(start + batchSize)).map { ResultBinaryRowCodec.encode(row: ["\($0)"]) }
                    await ingestor.enqueue(
                        update: QueryStreamUpdate(columns: columns, appendedRows: [], encodedRows: rows,
                                                  totalRowCount: start + batchSize, rowRange: start..<(start + batchSize)),
                        isPreview: false
                    )
                }
            }
        }
        await ingestor.finalize(with: QueryResultSet(columns: columns, rows: [], totalRowCount: total))

        let handle = try #require(await ingestor.currentHandle())
        #expect(ready.handles.count == 1)
        #expect(ready.handles.first === handle)
        let rows = try await handle.loadRows(offset: 0, limit: total)
        #expect(rows.count == total)
        #expect(rows.last == ["\(total - 1)"])
    }
}
