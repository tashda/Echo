import Foundation

extension ResultSpoolHandle {
    func loadRows(offset: Int, limit: Int) throws -> [[String?]] {
        guard offset >= 0, limit > 0 else {
            throw ResultSpoolError.invalidRange
        }
        guard offset < metadata.totalRowCount else {
            return []
        }

        let endIndex = min(metadata.totalRowCount, offset + limit)
        var results: [[String?]] = []
        results.reserveCapacity(endIndex - offset)

        // Serve from in-memory cache when possible
        if endIndex <= inMemoryRows.count {
            results.append(contentsOf: inMemoryRows[offset..<endIndex])
            return results
        }

        var currentIndex = offset
        if currentIndex < inMemoryRows.count {
            let upper = min(endIndex, inMemoryRows.count)
            if upper > currentIndex {
                results.append(contentsOf: inMemoryRows[currentIndex..<upper])
                currentIndex = upper
            }
        }

        guard currentIndex < endIndex else {
            return results
        }

        guard !chunkRecords.isEmpty else {
            return results
        }

        let readHandle = try resolvedReadHandle()

        while currentIndex < endIndex {
            guard let chunkIndex = chunkIndex(forRow: currentIndex) else {
                break
            }
            let chunk = chunkRecords[chunkIndex]
            let localStart = currentIndex - chunk.startRow
            if localStart >= chunk.rowCount {
                currentIndex = chunk.startRow + chunk.rowCount
                continue
            }
            let localLimit = min(chunk.rowCount - localStart, endIndex - currentIndex)
            let decoded = try readRows(
                from: chunk,
                localStart: localStart,
                count: localLimit,
                using: readHandle
            )
            if decoded.isEmpty {
                break
            }
            results.append(contentsOf: decoded)
            currentIndex += decoded.count
        }

        return results
    }

    func dropInMemoryRowsBeyond(limit: Int) {
        guard limit < inMemoryRows.count else { return }
        inMemoryRows.removeSubrange(limit..<inMemoryRows.count)
    }

    func chunkIndex(forRow row: Int) -> Int? {
        guard !chunkRecords.isEmpty else { return nil }
        var lower = 0
        var upper = chunkRecords.count - 1

        while lower <= upper {
            let mid = (lower + upper) / 2
            let chunk = chunkRecords[mid]
            if row < chunk.startRow {
                if mid == 0 {
                    return nil
                }
                upper = mid - 1
            } else {
                let chunkEnd = chunk.startRow + chunk.rowCount
                if row < chunkEnd {
                    return mid
                }
                if mid == chunkRecords.count - 1 {
                    return nil
                }
                lower = mid + 1
            }
        }

        return nil
    }

    func readRows(
        from chunk: ChunkRecord,
        localStart: Int,
        count: Int,
        using handle: FileHandle
    ) throws -> [[String?]] {
        guard count > 0 else { return [] }
        guard localStart < chunk.rowCount else { return [] }

        let clampedCount = min(count, chunk.rowCount - localStart)
        guard clampedCount > 0 else { return [] }

        try handle.seek(toOffset: chunk.offset)
        var remaining = Int(chunk.byteLength)
        var data = Data()
        data.reserveCapacity(remaining)

        while remaining > 0 {
            let fetched = try handle.read(upToCount: min(remaining, 64 * 1024)) ?? Data()
            if fetched.isEmpty {
                break
            }
            data.append(fetched)
            remaining -= fetched.count
        }

        if data.isEmpty {
            return []
        }

        var rows: [[String?]] = []
        rows.reserveCapacity(clampedCount)

        var cursor = 0
        if localStart > 0 {
            for index in 0..<localStart {
                if index >= chunk.rowLengths.count { break }
                cursor &+= Int(chunk.rowLengths[index])
                cursor &+= 1
            }
        }

        for index in localStart..<(localStart + clampedCount) {
            guard index < chunk.rowLengths.count else { break }
            let length = Int(chunk.rowLengths[index])
            let upper = cursor + length
            if upper > data.count {
                break
            }
            let slice = data[cursor..<upper]
            let decodedRow = decodeRowData(Data(slice))
            rows.append(decodedRow)
            cursor = upper + 1
        }

        return rows
    }

    func resolvedReadHandle() throws -> FileHandle {
        if let handle = readHandle {
            return handle
        }
        let rowsURL = directory.appendingPathComponent("rows.bin")
        let handle = try FileHandle(forReadingFrom: rowsURL)
        readHandle = handle
        return handle
    }
}
