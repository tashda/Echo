import AppKit
import SQLServerKit
import UniformTypeIdentifiers

extension ProfilerView {
    func exportTrace() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json, .commaSeparatedText]
        panel.nameFieldStringValue = "profiler_trace.json"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let events = viewModel.events
        let isCSV = url.pathExtension.lowercased() == "csv"

        do {
            if isCSV {
                var csv = "timestamp,event,database,login,duration_ms,cpu,reads,writes,spid,sql_text\n"
                let formatter = ISO8601DateFormatter()
                for event in events {
                    let timestamp = event.timestamp.map { formatter.string(from: $0) } ?? ""
                    let sql = (event.textData ?? "").replacingOccurrences(of: "\"", with: "\"\"")
                    csv += "\"\(timestamp)\",\"\(event.eventName)\",\"\(event.databaseName ?? "")\",\"\(event.loginName ?? "")\",\(event.duration ?? 0),\(event.cpu ?? 0),\(event.reads ?? 0),\(event.writes ?? 0),\(event.spid ?? 0),\"\(sql)\"\n"
                }
                try csv.write(to: url, atomically: true, encoding: .utf8)
            } else {
                let jsonEvents: [[String: Any]] = events.map { event in
                    var dictionary: [String: Any] = ["event_name": event.eventName]
                    if let timestamp = event.timestamp { dictionary["timestamp"] = ISO8601DateFormatter().string(from: timestamp) }
                    if let text = event.textData { dictionary["sql_text"] = text }
                    if let database = event.databaseName { dictionary["database"] = database }
                    if let login = event.loginName { dictionary["login"] = login }
                    if let duration = event.duration { dictionary["duration_ms"] = duration }
                    if let cpu = event.cpu { dictionary["cpu"] = cpu }
                    if let reads = event.reads { dictionary["reads"] = reads }
                    if let writes = event.writes { dictionary["writes"] = writes }
                    if let sessionID = event.spid { dictionary["spid"] = sessionID }
                    return dictionary
                }
                let data = try JSONSerialization.data(withJSONObject: jsonEvents, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: url)
            }
        } catch { }
    }
}
