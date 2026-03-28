import Foundation

enum QueryResultTextFormatter {
    private static let nullToken = "NULL"

    static func formatTable(resultSet: QueryResultSet) -> String {
        guard !resultSet.columns.isEmpty else {
            return resultSet.rows.isEmpty ? "No columns returned." : formatRowOnlyData(resultSet.rows)
        }

        let headers = resultSet.columns.map(\.name)
        let widths = columnWidths(headers: headers, rows: resultSet.rows)

        var lines: [String] = []
        lines.append(formatAlignedRow(headers, widths: widths))
        lines.append(formatSeparator(widths: widths))

        if resultSet.rows.isEmpty {
            lines.append("(0 rows)")
            return lines.joined(separator: "\n")
        }

        for row in resultSet.rows {
            let cells = paddedRowValues(row, columnCount: headers.count)
            lines.append(formatAlignedRow(cells, widths: widths))
        }

        let rowCount = resultSet.totalRowCount ?? resultSet.rows.count
        let rowLabel = rowCount == 1 ? "row" : "rows"
        lines.append("(\(rowCount) \(rowLabel))")
        return lines.joined(separator: "\n")
    }

    static func formatVertical(resultSet: QueryResultSet) -> String {
        guard !resultSet.columns.isEmpty else {
            return resultSet.rows.isEmpty ? "No columns returned." : formatRowOnlyData(resultSet.rows)
        }

        guard !resultSet.rows.isEmpty else {
            return "(0 rows)"
        }

        let headers = resultSet.columns.map(\.name)
        let labelWidth = headers.map(\.count).max() ?? 0
        var lines: [String] = []

        for (index, row) in resultSet.rows.enumerated() {
            lines.append(String(repeating: "*", count: 24) + " \(index + 1). row " + String(repeating: "*", count: 24))
            for columnIndex in headers.indices {
                let name = headers[columnIndex].padding(toLength: labelWidth, withPad: " ", startingAt: 0)
                let value = columnIndex < row.count ? renderValue(row[columnIndex]) : nullToken
                lines.append("\(name): \(value)")
            }
        }

        let rowCount = resultSet.totalRowCount ?? resultSet.rows.count
        let rowLabel = rowCount == 1 ? "row" : "rows"
        lines.append("(\(rowCount) \(rowLabel))")
        return lines.joined(separator: "\n")
    }

    private static func formatRowOnlyData(_ rows: [[String?]]) -> String {
        guard !rows.isEmpty else { return "(0 rows)" }
        return rows.map { row in
            row.map(renderValue).joined(separator: " | ")
        }.joined(separator: "\n")
    }

    private static func columnWidths(headers: [String], rows: [[String?]]) -> [Int] {
        var widths = headers.map(\.count)
        for row in rows {
            for index in headers.indices {
                let rendered = index < row.count ? renderValue(row[index]) : nullToken
                widths[index] = max(widths[index], rendered.count)
            }
        }
        return widths
    }

    private static func paddedRowValues(_ row: [String?], columnCount: Int) -> [String] {
        (0..<columnCount).map { index in
            if index < row.count {
                return renderValue(row[index])
            }
            return nullToken
        }
    }

    private static func formatAlignedRow(_ values: [String], widths: [Int]) -> String {
        values.enumerated().map { index, value in
            value.padding(toLength: widths[index], withPad: " ", startingAt: 0)
        }.joined(separator: " | ")
    }

    private static func formatSeparator(widths: [Int]) -> String {
        widths.map { String(repeating: "-", count: $0) }.joined(separator: "-+-")
    }

    private static func renderValue(_ value: String?) -> String {
        guard let value else { return nullToken }
        return value.replacingOccurrences(of: "\n", with: "\\n")
    }
}
