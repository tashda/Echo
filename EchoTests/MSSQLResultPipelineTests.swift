//
// Drives Echo's real result pipeline exactly like MSSQLDedicatedQuerySession.streamQueryWithProgress
// does since round 22 (DF1): every row is stored as the driver's wire bytes, the first 200 also as
// preview strings, and the spool formats stored rows with SQLServerCellFormatter from each column's
// wireType. It needs no database.
//
// Before the fix (2026-09-30), rows after the preview were decoded as UTF-8 text: an int column read
// as control characters, and tables with datetime, money or decimal columns fell back to strings that
// differed from the preview (SQLSERVER_SPOOL_FINDING.md).

import Foundation
import NIOCore
import SQLServerKit
import Testing
@testable import Echo

@MainActor
@Suite("SQL Server result pipeline")
struct MSSQLResultPipelineTests {
    /// `id int, name nvarchar(100), city varchar(50) COLLATE Cyrillic_General_CI_AS, amount money,
    /// at datetime2(7)` as the driver describes them (`SQLServerCellType.encoded`).
    nonisolated static let columns = [
        Echo.ColumnInfo(name: "id", dataType: "int", wireType: "mssql1:26:4:0:0::"),
        Echo.ColumnInfo(name: "name", dataType: "nvarchar", wireType: "mssql1:e7:200:0:0:0904d00034:"),
        Echo.ColumnInfo(name: "city", dataType: "varchar", wireType: "mssql1:a7:50:0:0:1904d00000:"),
        Echo.ColumnInfo(name: "amount", dataType: "money", wireType: "mssql1:6e:8:0:0::"),
        Echo.ColumnInfo(name: "at", dataType: "datetime2", wireType: "mssql1:2a:8:0:7::"),
    ]

    /// What `SQLServerRow.toStringArray()` shows for row `i`.
    nonisolated static func expected(_ i: Int) -> [String?] {
        ["\(i)", "row\(i)", i.isMultiple(of: 7) ? nil : "Привет", "\(i).1234", "2026-09-30 12:34:56.1234567"]
    }

    /// Row `i` as TDS wire bytes, the way `SQLServerRow.rawColumnBuffers()` hands them over.
    nonisolated static func rawRow(_ i: Int) -> ResultStreamBatchWorker.RawRow {
        var id = ByteBuffer()
        id.writeInteger(Int32(i), endianness: .little)
        var name = ByteBuffer()
        name.writeBytes(Array("row\(i)".utf16).flatMap { [UInt8($0 & 0xFF), UInt8($0 >> 8)] })
        // "Привет" in code page 1251, the Cyrillic collation's code page.
        let city: ByteBuffer? = i.isMultiple(of: 7) ? nil : ByteBuffer(bytes: [207, 240, 232, 226, 229, 242])
        var amount = ByteBuffer()
        let units = Int64(i) * 10_000 + 1_234
        amount.writeInteger(Int32(truncatingIfNeeded: units >> 32), endianness: .little)
        amount.writeInteger(UInt32(truncatingIfNeeded: units), endianness: .little)
        var at = ByteBuffer()
        let seconds: UInt64 = 12 * 3600 + 34 * 60 + 56
        let ticks: UInt64 = seconds * 10_000_000 + 1_234_567
        at.writeBytes((0..<5).map { UInt8(truncatingIfNeeded: ticks >> (8 * $0)) })
        let days: Int = 739_888 // 2026-09-30, days since 0001-01-01
        at.writeBytes((0..<3).map { UInt8(truncatingIfNeeded: days >> (8 * $0)) })

        let buffers: [ByteBuffer?] = [id, name, city, amount, at]
        let lengths = buffers.map { $0?.readableBytes ?? -1 }
        let totalLength = lengths.reduce(0) { $0 + ($1 < 0 ? 1 : 5 + $1) }
        return .init(buffers: buffers, lengths: lengths, totalLength: totalLength)
    }

