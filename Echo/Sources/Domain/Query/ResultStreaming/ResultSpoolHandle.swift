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
    private var rowRecords: [RowRecord] = []
    private var inMemoryRows: [[String?]] = []
    private var statContinuations: [UUID: AsyncStream<ResultSpoolStats>.Continuation] = [:]
    private var totalBytesWritten: UInt64 = 0
    private var headerLength: UInt64 = 0
    private var transientDispatchTask: Task<Void, Never>?
    private var lastTransientEmission: UInt64 = 0
    private let transientDispatchInterval: UInt64 = 8_000_000 // 8 ms trailing flush
    private let transientImmediateInterval: UInt64 = 1_000_000  // 1 ms (~1 kHz)
    private var pendingStats: ResultSpoolStats?
    private var statsFlushTask: Task<Void, Never>?
    private var lastStatsWriteTimestamp: UInt64 = 0
    private let statsFlushInterval: UInt64 = 12_000_000

    private struct RowRecord: Sendable {
        let offset: UInt64
        let length: UInt64
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
        statsFlushTask?.cancel()
        statsFlushTask = nil
        flushPendingStats()
        try? writeHandle?.close()
        try? readHandle?.close()
        statContinuations.values.forEach { $0.finish() }
    }

    func close() {
        transientDispatchTask?.cancel()
        transientDispatchTask = nil
        statsFlushTask?.cancel()
        statsFlushTask = nil
        flushPendingStats()
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

    func append(columns: [ColumnInfo], rows: [[String?]], encodedRows: [ResultBinaryRow], metrics: QueryStreamMetrics?) throws {
        guard let writeHandle else {
            throw ResultSpoolError.fileClosed
        }
        guard !rows.isEmpty || !encodedRows.isEmpty else { return }
        if !headerWritten {
            try writeHeader(columns: columns, using: writeHandle)
        }

        var bytesWritten: UInt64 = 0
        var newRecords: [RowRecord] = []
        let appendCount = max(rows.count, encodedRows.count)
        newRecords.reserveCapacity(appendCount)
        var buffer = Data()
        buffer.reserveCapacity(max(appendCount, 1) * 64)
        var currentOffset = fileOffset

        let payloads: [ResultBinaryRow]
        if !encodedRows.isEmpty {
            payloads = encodedRows
        } else {
            payloads = rows.map { ResultBinaryRowCodec.encode(row: $0) }
        }

        for payload in payloads {
            let data = payload.data
            let recordLength = UInt64(data.count)
            let rowBytes = recordLength + UInt64(Self.newlineData.count)

            buffer.append(data)
            buffer.append(Self.newlineData)

            bytesWritten += rowBytes
            newRecords.append(RowRecord(offset: currentOffset, length: recordLength))
            currentOffset += rowBytes

            metadata.totalRowCount += 1
            metadata.cumulativeBytes += rowBytes
            metadata.updatedAt = Date()

            emitTransientStatsIfAppropriate()
        }

        if !buffer.isEmpty {
            writeHandle.write(buffer)
            fileOffset = currentOffset
        }

        rowRecords.append(contentsOf: newRecords)
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

        if offset < inMemoryRows.count {
            results.append(contentsOf: inMemoryRows[offset..<min(endIndex, inMemoryRows.count)])
        }

        guard offset < rowRecords.count else {
            return results
        }

        let startIndex = max(offset, inMemoryRows.count)
        let readHandle = try resolvedReadHandle()

        for index in startIndex..<endIndex {
            guard index < rowRecords.count else { break }
            let record = rowRecords[index]
            try readHandle.seek(toOffset: record.offset)
            var data = try readHandle.read(upToCount: Int(record.length)) ?? Data()
            if data.count < record.length {
                let remaining = Int(record.length) - data.count
                if remaining > 0 {
                    let trailing = try readHandle.read(upToCount: remaining) ?? Data()
                    data.append(trailing)
                }
            }
            let decodedRow = decodeRowData(data)
            results.append(decodedRow)
        }

        return results
    }

    func dropInMemoryRowsBeyond(limit: Int) {
        guard limit < inMemoryRows.count else { return }
        inMemoryRows.removeSubrange(limit..<inMemoryRows.count)
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
        let metaURL = directory.appendingPathComponent("meta.json")
        let encoder = makeJSONEncoder()
        do {
            let data = try encoder.encode(metadata)
            try data.write(to: metaURL, options: .atomic)
        } catch {
            print("ResultSpoolHandle: Failed to persist metadata \(error)")
        }
    }

    private func persistStats(lastBatch: Int, metrics: QueryStreamMetrics?, isFinished: Bool) {
        let stats = currentStats(lastBatch: lastBatch, metrics: metrics, isFinished: isFinished)
        pendingStats = stats
        statContinuations.values.forEach { $0.yield(stats) }
        lastTransientEmission = DispatchTime.now().uptimeNanoseconds

        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = now &- lastStatsWriteTimestamp
        if isFinished || elapsed >= statsFlushInterval {
            flushPendingStats()
        } else if statsFlushTask == nil {
            let delay = max(statsFlushInterval - elapsed, 1)
            statsFlushTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: delay)
                await self?.flushPendingStats()
            }
        }
    }

    private func flushPendingStats() {
        statsFlushTask?.cancel()
        statsFlushTask = nil
        guard let stats = pendingStats else { return }
        pendingStats = nil
        writeStats(stats)
        lastStatsWriteTimestamp = DispatchTime.now().uptimeNanoseconds
    }

    private func writeStats(_ stats: ResultSpoolStats) {
        let statsURL = directory.appendingPathComponent("stats.json")
        let encoder = makeJSONEncoder()
        do {
            let data = try encoder.encode(stats)
            try data.write(to: statsURL, options: .atomic)
        } catch {
            print("ResultSpoolHandle: Failed to persist stats \(error)")
        }
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
