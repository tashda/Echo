import Foundation
import NIOCore
import PostgresWire

struct ResultSpoolConfiguration: Equatable, Sendable {
    var rootDirectory: URL
    var maximumBytes: UInt64
    var retentionInterval: TimeInterval
    var inMemoryRowLimit: Int

    static func defaultConfiguration(rootDirectory: URL) -> ResultSpoolConfiguration {
        ResultSpoolConfiguration(
            rootDirectory: rootDirectory,
            maximumBytes: 5 * 1_024 * 1_024 * 1_024, // 5 GB
            retentionInterval: 72 * 60 * 60,          // 72 hours
            inMemoryRowLimit: 500
        )
    }

    nonisolated static func == (lhs: ResultSpoolConfiguration, rhs: ResultSpoolConfiguration) -> Bool {
        lhs.rootDirectory.path == rhs.rootDirectory.path
            && lhs.maximumBytes == rhs.maximumBytes
            && lhs.retentionInterval == rhs.retentionInterval
            && lhs.inMemoryRowLimit == rhs.inMemoryRowLimit
    }
}

@preconcurrency struct ResultSpoolStats: Sendable, Codable {
    let spoolID: UUID
    let rowCount: Int
    let lastBatchCount: Int
    let cumulativeBytes: UInt64
    let lastUpdated: Date
    let metrics: QueryStreamMetrics?
    let isFinished: Bool
}

@preconcurrency struct ResultSpoolMetadata: Sendable, Codable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    var totalRowCount: Int
    var commandTag: String?
    var isFinished: Bool
    var columns: [ColumnInfo]
    var cumulativeBytes: UInt64
    var latestMetrics: QueryStreamMetrics?
    var rowEncoding: String?
}

enum ResultSpoolError: Error {
    case headerAlreadyWritten
    case headerMissing
    case fileClosed
    case invalidRange
}

struct ResultBinaryRowCodec {
    nonisolated static func encode(row: [String?]) -> ResultBinaryRow {
        var data = Data()
        data.reserveCapacity(row.count * 16)
        for value in row {
            switch value {
            case .some(let string):
                data.append(0x01)
                let utf8 = string.utf8
                var length = UInt32(utf8.count).littleEndian
                withUnsafeBytes(of: &length) { pointer in
                    data.append(contentsOf: pointer)
                }
                data.append(contentsOf: utf8)
            case .none:
                data.append(0x00)
            }
        }
        return ResultBinaryRow(data: data)
    }

    nonisolated static func encodeRaw(cells: [Data?]) -> ResultBinaryRow {
        var totalLength = cells.count // flag byte per column
        for cell in cells {
            if let raw = cell {
                totalLength &+= 4
                totalLength &+= raw.count
            }
        }

        var data = Data(count: totalLength)
        data.withUnsafeMutableBytes { mutableBytes in
            guard let baseAddress = mutableBytes.baseAddress else { return }
            var offset = 0

            for cell in cells {
                if let raw = cell {
                    baseAddress.storeBytes(of: UInt8(0x01), toByteOffset: offset, as: UInt8.self)
                    offset &+= 1

                    var length = UInt32(raw.count).littleEndian
                _ = withUnsafeBytes(of: &length) { pointer in
                    memcpy(baseAddress.advanced(by: offset), pointer.baseAddress!, 4)
                }
                    offset &+= 4

                    _ = raw.withUnsafeBytes { rawPointer in
                        memcpy(baseAddress.advanced(by: offset), rawPointer.baseAddress!, raw.count)
                    }
                    offset &+= raw.count
                } else {
                    baseAddress.storeBytes(of: UInt8(0x00), toByteOffset: offset, as: UInt8.self)
                    offset &+= 1
                }
            }
        }
        return ResultBinaryRow(data: data)
    }

    nonisolated static func decode(_ binaryRow: ResultBinaryRow, columnCount: Int) -> [String?] {
        extractCellBytes(binaryRow, columnCount: columnCount).map { cellData in
            guard let cellData else { return nil }
            return String(data: cellData, encoding: .utf8) ?? cellData.map { String(format: "%02x", $0) }.joined(separator: " ")
        }
    }

