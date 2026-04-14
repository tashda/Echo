import Foundation

/// Decodes raw TDS wire format bytes to display strings.
/// Used at display time when MSSQL rows are stored as `.raw(RawRow)` —
/// matching the Postgres approach of deferring string conversion.
nonisolated enum TDSBinaryDecoder {

    /// Returns true if the given TDS column type can be correctly decoded from raw
    /// bytes without additional metadata (scale, precision). Types like datetime2
    /// and decimal require scale info that isn't available at decode time.
    static func canDecodeRaw(_ dataType: String) -> Bool {
        switch dataType.lowercased() {
        case "int", "bigint", "smallint", "tinyint",
             "bit",
             "float", "real",
             "char", "varchar", "text",
             "nchar", "nvarchar", "ntext", "xml",
             "binary", "varbinary", "image",
             "uniqueidentifier":
            return true
        default:
            return false
        }
    }

    /// Returns true if `dataType` is a known TDS type name (MSSQL column).
    static func isTDSType(_ dataType: String) -> Bool {
        switch dataType.lowercased() {
        case "int", "bigint", "smallint", "tinyint",
             "bit",
             "float", "real",
             "decimal", "numeric", "money", "smallmoney",
             "datetime", "datetime2", "date", "time", "datetimeoffset", "smalldatetime",
             "char", "varchar", "text",
             "nchar", "nvarchar", "ntext", "xml",
             "binary", "varbinary", "image",
             "uniqueidentifier",
             "sql_variant", "hierarchyid":
            return true
        default:
            return false
        }
    }

    /// Decodes raw TDS bytes for a column to a display string.
    static func format(_ data: Data.SubSequence, dataType: String) -> String? {
        guard !data.isEmpty else { return "" }

        switch dataType.lowercased() {
        // Integer types — little-endian
        case "tinyint":
            return String(data.first ?? 0)
        case "smallint":
            guard data.count >= 2 else { return utf8Fallback(data) }
            let value = data.withUnsafeBytes { $0.loadUnaligned(as: Int16.self) }
            return String(Int16(littleEndian: value))
        case "int":
            guard data.count >= 4 else { return utf8Fallback(data) }
            let value = data.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
            return String(Int32(littleEndian: value))
        case "bigint":
            guard data.count >= 8 else { return utf8Fallback(data) }
            let value = data.withUnsafeBytes { $0.loadUnaligned(as: Int64.self) }
            return String(Int64(littleEndian: value))

        // Bit
        case "bit":
            return (data.first ?? 0) != 0 ? "1" : "0"

        // Float types — little-endian IEEE 754
        case "real":
            guard data.count >= 4 else { return utf8Fallback(data) }
            let bits = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
            return String(Float(bitPattern: UInt32(littleEndian: bits)))
        case "float":
            if data.count >= 8 {
                let bits = data.withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }
                return String(Double(bitPattern: UInt64(littleEndian: bits)))
            } else if data.count >= 4 {
                let bits = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
                return String(Float(bitPattern: UInt32(littleEndian: bits)))
            }
            return utf8Fallback(data)

        // String types — nvarchar/nchar/ntext/xml are UTF-16LE
        case "nvarchar", "nchar", "ntext", "xml":
            return String(data: Data(data), encoding: .utf16LittleEndian)

        // String types — varchar/char/text are UTF-8 (or server codepage)
        case "char", "varchar", "text":
            return String(data: Data(data), encoding: .utf8)
                ?? String(data: Data(data), encoding: .windowsCP1252)

        // UUID — 16 bytes in SQL Server mixed-endian format
        case "uniqueidentifier":
            guard data.count >= 16 else { return utf8Fallback(data) }
            let bytes = Array(data)
            let uuid = UUID(uuid: (
                bytes[3], bytes[2], bytes[1], bytes[0],
                bytes[5], bytes[4],
                bytes[7], bytes[6],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            ))
            return uuid.uuidString

        // Binary — hex display
        case "binary", "varbinary", "image":
            let hex = data.map { String(format: "%02X", $0) }.joined()
            return "0x\(hex)"

        // Date/time — TDS packed formats require scale/epoch context.
        // The raw bytes are not self-describing, so fall back to UTF-8
        // (works when the TDS parser has pre-formatted the value).
        case "datetime", "datetime2", "date", "time", "datetimeoffset", "smalldatetime":
            return utf8Fallback(data)

        // Decimal/numeric/money — TDS packed format
        case "decimal", "numeric", "money", "smallmoney":
            return utf8Fallback(data)

        default:
            return utf8Fallback(data)
        }
    }

    private static func utf8Fallback(_ data: Data.SubSequence) -> String? {
        String(data: Data(data), encoding: .utf8)
    }
}
