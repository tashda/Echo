import Foundation

/// A simple utility to format a set of rows and columns into an ASCII table similar to psql.
enum ASCIIPlainTableFormatter {
    static func format(columns: [String], rows: [[String?]], nullDisplay: String = "") -> String {
        guard !columns.isEmpty else { return "" }
        
        // Calculate max width for each column
        var columnWidths = columns.map { $0.count }
        for row in rows {
            for (i, cell) in row.enumerated() {
                if i < columnWidths.count {
                    let cellText = cell ?? nullDisplay
                    columnWidths[i] = max(columnWidths[i], cellText.count)
                }
            }
        }
        
        var output = ""
        
        // Header
        for (i, col) in columns.enumerated() {
            let width = columnWidths[i]
            output += " " + col.padding(toLength: width, withPad: " ", startingAt: 0) + " "
            if i < columns.count - 1 {
                output += "|"
            }
        }
        output += "\n"
        
        // Separator
        for (i, width) in columnWidths.enumerated() {
            output += String(repeating: "-", count: width + 2)
            if i < columnWidths.count - 1 {
                output += "+"
            }
        }
        output += "\n"
        
        // Rows
        for row in rows {
            for (i, cell) in row.enumerated() {
                if i < columnWidths.count {
                    let width = columnWidths[i]
                    let cellText = cell ?? nullDisplay
                    output += " " + cellText.padding(toLength: width, withPad: " ", startingAt: 0) + " "
                    if i < columns.count - 1 {
                        output += "|"
                    }
                }
            }
            output += "\n"
        }
        
        // Footer
        let rowCount = rows.count
        output += "(\(rowCount) \(rowCount == 1 ? "row" : "rows"))\n"
        
        return output
    }
}
