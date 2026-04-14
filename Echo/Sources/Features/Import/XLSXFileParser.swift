import Foundation

/// Parses Excel (.xlsx) files by reading the ZIP archive's XML contents.
///
/// Returns the same `CSVParseResult` as `CSVFileParser` for seamless integration
/// with the bulk import pipeline.
nonisolated struct XLSXFileParser {

    /// Reads and parses the first sheet of an xlsx file at the given URL.
    ///
    /// - Parameters:
    ///   - url: File URL to read.
    ///   - sheetIndex: Zero-based sheet index (default 0).
    ///   - previewLimit: Maximum data rows to return. Pass `nil` to load all rows.
    /// - Returns: Parsed headers and rows.
    @concurrent
    static func parse(
        url: URL,
        sheetIndex: Int = 0,
        previewLimit: Int? = nil
    ) async throws -> CSVParseResult {
        let archive = try ZIPReader(url: url)

        // Load shared strings table
        let sharedStrings: [String]
        if let sstData = try archive.readEntry("xl/sharedStrings.xml") {
            sharedStrings = parseSharedStrings(sstData)
        } else {
            sharedStrings = []
        }

        // Find the sheet file
        let sheetPath = "xl/worksheets/sheet\(sheetIndex + 1).xml"
        guard let sheetData = try archive.readEntry(sheetPath) else {
            throw XLSXParseError.sheetNotFound(sheetIndex)
        }

        let allRows = parseSheet(sheetData, sharedStrings: sharedStrings)

        guard let headers = allRows.first else {
            return CSVParseResult(headers: [], rows: [], totalRowCount: 0)
        }

        let dataRows = Array(allRows.dropFirst())
        let totalCount = dataRows.count

        let limitedRows: [[String]]
        if let limit = previewLimit {
            limitedRows = Array(dataRows.prefix(limit))
        } else {
            limitedRows = dataRows
        }

        return CSVParseResult(headers: headers, rows: limitedRows, totalRowCount: totalCount)
    }

    // MARK: - Shared Strings

    private static func parseSharedStrings(_ data: Data) -> [String] {
        guard let content = String(data: data, encoding: .utf8) else { return [] }

        var strings: [String] = []
        var searchRange = content.startIndex..<content.endIndex

        // Parse <si> elements — each contains one or more <t> tags
        while let siStart = content.range(of: "<si>", range: searchRange),
              let siEnd = content.range(of: "</si>", range: siStart.upperBound..<content.endIndex) {

            let siContent = String(content[siStart.upperBound..<siEnd.lowerBound])
            var combined = ""

            // Extract all <t> values within this <si>
            var tSearch = siContent.startIndex..<siContent.endIndex
            while let tOpen = siContent.range(of: "<t", range: tSearch) {
                // Skip to after the closing > of the <t> or <t ...> tag
                guard let tagClose = siContent.range(of: ">", range: tOpen.upperBound..<siContent.endIndex) else { break }
                guard let tClose = siContent.range(of: "</t>", range: tagClose.upperBound..<siContent.endIndex) else { break }
                combined += unescapeXML(String(siContent[tagClose.upperBound..<tClose.lowerBound]))
                tSearch = tClose.upperBound..<siContent.endIndex
            }

            strings.append(combined)
            searchRange = siEnd.upperBound..<content.endIndex
        }
        return strings
    }

    // MARK: - Sheet Parsing

    private static func parseSheet(_ data: Data, sharedStrings: [String]) -> [[String]] {
        guard let content = String(data: data, encoding: .utf8) else { return [] }

        var rows: [[String]] = []
        var searchRange = content.startIndex..<content.endIndex

        while let rowStart = content.range(of: "<row", range: searchRange) {
            // Find the end of this <row ...> ... </row>
            guard let rowEnd = content.range(of: "</row>", range: rowStart.upperBound..<content.endIndex) else { break }
            let rowContent = String(content[rowStart.upperBound..<rowEnd.lowerBound])

            let cells = parseCells(rowContent, sharedStrings: sharedStrings)
            rows.append(cells)
            searchRange = rowEnd.upperBound..<content.endIndex
        }
        return rows
    }

    private static func parseCells(_ rowXML: String, sharedStrings: [String]) -> [String] {
        var cells: [String] = []
        var searchRange = rowXML.startIndex..<rowXML.endIndex

        while let cStart = rowXML.range(of: "<c ", range: searchRange) {
            // Determine if self-closing or has content
            let remaining = cStart.upperBound..<rowXML.endIndex

            // Extract the opening tag only (up to first >) to avoid reading attributes from later cells
            let tagCloseIdx = rowXML[remaining].firstIndex(of: ">") ?? rowXML.endIndex
            let openingTag = String(rowXML[cStart.lowerBound...tagCloseIdx])
            let cellType = extractAttribute("t", from: openingTag)

            if let selfClose = rowXML.range(of: "/>", range: remaining),
               (rowXML.range(of: "</c>", range: remaining) == nil ||
                selfClose.lowerBound < rowXML.range(of: "</c>", range: remaining)!.lowerBound) {
                // Self-closing cell — empty value
                // But check for column gaps first
                let ref = extractAttribute("r", from: String(rowXML[cStart.lowerBound..<selfClose.upperBound]))
                fillGaps(&cells, upTo: ref)
                cells.append("")
                searchRange = selfClose.upperBound..<rowXML.endIndex
                continue
            }

            guard let cEnd = rowXML.range(of: "</c>", range: remaining) else { break }
            let cellContent = String(rowXML[cStart.upperBound..<cEnd.lowerBound])

            // Extract cell reference for gap detection
            let ref = extractAttribute("r", from: String(rowXML[cStart.lowerBound..<cEnd.upperBound]))
            fillGaps(&cells, upTo: ref)

            // Extract <v> value
            let value: String
            if let vStart = cellContent.range(of: "<v>"),
               let vEnd = cellContent.range(of: "</v>") {
                value = String(cellContent[vStart.upperBound..<vEnd.lowerBound])
            } else {
                value = ""
            }

            // Resolve based on type
            if cellType == "s", let idx = Int(value), idx < sharedStrings.count {
                cells.append(sharedStrings[idx])
            } else if cellType == "inlineStr" {
                // Inline string: extract <t> from <is><t>...</t></is>
                if let tStart = cellContent.range(of: "<t>") ?? cellContent.range(of: "<t "),
                   let tagEnd = cellContent.range(of: ">", range: tStart.upperBound..<cellContent.endIndex),
                   let tEnd = cellContent.range(of: "</t>", range: tagEnd.upperBound..<cellContent.endIndex) {
                    cells.append(unescapeXML(String(cellContent[tagEnd.upperBound..<tEnd.lowerBound])))
                } else {
                    cells.append("")
                }
            } else {
                cells.append(unescapeXML(value))
            }

            searchRange = cEnd.upperBound..<rowXML.endIndex
        }
        return cells
    }

    /// Fills empty cells for skipped columns (e.g., A1, C1 means B1 is empty).
    private static func fillGaps(_ cells: inout [String], upTo ref: String?) {
        guard let ref, let colIndex = columnIndex(from: ref) else { return }
        while cells.count < colIndex {
            cells.append("")
        }
    }

    /// Converts a cell reference like "C5" to a zero-based column index (2).
    private static func columnIndex(from ref: String) -> Int? {
        let letters = ref.prefix(while: { $0.isLetter })
        guard !letters.isEmpty else { return nil }
        var index = 0
        for char in letters.uppercased() {
            guard let val = char.asciiValue.map({ Int($0) - 64 }) else { return nil }
            index = index * 26 + val
        }
        return index - 1
    }

    private static func extractAttribute(_ name: String, from tag: String) -> String? {
        let patterns = ["\(name)=\"", "\(name)='"]
        for pattern in patterns {
            if let start = tag.range(of: pattern) {
                let quoteChar: Character = pattern.last == "\"" ? "\"" : "'"
                let valueStart = start.upperBound
                if let end = tag[valueStart...].firstIndex(of: quoteChar) {
                    return String(tag[valueStart..<end])
                }
            }
        }
        return nil
    }

    private static func unescapeXML(_ text: String) -> String {
        text.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
    }
}

// MARK: - ZIP Reader

/// Minimal ZIP reader for .xlsx files. Uses Foundation's decompression.
private struct ZIPReader {
    private let url: URL

    init(url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XLSXParseError.fileNotFound
        }
        self.url = url
    }

    func readEntry(_ path: String) throws -> Data? {
        // Use Process to call unzip for extraction — simple and reliable
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", "-qq", url.path, path, "-d", tempDir.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        let extractedFile = tempDir.appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: extractedFile.path) else { return nil }
        return try Data(contentsOf: extractedFile)
    }
}

// MARK: - Errors

enum XLSXParseError: LocalizedError {
    case fileNotFound
    case sheetNotFound(Int)
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "The xlsx file was not found."
        case .sheetNotFound(let index):
            return "Sheet \(index + 1) was not found in the workbook."
        case .invalidFormat:
            return "The file is not a valid xlsx file."
        }
    }
}