    /// Type-aware decode: formats each cell using direct binary interpretation.
    /// Avoids creating ByteBuffer/PostgresCell per cell — ~10x faster than PostgresPayloadFormatter path.
    nonisolated static func decode(_ binaryRow: ResultBinaryRow, columns: [ColumnInfo]) -> [String?] {
        let data = binaryRow.data
        var result: [String?] = []
        result.reserveCapacity(columns.count)

        var index = data.startIndex
        var columnIndex = 0

        while index < data.endIndex && columnIndex < columns.count {
            let flag = data[index]
            index = data.index(after: index)

            if flag == 0x00 {
                result.append(nil)
                columnIndex += 1
                continue
            }

            let remaining = data.distance(from: index, to: data.endIndex)
            guard remaining >= 4 else { break }
            let lengthValue = UInt32(data[index])
                | (UInt32(data[data.index(after: index)]) << 8)
                | (UInt32(data[data.index(index, offsetBy: 2)]) << 16)
                | (UInt32(data[data.index(index, offsetBy: 3)]) << 24)
            let length = Int(lengthValue)
            index = data.index(index, offsetBy: 4)

            guard length >= 0, let end = data.index(index, offsetBy: length, limitedBy: data.endIndex) else { break }
            let cellData = data[index..<end]
            index = end

            let oid = columnIndex < columns.count
                ? (PostgresDataTypeOIDMap.oid(for: columns[columnIndex].dataType) ?? 25)
                : 25
            if let formatted = DirectBinaryDecoder.format(cellData, oid: oid) {
                result.append(formatted)
            } else {
                // Fallback for types DirectBinaryDecoder can't handle (e.g., Numeric)
                let slowFormatter = PostgresPayloadFormatter()
                let payload = ResultCellPayload(dataTypeOID: oid, format: .binary, bytes: Data(cellData))
                result.append(slowFormatter.stringValue(for: payload, columnIndex: columnIndex))
            }
            columnIndex += 1
        }

        while result.count < columns.count {
            result.append(nil)
        }
        return result
    }

    /// Extract raw cell bytes from a binary row without formatting.
    private nonisolated static func extractCellBytes(_ binaryRow: ResultBinaryRow, columnCount: Int) -> [Data?] {
        let data = binaryRow.data
        var result: [Data?] = []
        result.reserveCapacity(max(columnCount, 1))

        var index = data.startIndex
        while index < data.endIndex {
            let flag = data[index]
            index = data.index(after: index)

            if flag == 0x00 {
                result.append(nil)
                continue
            }

            let remaining = data.distance(from: index, to: data.endIndex)
            guard remaining >= 4 else { break }
            let idx1 = data.index(after: index)
            let idx2 = data.index(idx1, offsetBy: 1)
            let idx3 = data.index(idx2, offsetBy: 1)
            let lengthValue = UInt32(data[index])
                | (UInt32(data[idx1]) << 8)
                | (UInt32(data[idx2]) << 16)
                | (UInt32(data[idx3]) << 24)
            let length = Int(lengthValue)
            index = data.index(index, offsetBy: 4)

            guard length >= 0 else { break }
            guard let end = data.index(index, offsetBy: length, limitedBy: data.endIndex) else { break }
            result.append(Data(data[index..<end]))
            index = end
        }

        if columnCount > result.count {
            result.append(contentsOf: repeatElement(nil, count: columnCount - result.count))
        }
        return result
    }
}

