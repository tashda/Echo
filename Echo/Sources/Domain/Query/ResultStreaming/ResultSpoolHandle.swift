import Foundation

actor ResultSpoolHandle {
    private static let newlineData = Data([0x0A])
    let id: UUID
    let directory: URL
    private(set) var metadata: ResultSpoolMetadata
    private let configuration: ResultSpoolConfiguration

    private var headerWritten = false
    private var writeHandle: FileHandle?
    private var readHandle: FileHandle?
    private var fileOffset: UInt64 = 0
    private var chunkRecords: [ChunkRecord] = []
    private var inMemoryRows: [[String?]] = []
    private var statContinuations: [UUID: AsyncStream<ResultSpoolStats>.Continuation] = [:]
    private var totalBytesWritten: UInt64 = 0
    private var headerLength: UInt64 = 0
    private var transientDispatchTask: Task<Void, Never>?
    private var lastTransientEmission: UInt64 = 0
    private let transientDispatchInterval: UInt64 = 20_000_000 // 20 ms trailing flush
    private let transientImmediateInterval: UInt64 = 5_000_000  // 5 ms (~200 Hz)

    private struct ChunkRecord: Sendable {
        let startRow: Int
        let rowCount: Int
        let offset: UInt64
        let byteLength: UInt64
        let rowLengths: ContiguousArray<UInt32>
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

    init(id: UUID, directory: URL, configuration: ResultSpoolConfiguration) throws {
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
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let rowsURL = directory.appendingPathComponent("rows.bin")
        FileManager.default.createFile(atPath: rowsURL.path, contents: nil)
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

    func close() {
        transientDispatchTask?.cancel()
        transientDispatchTask = nil
        try? writeHandle?.close()
        writeHandle = nil
        try? readHandle?.close()
        readHandle = nil
        statContinuations.values.forEach { $0.finish() }
        statContinuations.removeAll()
    }

    func statsStream() -> AsyncStream<ResultSpoolStats> {
        let identifier = UUID()
        return AsyncStream { continuation in
            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeContinuation(identifier)
                }
            }
            Task {
                await self.addContinuation(identifier, continuation)
            }
        }
    }

    private func addContinuation(_ id: UUID, _ continuation: AsyncStream<ResultSpoolStats>.Continuation) async {
        statContinuations[id] = continuation
        continuation.yield(currentStats(lastBatch: 0, metrics: nil, isFinished: metadata.isFinished))
    }

    private func removeContinuation(_ id: UUID) async {
        statContinuations.removeValue(forKey: id)
    }

    func append(
        columns: [ColumnInfo],
        rows: [[String?]],
        encodedRows: [ResultBinaryRow],
        rowRange: Range<Int>?,
        metrics: QueryStreamMetrics?
    ) throws {
        guard let writeHandle else {
            throw ResultSpoolError.fileClosed
        }
        guard !rows.isEmpty || !encodedRows.isEmpty else { return }
        if !headerWritten {
            try writeHeader(columns: columns, using: writeHandle)
        }

        let startRow: Int
        if let range = rowRange {
            startRow = range.lowerBound
            if range.upperBound > metadata.totalRowCount {
                metadata.totalRowCount = range.upperBound
            }
        } else {
            startRow = metadata.totalRowCount
        }

        var bytesWritten: UInt64 = 0
        let appendCount = max(rows.count, encodedRows.count)
        guard appendCount > 0 else { return }

        var rowLengths = ContiguousArray<UInt32>()
        rowLengths.reserveCapacity(appendCount)

        let payloads: [ResultBinaryRow]
        if !encodedRows.isEmpty {
            payloads = encodedRows
        } else {
            payloads = rows.map { ResultBinaryRowCodec.encode(row: $0) }
        }

        var buffer = Data()
        var estimatedCapacity = 0
        for payload in payloads {
            let rowBytes = payload.data.count + Self.newlineData.count
            if estimatedCapacity <= Int.max - rowBytes {
                estimatedCapacity += rowBytes
            } else {
                estimatedCapacity = Int.max
                break
            }
        }
        if estimatedCapacity > 0 {
            buffer.reserveCapacity(estimatedCapacity)
        }
        var currentOffset = fileOffset

        for payload in payloads {
            let data = payload.data
            let recordLength = UInt64(data.count)
            let rowBytes = recordLength + UInt64(Self.newlineData.count)

            buffer.append(data)
            buffer.append(Self.newlineData)

            bytesWritten += rowBytes
            rowLengths.append(UInt32(clamping: recordLength))
            currentOffset += rowBytes

            metadata.cumulativeBytes += rowBytes
            metadata.updatedAt = Date()

            emitTransientStatsIfAppropriate()
        }

        if !buffer.isEmpty {
            writeHandle.write(buffer)
            fileOffset = currentOffset
        }

        let chunkRecord = ChunkRecord(
            startRow: startRow,
            rowCount: payloads.count,
            offset: fileOffset - UInt64(bytesWritten),
            byteLength: bytesWritten,
            rowLengths: rowLengths
        )
        chunkRecords.append(chunkRecord)

        if rowRange == nil {
            metadata.totalRowCount += payloads.count
        }

        metadata.latestMetrics = metrics
        totalBytesWritten += bytesWritten
        appendInMemoryRows(rows)
        persistStats(lastBatch: payloads.count, metrics: metrics, isFinished: false)
    }

    func markFinished(commandTag: String?, metrics: QueryStreamMetrics?) throws {
        metadata.commandTag = commandTag
        metadata.isFinished = true
        metadata.latestMetrics = metrics
        metadata.updatedAt = Date()
        persistMetadata()
        persistStats(lastBatch: 0, metrics: metrics, isFinished: true)
        try writeHandle?.synchronize()
    }

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

    private func chunkIndex(forRow row: Int) -> Int? {
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

    private func readRows(
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
                cursor &+= Int(Self.newlineData.count)
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
            cursor = upper + Int(Self.newlineData.count)
        }

        return rows
    }

    private func appendInMemoryRows(_ rows: [[String?]]) {
        guard configuration.inMemoryRowLimit > 0 else { return }
        let capacityRemaining = configuration.inMemoryRowLimit - inMemoryRows.count
        guard capacityRemaining > 0 else { return }
        let slice = rows.prefix(capacityRemaining)
        inMemoryRows.append(contentsOf: slice)
    }

    private func decodeRowData(_ data: Data) -> [String?] {
        if metadata.rowEncoding == "binary_v1" {
            let binaryRow = ResultBinaryRow(data: data)
            var values = ResultBinaryRowCodec.decode(binaryRow, columnCount: metadata.columns.count)
            normalizeValues(&values)
            return values
        } else {
            return decodeLegacyJSONRow(from: data)
        }
    }

    private func decodeLegacyJSONRow(from data: Data) -> [String?] {
        let decoder = makeJSONDecoder()
        if let row = try? decoder.decode([String?].self, from: data) {
            return row
        }
        return []
    }

    private func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func normalizeValues(_ values: inout [String?]) {
        guard !values.isEmpty else { return }
        let columns = metadata.columns
        for index in 0..<min(values.count, columns.count) {
            guard let raw = values[index] else { continue }
            let type = columns[index].dataType.lowercased()
            if type.contains("bool") {
                let lower = raw.lowercased()
                if lower == "t" || lower == "true" {
                    values[index] = "true"
                } else if lower == "f" || lower == "false" {
                    values[index] = "false"
                }
            }
        }
    }

    private func writeHeader(columns: [ColumnInfo], using handle: FileHandle) throws {
        guard !headerWritten else {
            throw ResultSpoolError.headerAlreadyWritten
        }
        metadata.columns = columns
        metadata.rowEncoding = "binary_v1"
        let payload = HeaderPayload(columns: columns, createdAt: metadata.createdAt, rowEncoding: "binary_v1")
        let encoder = makeJSONEncoder()
        let headerData = try encoder.encode(payload)
        handle.write(headerData)
        handle.write(Self.newlineData)
        headerLength = UInt64(headerData.count + Self.newlineData.count)
        fileOffset += headerLength
        metadata.cumulativeBytes += headerLength
        totalBytesWritten += headerLength
        headerWritten = true
        persistMetadata()
        persistStats(lastBatch: 0, metrics: nil, isFinished: false)
    }

    private func resolvedReadHandle() throws -> FileHandle {
        if let handle = readHandle {
            return handle
        }
        let rowsURL = directory.appendingPathComponent("rows.bin")
        let handle = try FileHandle(forReadingFrom: rowsURL)
        readHandle = handle
        return handle
    }

    private func persistMetadata() {
        let snapshot = metadata
        let metaURL = directory.appendingPathComponent("meta.json")
        Task { @MainActor in
            let encoder = JSONEncoder()
            encoder.outputFormatting = []
            encoder.dateEncodingStrategy = .iso8601
            do {
                let data = try encoder.encode(snapshot)
                try data.write(to: metaURL, options: .atomic)
            } catch {
                print("ResultSpoolHandle: Failed to persist metadata \(error)")
            }
        }
    }

    private func persistStats(lastBatch: Int, metrics: QueryStreamMetrics?, isFinished: Bool) {
        let stats = currentStats(lastBatch: lastBatch, metrics: metrics, isFinished: isFinished)
        let statsURL = directory.appendingPathComponent("stats.json")
        Task { @MainActor in
            let encoder = JSONEncoder()
            encoder.outputFormatting = []
            encoder.dateEncodingStrategy = .iso8601
            do {
                let data = try encoder.encode(stats)
                try data.write(to: statsURL, options: .atomic)
            } catch {
                print("ResultSpoolHandle: Failed to persist stats \(error)")
            }
        }
        statContinuations.values.forEach { $0.yield(stats) }
        lastTransientEmission = DispatchTime.now().uptimeNanoseconds
    }

    private func emitTransientStatsIfAppropriate() {
        guard !statContinuations.isEmpty else { return }
        let now = DispatchTime.now().uptimeNanoseconds
        if now &- lastTransientEmission >= transientImmediateInterval {
            transientDispatchTask?.cancel()
            transientDispatchTask = nil
            lastTransientEmission = now
            let stats = currentStats(lastBatch: 1, metrics: nil, isFinished: metadata.isFinished)
            statContinuations.values.forEach { $0.yield(stats) }
        } else {
            scheduleTrailingStats()
        }
    }

    private func scheduleTrailingStats() {
        guard !statContinuations.isEmpty else { return }
        guard transientDispatchTask == nil else { return }
        transientDispatchTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.transientDispatchInterval)
            if Task.isCancelled { return }
            await self.emitScheduledStats()
        }
    }

    private func emitScheduledStats() async {
        transientDispatchTask = nil
        guard !statContinuations.isEmpty else { return }
        let stats = currentStats(lastBatch: 0, metrics: nil, isFinished: metadata.isFinished)
        statContinuations.values.forEach { $0.yield(stats) }
        lastTransientEmission = DispatchTime.now().uptimeNanoseconds
    }

    private func currentStats(lastBatch: Int, metrics: QueryStreamMetrics?, isFinished: Bool) -> ResultSpoolStats {
        ResultSpoolStats(
            spoolID: metadata.id,
            rowCount: metadata.totalRowCount,
            lastBatchCount: lastBatch,
            cumulativeBytes: metadata.cumulativeBytes,
            lastUpdated: metadata.updatedAt,
            metrics: metrics,
            isFinished: isFinished
        )
    }
}
