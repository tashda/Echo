import EchoSense
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
            metadata: metadata,
            statement: category == "Connection" ? nil : messageStatement
        )
        messages.append(entry)
        lastMessageTimestamp = timestamp
    }

    /// A server message with what SSMS shows above it (round 22, EM1): number, level and state.
    func appendServerMessage(_ message: ServerMessage) {
        var metadata = message.metadata
        if message.number != 0 {
            metadata["messageNumber"] = "\(message.number)"
            metadata["level"] = "\(message.severity)"
            metadata["state"] = "\(message.state)"
        }
        if let serverName = message.serverName, !serverName.isEmpty {
            metadata["server"] = serverName
        }
        appendMessage(
            message: message.message,
            severity: message.kind == .error ? .error : .info,
            category: message.category ?? "Server Response",
            procedure: message.procedureName,
            line: message.lineNumber.flatMap { $0 > 0 ? Int($0) : nil },
            metadata: metadata
        )
    }

    /// J1 and LL1: puts the editor on a message's line, selecting the marked word when the message
    /// is the error the editor marks.
    func goToLine(of message: QueryExecutionMessage) {
        guard let line = message.line else { return }
        let editorLine = messageLineMapper?(line) ?? line
        if let mark = errorMark, mark.line == editorLine || message.procedure.map({ !$0.isEmpty }) == true && message.severity == .error {
            editorLineRequest = EditorLineRequest(line: mark.line, range: mark.range)
        } else {
            editorLineRequest = EditorLineRequest(line: editorLine)
        }
    }

    /// The Go to Error button (round 21 J1, owner's note): the marked word, or the reported line.
    func goToError() {
        if let mark = errorMark {
            editorLineRequest = EditorLineRequest(line: mark.line, range: mark.range)
        } else if let message = messages.last(where: { $0.severity == .error && $0.line != nil }) {
            goToLine(of: message)
        }
    }

    /// The editor line a failed run points at: the marked error's, or the line the message
    /// reports mapped from what was sent (plan N4).
    func failureLine(for message: String) -> Int? {
        if let mark = errorMark { return mark.line }
        guard let reported = QueryErrorLocation.line(in: message) else { return nil }
        return messageLineMapper?(reported) ?? reported
    }

    /// Show in Editor on a failure (round 41.3): the marked word, or the reported line.
    func showFailureInEditor(message: String) {
        if let mark = errorMark {
            editorLineRequest = EditorLineRequest(line: mark.line, range: mark.range)
        } else if let line = failureLine(for: message) {
            editorLineRequest = EditorLineRequest(line: line)
        }
    }
}