/// Extracts Postgres OIDs from ColumnInfo.dataType strings.
/// Format: "TYPE(OID)" e.g. "INTEGER(23)" or legacy "INTEGER"
enum PostgresDataTypeOIDMap {
    nonisolated static func oid(for dataType: String) -> UInt32? {
        // Try to extract OID from "TYPE(OID)" format
        if let openParen = dataType.lastIndex(of: "("),
           let closeParen = dataType.lastIndex(of: ")"),
           closeParen > openParen {
            let oidStr = dataType[dataType.index(after: openParen)..<closeParen]
            return UInt32(oidStr)
        }
        // Fallback: map known type names to OIDs
        switch dataType.uppercased() {
        case "BOOLEAN": return 16
        case "BYTEA": return 17
        case "BIGINT", "INT8": return 20
        case "SMALLINT", "INT2": return 21
        case "INTEGER", "INT4": return 23
        case "TEXT": return 25
        case "OID": return 26
        case "JSON": return 114
        case "REAL", "FLOAT4": return 700
        case "DOUBLE PRECISION", "FLOAT8": return 701
        case "VARCHAR", "CHARACTER VARYING": return 1043
        case "DATE": return 1082
        case "TIME", "TIME WITHOUT TIME ZONE": return 1083
        case "TIMESTAMP", "TIMESTAMP WITHOUT TIME ZONE": return 1114
        case "TIMESTAMP WITH TIME ZONE", "TIMESTAMPTZ": return 1184
        case "NUMERIC": return 1700
        case "UUID": return 2950
        case "JSONB": return 3802
        default: return nil
        }
    }
}

/// Fast binary-to-string decoder that interprets Postgres wire format directly
/// without creating ByteBuffer or PostgresCell objects. Used for spool decode.
enum DirectBinaryDecoder {
    nonisolated static func format(_ data: Data.SubSequence, oid: UInt32) -> String? {
        guard !data.isEmpty else { return "" }
        switch oid {
        // Boolean (OID 16)
        case 16:
            return data.first == 1 ? "true" : "false"
        // Int2 / Smallint (OID 21)
        case 21:
            guard data.count >= 2 else { return textFallback(data) }
            let value = Int16(bigEndian: data.withUnsafeBytes { $0.loadUnaligned(as: Int16.self) })
            return String(value)
        // Int4 / Integer (OID 23), OID type (26)
        case 23, 26:
            guard data.count >= 4 else { return textFallback(data) }
            let value = Int32(bigEndian: data.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) })
            return String(value)
        // Int8 / Bigint (OID 20)
        case 20:
            guard data.count >= 8 else { return textFallback(data) }
            let value = Int64(bigEndian: data.withUnsafeBytes { $0.loadUnaligned(as: Int64.self) })
            return String(value)
        // Float4 (OID 700)
        case 700:
            guard data.count >= 4 else { return textFallback(data) }
            let bits = UInt32(bigEndian: data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
            let value = Float(bitPattern: bits)
            return String(value)
        // Float8 (OID 701)
        case 701:
            guard data.count >= 8 else { return textFallback(data) }
            let bits = UInt64(bigEndian: data.withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) })
            let value = Double(bitPattern: bits)
            return String(value)
        // Text, Varchar, Name, Char, JSON, JSONB header, XML, etc.
        case 18, 19, 25, 114, 142, 143, 1042, 1043, 3802:
            if oid == 3802, data.count > 1 {
                // JSONB: skip version byte (0x01)
                let jsonSlice = data.dropFirst()
                return String(data: Data(jsonSlice), encoding: .utf8) ?? textFallback(data)
            }
            return String(data: Data(data), encoding: .utf8) ?? textFallback(data)
        // UUID (OID 2950) — 16 bytes
        case 2950:
            guard data.count >= 16 else { return textFallback(data) }
            return data.withUnsafeBytes { ptr in
                let b = ptr.bindMemory(to: UInt8.self)
                return String(format: "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
                    b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                    b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15])
            }
        // Date (OID 1082) — Int32 days since 2000-01-01
        case 1082:
            guard data.count >= 4 else { return textFallback(data) }
            let days = Int32(bigEndian: data.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) })
            return formatPostgresDate(days: Int(days))
        // Timestamp (OID 1114) — Int64 microseconds since 2000-01-01
        case 1114:
            guard data.count >= 8 else { return textFallback(data) }
            let microseconds = Int64(bigEndian: data.withUnsafeBytes { $0.loadUnaligned(as: Int64.self) })
            return formatPostgresTimestamp(microseconds: microseconds, withTimeZone: false)
        // Timestamptz (OID 1184)
        case 1184:
            guard data.count >= 8 else { return textFallback(data) }
            let microseconds = Int64(bigEndian: data.withUnsafeBytes { $0.loadUnaligned(as: Int64.self) })
            return formatPostgresTimestamp(microseconds: microseconds, withTimeZone: true)
        // Time (OID 1083) — Int64 microseconds since midnight
        case 1083:
            guard data.count >= 8 else { return textFallback(data) }
            let us = Int64(bigEndian: data.withUnsafeBytes { $0.loadUnaligned(as: Int64.self) })
            let totalSeconds = us / 1_000_000
            let h = totalSeconds / 3600
            let m = (totalSeconds % 3600) / 60
            let s = totalSeconds % 60
            let frac = us % 1_000_000
            if frac == 0 { return String(format: "%02d:%02d:%02d", h, m, s) }
            return String(format: "%02d:%02d:%02d.%06d", h, m, s, frac)
        // Numeric (OID 1700) — complex BCD format, fall back to PostgresPayloadFormatter
        case 1700:
            return nil // Caller should fall back to slow path
        // Bytea (OID 17)
        case 17:
            return "\\x" + data.map { String(format: "%02x", $0) }.joined()
        // Default: try UTF-8 text
        default:
            return String(data: Data(data), encoding: .utf8) ?? textFallback(data)
        }
    }

    private nonisolated static func textFallback(_ data: Data.SubSequence) -> String {
        data.map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    /// Postgres epoch: 2000-01-01 00:00:00 UTC
    private static let postgresEpoch: TimeInterval = 946_684_800 // Unix timestamp of 2000-01-01

    private nonisolated static func formatPostgresDate(days: Int) -> String {
        let timestamp = postgresEpoch + Double(days) * 86400
        let date = Date(timeIntervalSince1970: timestamp)
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: date)
        return String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
    }

    private nonisolated static func formatPostgresTimestamp(microseconds: Int64, withTimeZone: Bool) -> String {
        let seconds = Double(microseconds) / 1_000_000.0
        let timestamp = postgresEpoch + seconds
        let date = Date(timeIntervalSince1970: timestamp)
        let calendar = Calendar(identifier: .gregorian)
        let tz = withTimeZone ? TimeZone.current : TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents(in: tz, from: date)
        let frac = microseconds % 1_000_000
        let base = String(format: "%04d-%02d-%02d %02d:%02d:%02d",
            components.year!, components.month!, components.day!,
            components.hour!, components.minute!, components.second!)
        if frac == 0 { return base }
        return base + String(format: ".%06d", abs(frac))
    }
}

