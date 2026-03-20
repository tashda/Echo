#if os(macOS)
import Foundation

/// Generates minimal .xlsx files (Office Open XML SpreadsheetML) without third-party dependencies.
///
/// The .xlsx format is a ZIP archive containing XML files. For single-sheet data export,
/// only a handful of XML templates are needed.
nonisolated struct XLSXExportWriter {

    /// Writes an xlsx file containing a single sheet with the given headers and rows.
    @concurrent
    static func write(headers: [String], rows: [[String?]], to url: URL) async throws {
        let sharedStrings = buildSharedStrings(headers: headers, rows: rows)
        let stringIndex = Dictionary(uniqueKeysWithValues: sharedStrings.enumerated().map { ($1, $0) })

        let files: [(String, Data)] = [
            ("[Content_Types].xml", contentTypesXML()),
            ("_rels/.rels", relsXML()),
            ("xl/workbook.xml", workbookXML()),
            ("xl/_rels/workbook.xml.rels", workbookRelsXML()),
            ("xl/styles.xml", stylesXML()),
            ("xl/sharedStrings.xml", sharedStringsXML(sharedStrings)),
            ("xl/worksheets/sheet1.xml", sheetXML(headers: headers, rows: rows, stringIndex: stringIndex)),
        ]

        // Write to a temp directory, then zip
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        for (path, data) in files {
            let fileURL = tempDir.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL)
        }

        // Use ditto to create the zip (preserves structure, available on all macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", tempDir.path, url.path]

        // ditto with --keepParent includes the temp dir name — use zip instead
        let zipProcess = Process()
        zipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zipProcess.arguments = ["-r", "-q", url.path] + files.map(\.0)
        zipProcess.currentDirectoryURL = tempDir
        zipProcess.standardOutput = FileHandle.nullDevice
        zipProcess.standardError = FileHandle.nullDevice

        // Remove existing file if present
        try? FileManager.default.removeItem(at: url)

        try zipProcess.run()
        zipProcess.waitUntilExit()

        guard zipProcess.terminationStatus == 0 else {
            throw XLSXWriteError.zipFailed
        }
    }

    /// Returns the xlsx data in memory.
    @concurrent
    static func exportData(headers: [String], rows: [[String?]]) async throws -> Data {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("xlsx")
        defer { try? FileManager.default.removeItem(at: tempFile) }

        try await write(headers: headers, rows: rows, to: tempFile)
        return try Data(contentsOf: tempFile)
    }

    // MARK: - Shared Strings

    private static func buildSharedStrings(headers: [String], rows: [[String?]]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []

        func add(_ s: String) {
            if seen.insert(s).inserted {
                ordered.append(s)
            }
        }

        for h in headers { add(h) }
        for row in rows {
            for cell in row {
                if let cell, !cell.isEmpty, !isNumeric(cell) {
                    add(cell)
                }
            }
        }
        return ordered
    }

    private static func isNumeric(_ value: String) -> Bool {
        Double(value) != nil
    }

    // MARK: - XML Generation

    private static func contentTypesXML() -> Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
          <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
        </Types>
        """.utf8)
    }

    private static func relsXML() -> Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """.utf8)
    }

    private static func workbookXML() -> Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>
            <sheet name="Results" sheetId="1" r:id="rId1"/>
          </sheets>
        </workbook>
        """.utf8)
    }

    private static func workbookRelsXML() -> Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
          <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
        </Relationships>
        """.utf8)
    }

    private static func stylesXML() -> Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <fonts count="2">
            <font><sz val="11"/><name val="Calibri"/></font>
            <font><b/><sz val="11"/><name val="Calibri"/></font>
          </fonts>
          <fills count="2">
            <fill><patternFill patternType="none"/></fill>
            <fill><patternFill patternType="gray125"/></fill>
          </fills>
          <borders count="1">
            <border><left/><right/><top/><bottom/><diagonal/></border>
          </borders>
          <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
          <cellXfs count="2">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
            <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
          </cellXfs>
        </styleSheet>
        """.utf8)
    }

    private static func sharedStringsXML(_ strings: [String]) -> Data {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="\(strings.count)" uniqueCount="\(strings.count)">
        """
        for s in strings {
            xml += "<si><t>\(escapeXML(s))</t></si>"
        }
        xml += "</sst>"
        return Data(xml.utf8)
    }

    private static func sheetXML(headers: [String], rows: [[String?]], stringIndex: [String: Int]) -> Data {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <sheetData>
        """

        // Header row (bold style = s="1")
        xml += "<row r=\"1\">"
        for (colIdx, header) in headers.enumerated() {
            let ref = cellRef(row: 0, col: colIdx)
            if let si = stringIndex[header] {
                xml += "<c r=\"\(ref)\" t=\"s\" s=\"1\"><v>\(si)</v></c>"
            } else {
                xml += "<c r=\"\(ref)\" s=\"1\"><v>\(escapeXML(header))</v></c>"
            }
        }
        xml += "</row>"

        // Data rows
        for (rowIdx, row) in rows.enumerated() {
            let xlRow = rowIdx + 2 // 1-based, header is row 1
            xml += "<row r=\"\(xlRow)\">"
            for (colIdx, cell) in row.enumerated() {
                let ref = cellRef(row: rowIdx + 1, col: colIdx)
                guard let value = cell, !value.isEmpty else { continue }

                if isNumeric(value) {
                    xml += "<c r=\"\(ref)\"><v>\(escapeXML(value))</v></c>"
                } else if let si = stringIndex[value] {
                    xml += "<c r=\"\(ref)\" t=\"s\"><v>\(si)</v></c>"
                } else {
                    xml += "<c r=\"\(ref)\" t=\"inlineStr\"><is><t>\(escapeXML(value))</t></is></c>"
                }
            }
            xml += "</row>"
        }

        xml += "</sheetData></worksheet>"
        return Data(xml.utf8)
    }

    // MARK: - Helpers

    private static func cellRef(row: Int, col: Int) -> String {
        var colStr = ""
        var c = col
        repeat {
            let letter = Character(UnicodeScalar(UInt8(65 + (c % 26))))
            colStr = String(letter) + colStr
            c = c / 26 - 1
        } while c >= 0
        return "\(colStr)\(row + 1)"
    }

    private static func escapeXML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

enum XLSXWriteError: LocalizedError {
    case zipFailed

    var errorDescription: String? {
        "Failed to create xlsx archive."
    }
}
#endif
