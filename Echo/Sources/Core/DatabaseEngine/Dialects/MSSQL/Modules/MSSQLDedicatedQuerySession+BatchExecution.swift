import Foundation
import SQLServerKit

extension MSSQLDedicatedQuerySession {
    func executeBatches(
        _ batches: [String],
        progressHandler: BatchProgressHandler?
    ) async throws -> [BatchResult] {
        let connection = try await readyConnection()
        let batchCount = batches.count
        var results: [BatchResult] = []
        results.reserveCapacity(batchCount)

        let stream = connection.streamBatches(batches)
        var currentColumns: [ColumnInfo] = []
        var currentRows: [[String?]] = []
        var currentResultSets: [QueryResultSet] = []
        var currentMessages: [ServerMessage] = []
        var resultSetIndex = -1

        do {
            for try await event in stream {
                switch event {
                case .batchStarted(let index):
                    currentColumns = []
                    currentRows = []
                    currentResultSets = []
                    currentMessages = []
                    resultSetIndex = -1
                    progressHandler?(BatchProgressUpdate(
                        batchIndex: index,
                        batchCount: batchCount,
                        event: .started
                    ))

                case .batchEvent(_, let streamEvent):
                    switch streamEvent {
                    case .metadata(let columnDescriptions):
                        // Save previous result set if we're starting a new one within the same batch
                        if resultSetIndex >= 0 && !currentColumns.isEmpty {
                            currentResultSets.append(QueryResultSet(
                                columns: currentColumns,
                                rows: currentRows,
                                totalRowCount: currentRows.count
                            ))
                        }
                        resultSetIndex += 1
                        currentColumns = columnDescriptions.map { column in
                            ColumnInfo(
                                name: column.name,
                                dataType: column.typeName,
                                isPrimaryKey: false,
                                isNullable: (column.flags & 0x01) != 0,
                                maxLength: column.length > 0 ? column.length : nil
                            )
                        }
                        currentRows = []

                    case .row(let row):
                        currentRows.append(row.toStringArray())

                    case .message(let message):
                        let kind: ServerMessage.Kind = message.kind == .error ? .error : .info
                        currentMessages.append(ServerMessage(
                            kind: kind,
                            number: message.number,
                            message: message.message,
                            state: message.state,
                            severity: message.severity,
                            lineNumber: message.lineNumber
                        ))

                    case .done:
                        break
                    }

                case .batchCompleted(let index):
                    // Flush final result set
                    if !currentColumns.isEmpty {
                        currentResultSets.append(QueryResultSet(
                            columns: currentColumns,
                            rows: currentRows,
                            totalRowCount: currentRows.count
                        ))
                    }
                    results.append(BatchResult(
                        batchIndex: index,
                        resultSets: currentResultSets,
                        error: nil,
                        messages: currentMessages
                    ))
                    progressHandler?(BatchProgressUpdate(
                        batchIndex: index,
                        batchCount: batchCount,
                        event: .completed
                    ))

                case .batchFailed(let index, let error, let messages):
                    // Flush any partial result set
                    if !currentColumns.isEmpty {
                        currentResultSets.append(QueryResultSet(
                            columns: currentColumns,
                            rows: currentRows,
                            totalRowCount: currentRows.count
                        ))
                    }
                    var allMessages = currentMessages
                    allMessages.append(contentsOf: messages.map { msg in
                        ServerMessage(
                            kind: msg.kind == .error ? .error : .info,
                            number: msg.number,
                            message: msg.message,
                            state: msg.state,
                            severity: msg.severity,
                            lineNumber: msg.lineNumber
                        )
                    })
                    results.append(BatchResult(
                        batchIndex: index,
                        resultSets: currentResultSets,
                        error: error.localizedDescription,
                        messages: allMessages
                    ))
                    progressHandler?(BatchProgressUpdate(
                        batchIndex: index,
                        batchCount: batchCount,
                        event: .failed(error.localizedDescription)
                    ))
                }
            }
        } catch is CancellationError {
            throw CancellationError()
        }

        return results
    }
}