struct PostgresPayloadFormatter: Sendable {
    private let allocator = ByteBufferAllocator()
    private let formatter = PostgresCellFormatter()

    nonisolated func stringValue(for payload: ResultCellPayload, columnIndex: Int) -> String? {
        let dataType = PostgresDataType(rawValue: payload.dataTypeOID) ?? .text
        let postgresFormat = PostgresFormat(rawValue: Int16(payload.format.rawValue)) ?? .text

        var buffer: ByteBuffer?
        if let data = payload.bytes {
            var byteBuffer = allocator.buffer(capacity: data.count)
            byteBuffer.writeBytes(data)
            buffer = byteBuffer
        }

        let cell = PostgresCell(
            bytes: buffer,
            dataType: dataType,
            format: postgresFormat,
            columnName: "",
            columnIndex: columnIndex
        )
        return formatter.stringValue(for: cell)
    }
}

actor ResultRowFormattingCoordinator {
    struct DeferredBatch: Sendable {
        let generation: Int
        let range: Range<Int>
        let rows: [ResultRowPayload]
        let totalRowCount: Int
        let metrics: QueryStreamMetrics?
        let treatAsPreview: Bool
        let columns: [ColumnInfo]
        let token: Int
    }

    struct FormattedBatch: Sendable {
        let range: Range<Int>
        let rows: [[String?]]
        let totalRowCount: Int
        let metrics: QueryStreamMetrics?
        let treatAsPreview: Bool
        let columns: [ColumnInfo]
        let token: Int
    }

    typealias Delivery = @MainActor @Sendable (FormattedBatch) -> Void

    private let formatter: PostgresPayloadFormatter
    private let deliver: Delivery
    private var queue: [DeferredBatch] = []
    private var isProcessing = false
    private var generation: Int = 0
    private var currentTask: Task<Void, Never>?

    init(formatter: PostgresPayloadFormatter, deliver: @escaping Delivery) {
        self.formatter = formatter
        self.deliver = deliver
    }

    func reset() {
        generation &+= 1
        queue.removeAll(keepingCapacity: false)
        isProcessing = false
        currentTask?.cancel()
        currentTask = nil
    }

    func enqueue(
        range: Range<Int>,
        rows: [ResultRowPayload],
        totalRowCount: Int,
        metrics: QueryStreamMetrics?,
        treatAsPreview: Bool,
        columns: [ColumnInfo],
        token: Int
    ) {
        guard !rows.isEmpty else { return }
        let batch = DeferredBatch(
            generation: generation,
            range: range,
            rows: rows,
            totalRowCount: totalRowCount,
            metrics: metrics,
            treatAsPreview: treatAsPreview,
            columns: columns,
            token: token
        )
        queue.append(batch)
        processNextIfNeeded()
    }

    func prioritize(range target: Range<Int>, token: Int) {
        guard queue.count > 1 else { return }
        queue.sort { lhs, rhs in
            let leftDistance = lhs.token == token ? distance(lhs.range, to: target) : Int.max
            let rightDistance = rhs.token == token ? distance(rhs.range, to: target) : Int.max
            if leftDistance == rightDistance {
                return lhs.range.lowerBound < rhs.range.lowerBound
            }
            return leftDistance < rightDistance
        }
        processNextIfNeeded()
    }

    private func processNextIfNeeded() {
        guard !isProcessing else { return }
        guard let batch = queue.first else { return }
        queue.removeFirst()
        isProcessing = true
        let formatter = self.formatter
        currentTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }

            var formattedRows: [[String?]] = []
            formattedRows.reserveCapacity(batch.rows.count)

            for row in batch.rows {
                if Task.isCancelled {
                    await self.handleCancellation(for: batch)
                    return
                }

                var formattedRow: [String?] = []
                formattedRow.reserveCapacity(row.cells.count)

                for (columnIndex, cell) in row.cells.enumerated() {
                    if Task.isCancelled {
                        await self.handleCancellation(for: batch)
                        return
                    }
                    formattedRow.append(formatter.stringValue(for: cell, columnIndex: columnIndex))
                }

                formattedRows.append(formattedRow)
            }

            if Task.isCancelled {
                await self.handleCancellation(for: batch)
                return
            }

            await self.finish(batch: batch, formattedRows: formattedRows)
        }
    }

    private func finish(batch: DeferredBatch, formattedRows: [[String?]]) async {
        currentTask = nil
        defer {
            isProcessing = false
            processNextIfNeeded()
        }

        guard batch.generation == generation else { return }

        let formattedBatch = FormattedBatch(
            range: batch.range,
            rows: formattedRows,
            totalRowCount: batch.totalRowCount,
            metrics: batch.metrics,
            treatAsPreview: batch.treatAsPreview,
            columns: batch.columns,
            token: batch.token
        )
        await deliver(formattedBatch)
    }

    private func handleCancellation(for batch: DeferredBatch) async {
        currentTask = nil
        isProcessing = false
        if batch.generation == generation && !queue.contains(where: { $0.range == batch.range }) {
            queue.insert(batch, at: 0)
        }
        processNextIfNeeded()
    }

    private func distance(_ candidate: Range<Int>, to target: Range<Int>) -> Int {
        if candidate.overlaps(target) { return 0 }
        if candidate.upperBound <= target.lowerBound {
            return target.lowerBound - candidate.upperBound
        }
        if candidate.lowerBound >= target.upperBound {
            return candidate.lowerBound - target.upperBound
        }
        return 0
    }
}
