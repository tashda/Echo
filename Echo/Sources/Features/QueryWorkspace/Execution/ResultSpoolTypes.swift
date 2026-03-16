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
                withUnsafeBytes(of: &length) { pointer in
                    guard let pointerBase = pointer.baseAddress else { return }
                    memcpy(baseAddress.advanced(by: offset), pointerBase, 4)
                }
                    offset &+= 4

                    raw.withUnsafeBytes { rawPointer in
                        guard let rawBase = rawPointer.baseAddress else { return }
                        memcpy(baseAddress.advanced(by: offset), rawBase, raw.count)
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
