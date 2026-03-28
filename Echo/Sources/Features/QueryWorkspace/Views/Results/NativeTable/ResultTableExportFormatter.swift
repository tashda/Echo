#if os(macOS)
import Foundation

enum ResultTableExportFormatter {

    static func format(_ format: ResultExportFormat, headers: [String], rows: [[String?]], tableName: String? = nil, databaseType: DatabaseType? = nil) -> String {
        switch format {
        case .tsv: return formatTSV(headers: headers, rows: rows, includeHeaders: true)
        case .csv: return formatCSV(headers: headers, rows: rows)
        case .json: return formatJSON(headers: headers, rows: rows)
        case .html: return formatHTML(headers: headers, rows: rows)
        case .xml: return formatXML(headers: headers, rows: rows)
        case .sqlInsert: return formatSQLInsert(tableName: tableName ?? "table_name", headers: headers, rows: rows, databaseType: databaseType)
        case .markdown: return formatMarkdown(headers: headers, rows: rows)
        case .xlsx: return formatCSV(headers: headers, rows: rows) // Fallback — binary export uses XLSXExportWriter directly
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

    static func formatHTML(headers: [String], rows: [[String?]]) -> String {
        var lines: [String] = [
            "<!DOCTYPE html>",
            "<html>",
            "<head>",
            "<meta charset=\"utf-8\">",
            "<title>Query Results</title>",
            "<style>table{border-collapse:collapse;font-family:-apple-system,BlinkMacSystemFont,sans-serif;font-size:13px}th,td{border:1px solid #c7c7cc;padding:6px 8px;text-align:left;vertical-align:top}th{background:#f5f5f7}</style>",
            "</head>",
            "<body>",
            "<table>",
            "<thead>",
            "<tr>"
        ]
        lines.append(headers.map { "<th>\(xmlEscape($0))</th>" }.joined())
        lines += [
            "</tr>",
            "</thead>",
            "<tbody>"
        ]
        for row in rows {
            lines.append("<tr>")
            for index in headers.indices {
                let value = index < row.count ? (row[index] ?? "") : ""
                lines.append("<td>\(xmlEscape(value))</td>")
            }
            lines.append("</tr>")
        }
        lines += [
            "</tbody>",
            "</table>",
            "</body>",
            "</html>"
        ]
        return lines.joined(separator: "\n")
    }

    static func formatXML(headers: [String], rows: [[String?]]) -> String {
        var lines = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>", "<result-set>"]
        for row in rows {
            lines.append("  <row>")
            for index in headers.indices {
                let header = xmlElementName(headers[index], fallbackIndex: index)
                let value = index < row.count ? row[index] : nil
                if let value {
                    lines.append("    <\(header)>\(xmlEscape(value))</\(header)>")
                } else {
                    lines.append("    <\(header) nil=\"true\"/>")
                }
            }
            lines.append("  </row>")
        }
        lines.append("</result-set>")
        return lines.joined(separator: "\n")
    }

    static func formatSQLInsert(tableName: String, headers: [String], rows: [[String?]], databaseType: DatabaseType? = nil) -> String {
        guard !rows.isEmpty else { return "" }
        let quotedColumns = headers.map { quoteIdentifier($0, databaseType: databaseType) }.joined(separator: ", ")
        let quotedTable = quoteIdentifier(tableName, databaseType: databaseType)
        var statements: [String] = []
        for row in rows {
            let values = row.map { sqlLiteral($0) }.joined(separator: ", ")
            statements.append("INSERT INTO \(quotedTable) (\(quotedColumns)) VALUES (\(values));")
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

    private static func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func xmlElementName(_ header: String, fallbackIndex: Int) -> String {
        let trimmed = header.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitized = trimmed.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "_" || scalar == "-" {
                return Character(scalar)
            }
            return "_"
        }
        let joined = String(sanitized)
        let collapsed = joined.replacingOccurrences(of: "__+", with: "_", options: .regularExpression)
        let base = collapsed.isEmpty ? "column_\(fallbackIndex + 1)" : collapsed
        if let first = base.first, first.isNumber || first == "-" {
            return "column_\(fallbackIndex + 1)_\(base)"
        }
        return base
    }

    private static func quoteIdentifier(_ identifier: String, databaseType: DatabaseType?) -> String {
        switch databaseType {
        case .mysql:
            return "`\(identifier.replacingOccurrences(of: "`", with: "``"))`"
        case .microsoftSQL:
            return "[\(identifier.replacingOccurrences(of: "]", with: "]]"))]"
        case .postgresql, .sqlite, nil:
            return "\"\(identifier.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
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
