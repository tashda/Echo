import Foundation

/// A synchronous spool writer for high-throughput streaming.
///
/// Writes binary row data directly to a file on the caller's thread (typically a serial GCD queue).
/// Avoids actor hops by using synchronous `FileHandle` writes. The accumulated state
/// (chunk records, byte offsets) is later transferred to a `ResultSpoolHandle` for reading.
///
/// Thread safety: callers must ensure serialized access (e.g., from a serial DispatchQueue).
final class SynchronousSpoolWriter: @unchecked Sendable {
    struct ChunkRecord: Sendable {
        let startRow: Int
        let rowCount: Int
        let offset: UInt64
        let byteLength: UInt64
        let rowLengths: ContiguousArray<UInt32>
    }

    let id: UUID
    let directory: URL
    private let writeHandle: FileHandle
    private(set) var fileOffset: UInt64 = 0
    private(set) var totalBytesWritten: UInt64 = 0
    private(set) var chunkRecords: [ChunkRecord] = []
    private(set) var totalRowCount: Int = 0
    private var headerWritten = false
    private var headerLength: UInt64 = 0

    private static let newlineByte: UInt8 = 0x0A

    init(id: UUID = UUID(), rootDirectory: URL) throws {
        self.id = id
        self.directory = rootDirectory.appendingPathComponent(id.uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let rowsURL = directory.appendingPathComponent("rows.bin")
        FileManager.default.createFile(atPath: rowsURL.path, contents: nil)
        self.writeHandle = try FileHandle(forWritingTo: rowsURL)
    }

    func writeHeader(columns: [ColumnInfo]) throws {
        guard !headerWritten else { return }
        let payload = HeaderPayload(columns: columns, createdAt: Date(), rowEncoding: "binary_v1")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let headerData = try encoder.encode(payload)
        writeHandle.write(headerData)
        writeHandle.write(Data([Self.newlineByte]))
        headerLength = UInt64(headerData.count + 1)
        fileOffset += headerLength
        totalBytesWritten += headerLength
        headerWritten = true
    }

    func appendEncodedRows(_ rows: [ResultBinaryRow], startRow: Int) {
        guard !rows.isEmpty else { return }

        let chunkStartOffset = fileOffset
        var rowLengths = ContiguousArray<UInt32>()
        rowLengths.reserveCapacity(rows.count)

        var buffer = Data()
        var estimatedSize = 0
        for row in rows {
            switch row.storage {
            case .data(let d): estimatedSize += d.count + 1
            case .raw(let r): estimatedSize += r.totalLength + 1
            }
        }
        buffer.reserveCapacity(estimatedSize)

        for row in rows {
            let rowData = row.data
            buffer.append(rowData)
            buffer.append(Self.newlineByte)
            rowLengths.append(UInt32(clamping: rowData.count))
        }

        writeHandle.write(buffer)
        let bytesWritten = UInt64(buffer.count)
        fileOffset += bytesWritten
        totalBytesWritten += bytesWritten

        let chunk = ChunkRecord(
            startRow: startRow,
            rowCount: rows.count,
            offset: chunkStartOffset,
            byteLength: bytesWritten,
            rowLengths: rowLengths
        )
        chunkRecords.append(chunk)
        totalRowCount = max(totalRowCount, startRow + rows.count)
    }

    func close() {
        try? writeHandle.synchronize()
        try? writeHandle.close()
    }

    private struct HeaderPayload: Encodable {
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
}
