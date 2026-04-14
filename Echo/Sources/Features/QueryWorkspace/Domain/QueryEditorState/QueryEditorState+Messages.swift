import Foundation

extension QueryEditorState {
    func appendMessage(
        message: String,
        severity: QueryExecutionMessage.Severity,
        category: String = "Query Execution",
        timestamp: Date = Date(),
        duration: TimeInterval? = nil,
        procedure: String? = nil,
        line: Int? = nil,
        metadata: [String: String] = [:]
    ) {
        let index = messages.count + 1
        let delta = lastMessageTimestamp.map { timestamp.timeIntervalSince($0) } ?? 0
        let entry = QueryExecutionMessage(
            index: index,
            category: category,
            message: message,
            timestamp: timestamp,
            severity: severity,
            delta: delta,
            duration: duration,
            procedure: procedure,
            line: line,
            metadata: metadata
        )
        messages.append(entry)
        lastMessageTimestamp = timestamp
    }
}
