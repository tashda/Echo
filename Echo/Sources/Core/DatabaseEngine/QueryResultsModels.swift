import Foundation
import NIOCore

public struct QueryResultSet: Sendable {
    public var columns: [ColumnInfo]
    public var rows: [[String?]]
    public var totalRowCount: Int?
    public var commandTag: String?
    public var additionalResults: [QueryResultSet]
    public var dataClassification: DataClassification?

    public nonisolated init(columns: [ColumnInfo], rows: [[String?]] = [], totalRowCount: Int? = nil, commandTag: String? = nil, additionalResults: [QueryResultSet] = [], dataClassification: DataClassification? = nil) {
        self.columns = columns
        self.rows = rows
        self.totalRowCount = totalRowCount ?? rows.count
        self.commandTag = commandTag
        self.additionalResults = additionalResults
        self.dataClassification = dataClassification
    }

    public nonisolated init(columns: [String], rows: [[String?]]) {
        self.columns = columns.map { ColumnInfo(name: $0, dataType: "text") }
        self.rows = rows
        self.totalRowCount = rows.count
        self.commandTag = nil
        self.additionalResults = []
        self.dataClassification = nil
    }

    public nonisolated var allResultSets: [QueryResultSet] {
        [self] + additionalResults
    }

    public nonisolated var combinedRowCount: Int {
        let primary = totalRowCount ?? rows.count
        return additionalResults.reduce(primary) { $0 + ($1.totalRowCount ?? $1.rows.count) }
    }
}

public struct ColumnInfo: Sendable, Identifiable, Codable, Hashable {
    public nonisolated var id: String { name }
    public let name: String
    public let dataType: String
    public let isPrimaryKey: Bool
    public let isNullable: Bool
    public let maxLength: Int?
    public var foreignKey: ForeignKeyReference?
    public let comment: String?

    public nonisolated init(
        name: String,
        dataType: String,
        isPrimaryKey: Bool = false,
        isNullable: Bool = true,
        maxLength: Int? = nil,
        foreignKey: ForeignKeyReference? = nil,
        comment: String? = nil
    ) {
        self.name = name; self.dataType = dataType; self.isPrimaryKey = isPrimaryKey; self.isNullable = isNullable; self.maxLength = maxLength; self.foreignKey = foreignKey; self.comment = comment
    }

    public struct ForeignKeyReference: Sendable, Codable, Hashable {
        public let constraintName: String
        public let referencedSchema: String
        public let referencedTable: String
        public let referencedColumn: String

        public nonisolated init(constraintName: String, referencedSchema: String, referencedTable: String, referencedColumn: String) {
            self.constraintName = constraintName; self.referencedSchema = referencedSchema; self.referencedTable = referencedTable; self.referencedColumn = referencedColumn
        }
    }
}

public struct QueryStreamMetrics: Sendable, Codable {
    public let batchRowCount: Int
    public let loopElapsed: TimeInterval
    public let decodeDuration: TimeInterval
    public let totalElapsed: TimeInterval
    public let cumulativeRowCount: Int
    public let fetchRequestRowCount: Int?
    public let fetchRowCount: Int?
    public let fetchDuration: TimeInterval?
    public let fetchWait: TimeInterval?

    public nonisolated init(batchRowCount: Int, loopElapsed: TimeInterval, decodeDuration: TimeInterval, totalElapsed: TimeInterval, cumulativeRowCount: Int, fetchRequestRowCount: Int? = nil, fetchRowCount: Int? = nil, fetchDuration: TimeInterval? = nil, fetchWait: TimeInterval? = nil) {
        self.batchRowCount = batchRowCount; self.loopElapsed = loopElapsed; self.decodeDuration = decodeDuration; self.totalElapsed = totalElapsed; self.cumulativeRowCount = cumulativeRowCount; self.fetchRequestRowCount = fetchRequestRowCount; self.fetchRowCount = fetchRowCount; self.fetchDuration = fetchDuration; self.fetchWait = fetchWait
    }

    public nonisolated var networkWaitEstimate: TimeInterval {
        if let fetchWait { return fetchWait }
        return max(loopElapsed - decodeDuration, 0)
    }
}

public struct ResultBinaryRow: Sendable {
    public enum Storage: Sendable {
        case data(Data)
        case raw(Raw)
    }

    public struct Raw: @unchecked Sendable {
        public let buffers: [ByteBuffer?]
        public let lengths: [Int]
        public let totalLength: Int
        public init(buffers: [ByteBuffer?], lengths: [Int], totalLength: Int) { self.buffers = buffers; self.lengths = lengths; self.totalLength = totalLength }
    }

    public let storage: Storage
    public nonisolated init(data: Data) { self.storage = .data(data) }
    internal nonisolated init(raw: Raw) { self.storage = .raw(raw) }

    public nonisolated var data: Data {
        switch storage {
        case .data(let data): return data
        case .raw(let raw):
            var result = Data(); result.reserveCapacity(raw.totalLength)
            var flagNull: UInt8 = 0x00; var flagValue: UInt8 = 0x01
            for (index, length) in raw.lengths.enumerated() {
                if length < 0 { result.append(&flagNull, count: 1); continue }
                result.append(&flagValue, count: 1)
                var le = UInt32(length).littleEndian
                withUnsafeBytes(of: &le) { result.append($0.bindMemory(to: UInt8.self)) }
                if length > 0, let buffer = raw.buffers[index] { result.append(contentsOf: buffer.readableBytesView) }
            }
            return result
        }
    }
}

public struct ResultCellPayload: Sendable {
    public enum Format: UInt8, Sendable { case text = 0, binary = 1 }
    public let dataTypeOID: UInt32
    public let format: Format
    public let bytes: Data?
    public nonisolated init(dataTypeOID: UInt32, format: Format, bytes: Data?) { self.dataTypeOID = dataTypeOID; self.format = format; self.bytes = bytes }
}

public struct ResultRowPayload: Sendable {
    public let cells: [ResultCellPayload]
    public nonisolated init(cells: [ResultCellPayload]) { self.cells = cells }
}

public struct QueryStreamUpdate: Sendable {
    public let columns: [ColumnInfo]
    public let appendedRows: [[String?]]
    public let encodedRows: [ResultBinaryRow]
    public let rawRows: [ResultRowPayload]
    public let totalRowCount: Int
    public let metrics: QueryStreamMetrics?
    public let rowRange: Range<Int>?

    public nonisolated init(columns: [ColumnInfo], appendedRows: [[String?]], encodedRows: [ResultBinaryRow] = [], rawRows: [ResultRowPayload] = [], totalRowCount: Int, metrics: QueryStreamMetrics? = nil, rowRange: Range<Int>? = nil) {
        self.columns = columns; self.appendedRows = appendedRows; self.encodedRows = encodedRows; self.rawRows = rawRows; self.totalRowCount = totalRowCount; self.metrics = metrics; self.rowRange = rowRange
    }
}

public typealias QueryProgressHandler = @Sendable (QueryStreamUpdate) -> Void
