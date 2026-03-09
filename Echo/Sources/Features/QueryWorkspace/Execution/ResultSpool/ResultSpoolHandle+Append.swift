import Foundation

extension ResultSpoolHandle {
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
#if DEBUG
        let appendStart = CFAbsoluteTimeGetCurrent()
        debugLog("append start rows=\(rows.count) encoded=\(encodedRows.count) rowRange=\(String(describing: rowRange))")
#endif

        let startRow: Int
        if let range = rowRange {
            startRow = range.lowerBound
            if range.upperBound > metadata.totalRowCount {
#if DEBUG
                debugLog("append: updating totalRowCount from \(metadata.totalRowCount) to \(range.upperBound) (rowRange provided)")
#endif
                metadata.totalRowCount = range.upperBound
            }
        } else {
            startRow = metadata.totalRowCount
        }

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

        let chunkStartOffset = fileOffset
        var buffer = Data()
        buffer.reserveCapacity(payloads.reduce(0) { $0 + bytesForPayload($1) + 1 })

        for payload in payloads {
            let rowData = payload.data
            buffer.append(rowData)
            buffer.append(Self.newlineByte)
            rowLengths.append(UInt32(clamping: rowData.count))
            metadata.cumulativeBytes &+= UInt64(rowData.count + 1)
            metadata.updatedAt = Date()
            emitTransientStatsIfAppropriate()
        }

        writeHandle.write(buffer)
        let bytesWritten = UInt64(buffer.count)
        fileOffset &+= bytesWritten

        let chunkRecord = ChunkRecord(
            startRow: startRow,
            rowCount: payloads.count,
            offset: chunkStartOffset,
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
#if DEBUG
        let duration = CFAbsoluteTimeGetCurrent() - appendStart
        debugLog("append finished batchCount=\(payloads.count) totalRowCount=\(metadata.totalRowCount) bytes=\(bytesWritten) duration=\(String(format: "%.3f", duration))")
#endif
    }

    func bytesForPayload(_ payload: ResultBinaryRow) -> Int {
        switch payload.storage {
        case .data(let data):
            return data.count
        case .raw(let raw):
            return raw.totalLength
        }
    }

    func markFinished(commandTag: String?, metrics: QueryStreamMetrics?) throws {
        metadata.commandTag = commandTag
        metadata.isFinished = true
        metadata.latestMetrics = metrics
        metadata.updatedAt = Date()
        persistMetadata()
        persistStats(lastBatch: 0, metrics: metrics, isFinished: true)
        try writeHandle?.synchronize()
#if DEBUG
        debugLog("markFinished commandTag=\(String(describing: commandTag)) totalRowCount=\(metadata.totalRowCount)")
#endif
    }

    func writeHeader(columns: [ColumnInfo], using handle: FileHandle) throws {
        guard !headerWritten else {
            throw ResultSpoolError.headerAlreadyWritten
        }
        metadata.columns = columns
        metadata.rowEncoding = "binary_v1"
        let payload = HeaderPayload(columns: columns, createdAt: metadata.createdAt, rowEncoding: "binary_v1")
        let encoder = makeJSONEncoder()
        let headerData = try encoder.encode(payload)
        handle.write(headerData)
        handle.write(Data([Self.newlineByte]))
        headerLength = UInt64(headerData.count + 1)
        fileOffset += headerLength
        metadata.cumulativeBytes += headerLength
        totalBytesWritten += headerLength
        headerWritten = true
        persistMetadata()
        persistStats(lastBatch: 0, metrics: nil, isFinished: false)
    }

    func persistMetadata() {
        let snapshot = metadata
        let metaURL = directory.appendingPathComponent("meta.json")
        Task.detached(priority: .utility) { [weak self, snapshot] in
            guard let self else { return }
            do {
                let data = try await MainActor.run { () -> Data in
                    let encoder = self.makeJSONEncoder()
                    return try encoder.encode(snapshot)
                }
                try data.write(to: metaURL, options: .atomic)
            } catch {
                print("ResultSpoolHandle: Failed to persist metadata \(error)")
            }
        }
    }

    func appendInMemoryRows(_ rows: [[String?]]) {
        guard configuration.inMemoryRowLimit > 0 else { return }
        let capacityRemaining = configuration.inMemoryRowLimit - inMemoryRows.count
        guard capacityRemaining > 0 else { return }
        let slice = rows.prefix(capacityRemaining)
        inMemoryRows.append(contentsOf: slice)
    }
}
