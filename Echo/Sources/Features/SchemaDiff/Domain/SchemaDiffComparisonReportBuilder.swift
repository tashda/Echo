import Foundation

enum SchemaDiffComparisonReportFormat {
    case text
    case markdown
    case html

    var fileExtension: String {
        switch self {
        case .text: "txt"
        case .markdown: "md"
        case .html: "html"
        }
    }
}

enum SchemaDiffComparisonReportBuilder {
    static func build(
        sourceSchema: String,
        targetSchema: String,
        diffs: [SchemaDiffItem],
        format: SchemaDiffComparisonReportFormat
    ) -> String {
        let summary = summaryLines(diffs: diffs)
        switch format {
        case .text:
            return buildText(sourceSchema: sourceSchema, targetSchema: targetSchema, diffs: diffs, summary: summary)
        case .markdown:
            return buildMarkdown(sourceSchema: sourceSchema, targetSchema: targetSchema, diffs: diffs, summary: summary)
        case .html:
            return buildHTML(sourceSchema: sourceSchema, targetSchema: targetSchema, diffs: diffs, summary: summary)
        }
    }

    private static func buildText(
        sourceSchema: String,
        targetSchema: String,
        diffs: [SchemaDiffItem],
        summary: [String]
    ) -> String {
        let rows = diffs.map { item in
            let sourceState = item.sourceDDL.nilIfEmpty == nil ? "missing" : "present"
            let targetState = item.targetDDL.nilIfEmpty == nil ? "missing" : "present"
            return "- [\(item.status.rawValue)] \(item.objectType) \(item.objectName) | source: \(sourceState) | target: \(targetState)"
        }

        return ([
            "Schema Comparison Report",
            "Source: \(sourceSchema)",
            "Target: \(targetSchema)",
            "Generated: \(timestamp())",
            "",
            "Summary",
        ] + summary + [
            "",
            "Differences",
        ] + rows).joined(separator: "\n") + "\n"
    }

    private static func buildMarkdown(
        sourceSchema: String,
        targetSchema: String,
        diffs: [SchemaDiffItem],
        summary: [String]
    ) -> String {
        let tableRows = diffs.map { item in
            "| \(escapeMarkdown(item.status.rawValue)) | \(escapeMarkdown(item.objectType)) | \(escapeMarkdown(item.objectName)) | \(item.sourceDDL.nilIfEmpty == nil ? "No" : "Yes") | \(item.targetDDL.nilIfEmpty == nil ? "No" : "Yes") |"
        }

        return ([
            "# Schema Comparison Report",
            "",
            "- Source: `\(sourceSchema)`",
            "- Target: `\(targetSchema)`",
            "- Generated: `\(timestamp())`",
            "",
            "## Summary",
        ] + summary.map { "- \($0)" } + [
            "",
            "## Differences",
            "",
            "| Status | Type | Name | Source DDL | Target DDL |",
            "| --- | --- | --- | --- | --- |",
        ] + tableRows).joined(separator: "\n") + "\n"
    }

    private static func buildHTML(
        sourceSchema: String,
        targetSchema: String,
        diffs: [SchemaDiffItem],
        summary: [String]
    ) -> String {
        let summaryItems = summary.map { "<li>\(escapeHTML($0))</li>" }.joined()
        let rows = diffs.map { item in
            """
            <tr>
              <td>\(escapeHTML(item.status.rawValue))</td>
              <td>\(escapeHTML(item.objectType))</td>
              <td>\(escapeHTML(item.objectName))</td>
              <td>\(item.sourceDDL.nilIfEmpty == nil ? "No" : "Yes")</td>
              <td>\(item.targetDDL.nilIfEmpty == nil ? "No" : "Yes")</td>
            </tr>
            """
        }.joined(separator: "\n")

        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <title>Schema Comparison Report</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 32px; color: #1f2937; }
            table { border-collapse: collapse; width: 100%; margin-top: 16px; }
            th, td { border: 1px solid #d1d5db; padding: 8px 10px; text-align: left; vertical-align: top; }
            th { background: #f3f4f6; }
            h1, h2 { margin-bottom: 8px; }
            ul { margin-top: 8px; }
          </style>
        </head>
        <body>
          <h1>Schema Comparison Report</h1>
          <p><strong>Source:</strong> \(escapeHTML(sourceSchema))<br><strong>Target:</strong> \(escapeHTML(targetSchema))<br><strong>Generated:</strong> \(escapeHTML(timestamp()))</p>
          <h2>Summary</h2>
          <ul>\(summaryItems)</ul>
          <h2>Differences</h2>
          <table>
            <thead>
              <tr>
                <th>Status</th>
                <th>Type</th>
                <th>Name</th>
                <th>Source DDL</th>
                <th>Target DDL</th>
              </tr>
            </thead>
            <tbody>
            \(rows)
            </tbody>
          </table>
        </body>
        </html>
        """
    }

    private static func summaryLines(diffs: [SchemaDiffItem]) -> [String] {
        let grouped = Dictionary(grouping: diffs, by: \.status)
        return SchemaDiffStatus.allCases.map { status in
            "\(status.rawValue): \(grouped[status, default: []].count)"
        }
    }

    private static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }

    private static func escapeMarkdown(_ value: String) -> String {
        value.replacingOccurrences(of: "|", with: "\\|")
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

private extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        guard let self else { return nil }
        return self.isEmpty ? nil : self
    }
}
