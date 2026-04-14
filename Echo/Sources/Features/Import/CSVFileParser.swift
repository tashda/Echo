import Foundation

/// Delimiter options for CSV/TSV/PSV file parsing.
enum CSVDelimiter: String, CaseIterable, Identifiable, Sendable {
    case comma = ","
    case tab = "\t"
    case pipe = "|"
    case semicolon = ";"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .comma: return "Comma (,)"
        case .tab: return "Tab"
        case .pipe: return "Pipe (|)"
        case .semicolon: return "Semicolon (;)"
        }
    }
}

/// Result of parsing a delimited text file.
struct CSVParseResult: Sendable {
    let headers: [String]
    let rows: [[String]]
    let totalRowCount: Int
}

/// Parses CSV, TSV, and other delimited text files.
///
/// Handles quoted fields with double-quote escaping per RFC 4180.
/// Limits loaded rows to `previewLimit` for performance when previewing large files.
nonisolated struct CSVFileParser {

    /// Reads and parses a delimited file at the given URL.
    ///
    /// - Parameters:
    ///   - url: File URL to read.
    ///   - delimiter: Field delimiter character.
    ///   - previewLimit: Maximum data rows to return (headers are always returned). Pass `nil` to load all rows.
    /// - Returns: Parsed headers and rows.
    @concurrent
    static func parse(
        url: URL,
        delimiter: CSVDelimiter,
        previewLimit: Int? = nil
    ) async throws -> CSVParseResult {
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) else {
            throw CSVParseError.invalidEncoding
        }
        return parseContent(content, delimiter: delimiter, previewLimit: previewLimit)
    }

    /// Parses all rows from a file URL without preview limits.
    @concurrent
    static func parseAll(
        url: URL,
        delimiter: CSVDelimiter
    ) async throws -> CSVParseResult {
        try await parse(url: url, delimiter: delimiter, previewLimit: nil)
    }

    // MARK: - Internal

    private static func parseContent(
        _ content: String,
        delimiter: CSVDelimiter,
        previewLimit: Int?
    ) -> CSVParseResult {
        let delimChar = delimiter.rawValue.first ?? ","
        var rows: [[String]] = []
        var currentField = ""
        var currentRow: [String] = []
        var inQuotes = false
        let chars = Array(content.unicodeScalars)
        var i = chars.startIndex

        while i < chars.endIndex {
            let c = chars[i]

            if inQuotes {
                if c == "\"" {
                    let next = chars.index(after: i)
                    if next < chars.endIndex, chars[next] == "\"" {
                        // Escaped quote
                        currentField.append("\"")
                        i = chars.index(after: next)
                    } else {
                        // End of quoted field
                        inQuotes = false
                        i = chars.index(after: i)
                    }
                } else {
                    currentField.unicodeScalars.append(c)
                    i = chars.index(after: i)
                }
            } else {
                if c == "\"" {
                    inQuotes = true
                    i = chars.index(after: i)
                } else if c == Character(String(delimChar)).unicodeScalars.first! {
                    currentRow.append(currentField)
                    currentField = ""
                    i = chars.index(after: i)
                } else if c == "\r" {
                    currentRow.append(currentField)
                    currentField = ""
                    rows.append(currentRow)
                    currentRow = []
                    i = chars.index(after: i)
                    // Skip \n after \r
                    if i < chars.endIndex, chars[i] == "\n" {
                        i = chars.index(after: i)
                    }
                } else if c == "\n" {
                    currentRow.append(currentField)
                    currentField = ""
                    rows.append(currentRow)
                    currentRow = []
                    i = chars.index(after: i)
                } else {
                    currentField.unicodeScalars.append(c)
                    i = chars.index(after: i)
                }
            }
        }

        // Last field/row
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        // Remove empty trailing rows
        while let last = rows.last, last.allSatisfy({ $0.isEmpty }) {
            rows.removeLast()
        }

        guard let headers = rows.first else {
            return CSVParseResult(headers: [], rows: [], totalRowCount: 0)
        }

        let dataRows = Array(rows.dropFirst())
        let totalCount = dataRows.count

        let limitedRows: [[String]]
        if let limit = previewLimit {
            limitedRows = Array(dataRows.prefix(limit))
        } else {
            limitedRows = dataRows
        }

        return CSVParseResult(headers: headers, rows: limitedRows, totalRowCount: totalCount)
    }
}

enum CSVParseError: LocalizedError {
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return "The file could not be read as UTF-8 text."
        }
    }
}
