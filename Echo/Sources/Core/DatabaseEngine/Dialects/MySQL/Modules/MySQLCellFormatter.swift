import Foundation
import MySQLKit

/// Display text for MySQL and MariaDB values (Echo #40, decision D24: the server's own text, as
/// round 21 decided for Postgres).
///
/// Values arrive as the server prints them (text protocol): DECIMAL, DATETIME(6), TIME and FLOAT
/// exactly as MySQL shows them. Bytes that aren't text (BLOB, BINARY, GEOMETRY) show as `0x…`
/// hex; BIT(1) shows `0`/`1`, longer BIT columns as `b'1010'`.
internal struct MySQLCellFormatter: Sendable {
    func stringValue(bytes: Data?, column: MySQLColumn) -> String? {
        guard let bytes else { return nil }
        if column.columnType == .bit { return Self.bits(bytes, length: column.columnLength) }
        if column.columnType == .geometry { return Self.hex(bytes) }
        if column.isBinary {
            if let text = String(data: bytes, encoding: .utf8), text.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) || $0 == "\n" || $0 == "\t" }) {
                return text
            }
            return Self.hex(bytes)
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    func stringValue(for value: MySQLData, column: MySQLColumn) -> String? {
        stringValue(bytes: value.bytes, column: column)
    }

    static func hex(_ bytes: Data) -> String {
        bytes.reduce(into: "0x") { $0 += String(format: "%02X", $1) }
    }

    /// BIT(1) as `0`/`1`; longer as `b'…'` with exactly the column's bits.
    static func bits(_ bytes: Data, length: UInt64) -> String {
        let all = bytes.map { byte in (0..<8).reversed().map { (byte >> $0) & 1 == 1 ? "1" : "0" }.joined() }.joined()
        let width = Int(max(1, min(length, UInt64(all.count))))
        let trimmed = String(all.suffix(width))
        return length <= 1 ? trimmed : "b'\(trimmed)'"
    }
}
