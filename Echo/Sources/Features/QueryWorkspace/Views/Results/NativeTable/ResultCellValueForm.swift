import Foundation

/// How a results cell draws values that are hard to read as sent (Echo Labs round 21, "Values in
/// the grid": VA4, VJ3, VB3, VN2, SC1). Only the drawing changes: copy, export and the inspector
/// keep the server's text. Work happens when a visible cell is configured, never while rows stream.
nonisolated enum ResultCellValueForm: Equatable, Sendable {
    /// Drawn as sent.
    case plain
    /// A PostgreSQL array: its element count, then the elements without braces or quotes.
    case postgresArray
    /// JSON objects and arrays as a summary, `{ 4 keys }` or `[ 12 items ]`.
    case json
    /// Hex binary (`\x…` from PostgreSQL, `0x…` from SQL Server and MySQL) as kind and size.
    case binary
    /// Numbers lined up on the decimal point.
    case decimal

    static func form(kind: ResultGridValueKind, dataType: String?) -> ResultCellValueForm {
        if let dataType, dataType.contains("[]"), PostgresSpoolColumns.oid(for: dataType) != nil { return .postgresArray }
        switch kind {
        case .json: return .json
        case .binary: return .binary
        case .numeric: return .decimal
        default: return .plain
        }
    }

    /// Fraction digits beyond this are not padded for, so one long float does not push a column apart.
    static let maxAlignedFractionDigits = 6

    /// The text a cell shows. `countLength` is the length of the leading element count (arrays),
    /// drawn in a secondary colour. `fractionDigits` is the column's widest fraction so far.
    static func shown(_ raw: String, form: ResultCellValueForm, fractionDigits: Int = 0) -> (text: String, countLength: Int) {
        switch form {
        case .plain:
            return (raw, 0)
        case .postgresArray:
            guard let array = postgresArray(raw) else { return (raw, 0) }
            let count = String(array.count)
            return (array.items.isEmpty ? count : "\(count)\u{2002}\(array.items)", count.utf16.count)
        case .json:
            return (jsonSummary(raw) ?? raw, 0)
        case .binary:
            return (binarySummary(raw) ?? raw, 0)
        case .decimal:
            return (decimalAligned(raw, fractionDigits: fractionDigits), 0)
        }
    }

    /// What Copy as Shown puts on the clipboard: the drawn text without alignment padding.
    static func copiedAsShown(_ raw: String?, kind: ResultGridValueKind, form: ResultCellValueForm) -> String? {
        guard let raw else { return nil }
        if kind == .boolean { return ResultCellPresentation.displayText(raw, kind: kind) }
        let text = shown(raw, form: form).text
        return form == .postgresArray ? text.replacingOccurrences(of: "\u{2002}", with: " ") : text
    }

    // MARK: - Arrays

    /// Top-level element count and the elements joined with ", ", for PostgreSQL array text such as
    /// `{new,"net 30",NULL}`, `{{1,2},{3,4}}` or `[0:1]={a,b}`. Nil if it is not array text.
    static func postgresArray(_ raw: String, itemsLimit: Int = 400) -> (count: Int, items: String)? {
        var text = Substring(raw)
        if text.first == "[", let equals = text.firstIndex(of: "=") { text = text[text.index(after: equals)...] }
        guard text.first == "{", text.last == "}" else { return nil }
        let body = text.dropFirst().dropLast()
        if body.isEmpty { return (0, "") }

        var count = 0
        var items = ""
        var current = ""
        var depth = 0
        var inQuotes = false
        var escaped = false
        func finish() {
            count += 1
            guard items.utf16.count < itemsLimit else { return }
            items += items.isEmpty ? current : ", " + current
            current = ""
        }
        for character in body {
            if inQuotes {
                if escaped {
                    current.append(character); escaped = false
                } else if character == "\\" {
                    escaped = true; if depth > 0 { current.append(character) }
                } else if character == "\"" {
                    inQuotes = false; if depth > 0 { current.append(character) }
                } else {
                    current.append(character)
                }
                continue
            }
            switch character {
            case "\"":
                inQuotes = true; if depth > 0 { current.append(character) }
            case "{":
                depth += 1; current.append(character)
            case "}":
                depth -= 1; current.append(character)
            case "," where depth == 0:
                finish(); current = ""
            default:
                current.append(character)
            }
        }
        finish()
        return (count, items)
    }

    // MARK: - JSON

    /// Documents larger than this are summarised by size instead of being scanned.
    static let jsonScanLimit = 4 * 1024 * 1024

    /// `{ 4 keys }`, `[ 12 items ]`, `{ }`; nil for scalars (strings, numbers, true, null) and non-JSON.
    static func jsonSummary(_ raw: String) -> String? {
        let bytes = raw.utf8
        guard let open = bytes.first(where: { !isJSONSpace($0) }), open == UInt8(ascii: "{") || open == UInt8(ascii: "[") else { return nil }
        let isObject = open == UInt8(ascii: "{")
        guard bytes.count <= jsonScanLimit else {
            return isObject ? "{ \(byteSize(bytes.count)) }" : "[ \(byteSize(bytes.count)) ]"
        }
        var depth = 0
        var inString = false
        var escaped = false
        var separators = 0
        var hasContent = false
        for byte in bytes {
            if inString {
                if escaped { escaped = false } else if byte == UInt8(ascii: "\\") { escaped = true } else if byte == UInt8(ascii: "\"") { inString = false }
                continue
            }
            switch byte {
            case UInt8(ascii: "\""):
                inString = true; if depth == 1 { hasContent = true }
            case UInt8(ascii: "{"), UInt8(ascii: "["):
                if depth == 1 { hasContent = true }
                depth += 1
            case UInt8(ascii: "}"), UInt8(ascii: "]"):
                depth -= 1
            case UInt8(ascii: ","):
                if depth == 1 { separators += 1 }
            default:
                if depth == 1, !isJSONSpace(byte) { hasContent = true }
            }
        }
        let count = hasContent ? separators + 1 : 0
        if isObject { return count == 0 ? "{ }" : "{ \(count) \(count == 1 ? "key" : "keys") }" }
        return count == 0 ? "[ ]" : "[ \(count) \(count == 1 ? "item" : "items") ]"
    }

    private static func isJSONSpace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09
    }

    // MARK: - Binary

    /// `PNG image · 12 KB`, `Binary · 20 bytes`, `Empty`; nil when the text is not hex binary.
    static func binarySummary(_ raw: String) -> String? {
        guard raw.hasPrefix("\\x") || raw.hasPrefix("0x") || raw.hasPrefix("0X") else { return nil }
        let hex = raw.utf8.dropFirst(2)
        guard hex.count % 2 == 0, hex.prefix(32).allSatisfy(isHexDigit) else { return nil }
        let byteCount = hex.count / 2
        if byteCount == 0 { return "Empty" }
        let head = String(decoding: hex.prefix(24), as: UTF8.self).uppercased()
        return "\(binaryKind(hexPrefix: head)) · \(byteSize(byteCount))"
    }

    private static func isHexDigit(_ byte: UInt8) -> Bool {
        (0x30...0x39).contains(byte) || (0x41...0x46).contains(byte) || (0x61...0x66).contains(byte)
    }

    /// The file kind from its first bytes (upper-case hex).
    static func binaryKind(hexPrefix head: String) -> String {
        if head.hasPrefix("89504E470D0A1A0A") { return "PNG image" }
        if head.hasPrefix("FFD8FF") { return "JPEG image" }
        if head.hasPrefix("47494638") { return "GIF image" }
        if head.hasPrefix("52494646"), head.dropFirst(16).hasPrefix("57454250") { return "WebP image" }
        if head.hasPrefix("49492A00") || head.hasPrefix("4D4D002A") { return "TIFF image" }
        if head.hasPrefix("25504446") { return "PDF" }
        if head.hasPrefix("504B0304") { return "ZIP archive" }
        if head.hasPrefix("1F8B") { return "Gzip data" }
        return "Binary"
    }

    /// `1 byte`, `20 bytes`, `12 KB`, `1.5 MB` (1024-based, as Finder shows file sizes in lists).
    static func byteSize(_ count: Int) -> String {
        if count < 1024 { return count == 1 ? "1 byte" : "\(count) bytes" }
        let units = ["KB", "MB", "GB", "TB"]
        var value = Double(count) / 1024
        var unit = 0
        while value >= 1024, unit < units.count - 1 { value /= 1024; unit += 1 }
        let number = value < 10 ? String(format: "%.1f", value) : String(Int(value.rounded()))
        return "\(number.hasSuffix(".0") ? String(number.dropLast(2)) : number) \(units[unit])"
    }

    // MARK: - Decimal alignment

    /// Digits after the decimal point, or 0 when there is none (integers, `NaN`, `1e+20`).
    static func fractionDigits(_ raw: String) -> Int {
        guard let dot = raw.utf8.lastIndex(of: UInt8(ascii: ".")) else { return 0 }
        let fraction = raw.utf8[raw.utf8.index(after: dot)...]
        guard fraction.allSatisfy({ (0x30...0x39).contains($0) }) else { return 0 }
        return fraction.count
    }

    /// Pads the fraction with figure spaces (and a punctuation space where an integer has no point),
    /// so that in a right-aligned column with tabular digits the decimal points line up.
    static func decimalAligned(_ raw: String, fractionDigits columnDigits: Int) -> String {
        let target = min(columnDigits, maxAlignedFractionDigits)
        guard target > 0 else { return raw }
        let hasPoint = raw.utf8.contains(UInt8(ascii: "."))
        let digits = fractionDigits(raw)
        if hasPoint {
            guard digits < target, digits > 0 || raw.hasSuffix(".") else { return raw }
            return raw + String(repeating: "\u{2007}", count: target - digits)
        }
        return raw + "\u{2008}" + String(repeating: "\u{2007}", count: target)
    }
}
