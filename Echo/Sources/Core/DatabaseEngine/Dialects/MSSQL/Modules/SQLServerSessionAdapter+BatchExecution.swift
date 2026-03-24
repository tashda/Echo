import Foundation
import SQLServerKit

extension SQLServerSessionAdapter {

    func executeBatches(
        _ batches: [String],
        progressHandler: BatchProgressHandler?
    ) async throws -> [BatchResult] {
        let batchResult = try await client.executeBatches(batches)
        return batchResult.batchResults.map { single in
            let resultSets: [QueryResultSet]
            if let result = single.result, !result.rows.isEmpty {
                resultSets = [convertSQLServerRowsToEcho(result.rows)]
            } else {
                resultSets = []
            }
            let messages = single.result?.messages.map { msg in
                ServerMessage(
                    kind: msg.kind == .error ? .error : .info,
                    number: msg.number,
                    message: msg.message,
                    state: msg.state,
                    severity: msg.severity,
                    lineNumber: msg.lineNumber
                )
            } ?? []
            return BatchResult(
                batchIndex: single.batchIndex,
                resultSets: resultSets,
                error: single.error?.localizedDescription,
                messages: messages
            )
        }
    }
}
