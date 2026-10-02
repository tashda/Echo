import Foundation
import EchoLocalStorage
import SQLServerKit
import NIOCore
import OSLog

actor ResultSpoolHandle {
    static let newlineByte: UInt8 = 0x0A
    let id: UUID
    let directory: URL
    var metadata: ResultSpoolMetadata
    let configuration: ResultSpoolConfiguration
    let encryption: LocalEncryption
    let storage: EncryptedRecordStore
    var archiveTask: Task<Void, Never>?

    var headerWritten = false
    var writeHandle: FileHandle?
    var readHandle: FileHandle?
    var fileOffset: UInt64 = 0
    var chunkRecords: [ChunkRecord] = []
    var inMemoryRows: [[String?]] = []
    var statContinuations: [UUID: AsyncStream<ResultSpoolStats>.Continuation] = [:]
    var chunksAreSorted = false
    var totalBytesWritten: UInt64 = 0
    var headerLength: UInt64 = 0
    var transientDispatchTask: Task<Void, Never>?
    var lastTransientEmission: UInt64 = 0
    let transientDispatchInterval: UInt64 = 80_000_000 // 80 ms trailing flush
    let transientImmediateInterval: UInt64 = 25_000_000  // 25 ms (~40 Hz)
    /// Postgres column OIDs, resolved on first decode (see `postgresColumnOIDs()`).
    var cachedPostgresOIDs: CachedOIDs?

    struct CachedOIDs { let value: [UInt32]? }
    /// SQL Server cell types, resolved on first decode (see `sqlServerCellTypes()`).
    var cachedSQLServerCellTypes: CachedCellTypes?

    struct CachedCellTypes { let value: [SQLServerCellType]? }

    func debugLog(_ message: String) {
        Logger.spool.debug("\(message)")
    }

    struct ChunkRecord: Sendable {
        let startRow: Int
        let rowCount: Int
        let offset: UInt64
        let byteLength: UInt64
        let rowLengths: ContiguousArray<UInt32>
    }

    struct HeaderPayload: Encodable {
        let __isStreamHeader: Bool
        let columns: [ColumnInfo]
        let createdAt: Date
        let rowEncoding: String

        init(columns: [ColumnInfo], createdAt: Date, rowEncoding: String) {
            self.__isStreamHeader = true
            self.columns = columns
            self.createdAt = createdAt
            self.rowEncoding = rowEncoding
        }
    }

    init(id: UUID, directory: URL, configuration: ResultSpoolConfiguration,
         encryption: LocalEncryption, storage: EncryptedRecordStore) throws {
        self.encryption = encryption
        self.storage = storage
        self.id = id
        self.directory = directory
        self.configuration = configuration
        self.metadata = ResultSpoolMetadata(
            id: id,
            createdAt: Date(),
            updatedAt: Date(),
            totalRowCount: 0,
            commandTag: nil,
            isFinished: false,
            columns: [],
            cumulativeBytes: 0,
            latestMetrics: nil,
            rowEncoding: nil
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let rowsURL = directory.appendingPathComponent("rows.bin")
        FileManager.default.createFile(atPath: rowsURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        self.writeHandle = try FileHandle(forWritingTo: rowsURL)
        self.writeHandle?.seekToEndOfFile()
        self.fileOffset = 0
    }

    deinit {
        transientDispatchTask?.cancel()
        transientDispatchTask = nil
        try? writeHandle?.close()
        try? readHandle?.close()
        statContinuations.values.forEach { $0.finish() }
    }

    func close() async {
        await archiveTask?.value
        transientDispatchTask?.cancel()
        transientDispatchTask = nil
        try? writeHandle?.close()
        writeHandle = nil
        try? readHandle?.close()
        readHandle = nil
        statContinuations.values.forEach { $0.finish() }
        statContinuations.removeAll()
    }
}
