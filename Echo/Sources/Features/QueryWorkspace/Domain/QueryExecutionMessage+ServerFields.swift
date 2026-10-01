import Foundation

extension QueryExecutionMessage {
    /// Whether the server said it (a result's message, an error, PRINT output), as opposed to a
    /// line from Echo about a connection, a script or SQLCMD.
    var isFromServer: Bool {
        category == "Server Response" || metadata["messageNumber"] != nil
    }

    /// Everything the server sent with the message, as label and value, in a stable order: SQL
    /// Server's number, level, state, line, procedure and server, then any other fields the driver
    /// passed on (PostgreSQL's SQLSTATE, detail and hint), then the text itself.
    var serverFields: [(label: String, value: String)] {
        var fields: [(String, String)] = []
        if let number = metadata["messageNumber"] { fields.append(("Message number", number)) }
        if let level = metadata["level"] { fields.append(("Level", level)) }
        if let state = metadata["state"] { fields.append(("State", state)) }
        if let line { fields.append(("Line", "\(line)")) }
        if let procedure, !procedure.isEmpty { fields.append(("Procedure", procedure)) }
        if let server = metadata["server"], !server.isEmpty { fields.append(("Server", server)) }
        let shown: Set<String> = ["messageNumber", "level", "state", "server"]
        for key in metadata.keys.sorted() where !shown.contains(key) {
            if let value = metadata[key], !value.isEmpty { fields.append((key, value)) }
        }
        return fields
    }

    /// The message as the server sent it, for Copy: the fields, then the text.
    var serverCopyText: String {
        (serverFields.map { "\($0.label): \($0.value)" } + [message]).joined(separator: "\n")
    }
}