    private func runPipeline(total: Int) async throws -> QueryEditorState {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MSSQLResultPipelineTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let spoolManager = ResultSpooler(configuration: .defaultConfiguration(rootDirectory: tempRoot))
        // Same defaults as a real query tab (resultsInitialRowLimit 500).
        let state = QueryEditorState(sql: "SELECT * FROM t", initialVisibleRowBatch: 500, previewRowLimit: 512, spoolManager: spoolManager)
        state.startExecution()

        let columns = Self.columns
        let preview = 200
        // WorkspaceTabContainerView+Execution: second MainActor hop.
        let tabHandler: QueryProgressHandler = { [weak state] update in
            guard let state else { return }
            Task { @MainActor in state.applyStreamUpdate(update) }
        }
        // The session's bridgedHandler: first MainActor hop.
        let bridged: QueryProgressHandler = { update in
            Task { @MainActor in tabHandler(update) }
        }

        let result: QueryResultSet = await Task.detached {
            let worker = ResultStreamBatchWorker(
                label: "test.mssql.pipeline", columns: columns, streamingPreviewLimit: preview,
                maxFlushLatency: 0.015, operationStart: CFAbsoluteTimeGetCurrent(), progressHandler: bridged)
            var previewRows: [[String?]] = []
            var pending: [ResultStreamBatchWorker.Payload] = []
            for i in 1...total {
                let previewValues: [String?]? = i <= preview ? Self.expected(i) : nil
                if let previewValues { previewRows.append(previewValues) }
                pending.append(.init(previewValues: previewValues, storage: .raw(Self.rawRow(i)), totalRowCount: i, decodeDuration: 0))
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

    @Test(arguments: [201, 1_000, 5_000])
    func rowsAfterThePreviewReadLikeThePreview(total: Int) async throws {
        let state = try await runPipeline(total: total)
        #expect(state.displayedRowCount == total)
        for index in [0, 199, 200, 202, total - 1] where index < total {
            #expect(state.displayedRow(at: index) == Self.expected(index + 1), "row \(index + 1) of \(total)")
        }
    }

    @Test func spooledRowDecodesWithTheDriverFormatter() throws {
        let types = try #require(SQLServerSpoolColumns.cellTypes(for: Self.columns))
        for i in [1, 7, 250] {
            let raw = Self.rawRow(i)
            let row = ResultBinaryRow(raw: ResultBinaryRow.Raw(buffers: raw.buffers, lengths: raw.lengths, totalLength: raw.totalLength))
            #expect(SQLServerSpoolColumns.decodeRow(row.data, types: types) == Self.expected(i))
            #expect(ResultBinaryRowCodec.decode(row, columns: Self.columns) == Self.expected(i))
        }
    }

    @Test func columnsWithoutWireTypesAreNotSQLServerSpools() {
        #expect(SQLServerSpoolColumns.cellTypes(for: [Echo.ColumnInfo(name: "id", dataType: "int")]) == nil)
        #expect(SQLServerSpoolColumns.cellTypes(for: [Echo.ColumnInfo(name: "id", dataType: "INTEGER(23)")]) == nil)
        #expect(SQLServerSpoolColumns.cellTypes(for: []) == nil)
    }

    @Test func wireTypeSurvivesTheSpoolHeader() throws {
        let data = try JSONEncoder().encode(Self.columns)
        let decoded = try JSONDecoder().decode([Echo.ColumnInfo].self, from: data)
        let decodedTypes: [String?] = decoded.map { $0.wireType }
        let writtenTypes: [String?] = Self.columns.map { $0.wireType }
        #expect(decodedTypes == writtenTypes)
        // Spools written before round 22 have no wireType and still decode.
        let oldHeader = Data(#"[{"name":"id","dataType":"int","isPrimaryKey":false,"isNullable":true}]"#.utf8)
        let old: [Echo.ColumnInfo] = try JSONDecoder().decode([Echo.ColumnInfo].self, from: oldHeader)
        let oldType: String? = old.first?.wireType
        #expect(old.count == 1)
        #expect(oldType == nil)
    }
}
