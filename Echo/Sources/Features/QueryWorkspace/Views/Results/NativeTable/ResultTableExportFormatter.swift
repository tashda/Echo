#if os(macOS)
import Foundation

enum ResultTableExportFormatter {

    static func format(_ format: ResultExportFormat, headers: [String], rows: [[String?]], tableName: String? = nil) -> String {
        switch format {
        case .tsv: return formatTSV(headers: headers, rows: rows, includeHeaders: true)
        case .csv: return formatCSV(headers: headers, rows: rows)
        case .json: return formatJSON(headers: headers, rows: rows)
        case .sqlInsert: return formatSQLInsert(tableName: tableName ?? "table_name", headers: headers, rows: rows)
        case .markdown: return formatMarkdown(headers: headers, rows: rows)
        }
    }

    static func formatTSV(headers: [String], rows: [[String?]], includeHeaders: Bool) -> String {
        var lines: [String] = []
        if includeHeaders {
            lines.append(headers.joined(separator: "\t"))
        }
        for row in rows {
            lines.append(row.map { $0 ?? "" }.joined(separator: "\t"))
        }
        return lines.joined(separator: "\n")
    }

    static func formatCSV(headers: [String], rows: [[String?]]) -> String {
        var lines: [String] = []
        lines.append(headers.map { csvEscape($0) }.joined(separator: ","))
        for row in rows {
            lines.append(row.map { csvEscape($0 ?? "") }.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func formatJSON(headers: [String], rows: [[String?]]) -> String {
        var objects: [[String: Any?]] = []
        for row in rows {
            var obj: [String: Any?] = [:]
            for (i, header) in headers.enumerated() {
                let value = i < row.count ? row[i] : nil
                obj[header] = value
            }
            objects.append(obj)
        }
        guard let data = try? JSONSerialization.data(withJSONObject: objects, options: [.prettyPrinted, .sortedKeys]) else {
            return "[]"
        }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static func formatSQLInsert(tableName: String, headers: [String], rows: [[String?]]) -> String {
        guard !rows.isEmpty else { return "" }
        let quotedColumns = headers.map { "\"\($0)\"" }.joined(separator: ", ")
        var statements: [String] = []
        for row in rows {
            let values = row.map { sqlLiteral($0) }.joined(separator: ", ")
            statements.append("INSERT INTO \"\(tableName)\" (\(quotedColumns)) VALUES (\(values));")
        }
        return statements.joined(separator: "\n")
    }

    static func formatMarkdown(headers: [String], rows: [[String?]]) -> String {
        var lines: [String] = []
        lines.append("| " + headers.joined(separator: " | ") + " |")
        lines.append("| " + headers.map { _ in "---" }.joined(separator: " | ") + " |")
        for row in rows {
            let cells = row.map { ($0 ?? "NULL").replacingOccurrences(of: "|", with: "\\|") }
            lines.append("| " + cells.joined(separator: " | ") + " |")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private static func sqlLiteral(_ value: String?) -> String {
        guard let value else { return "NULL" }
        if value.isEmpty { return "''" }
        if value.uppercased() == "NULL" { return "NULL" }
        if let _ = Int(value) { return value }
        if let _ = Double(value) { return value }
        let boolLower = value.lowercased()
        if boolLower == "true" || boolLower == "false" { return boolLower.uppercased() }
        return "'" + value.replacingOccurrences(of: "'", with: "''") + "'"
    }
}
#endif
