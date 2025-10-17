import Foundation

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
                        memcpy(baseAddress.advanced(by: offset), pointer.baseAddress!, 4)
                    }
                    offset &+= 4

                    raw.withUnsafeBytes { rawPointer in
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
        let data = binaryRow.data
        var result: [String?] = []
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
            let slice = data[index..<end]
            index = end

            if let string = String(data: slice, encoding: .utf8) {
                result.append(string)
            } else {
                result.append(String(decoding: slice, as: UTF8.self))
            }
        }

        if columnCount > result.count {
            result.append(contentsOf: repeatElement(nil, count: columnCount - result.count))
        }

        return result
    }
}
