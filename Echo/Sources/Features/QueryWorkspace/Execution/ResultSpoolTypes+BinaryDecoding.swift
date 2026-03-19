import Foundation
import NIOCore
import PostgresWire

/// Extracts Postgres OIDs from ColumnInfo.dataType strings.
/// Format: "TYPE(OID)" e.g. "INTEGER(23)" or legacy "INTEGER"
enum PostgresDataTypeOIDMap {
    nonisolated static func oid(for dataType: String) -> UInt32? {
        // Try to extract OID from "TYPE(OID)" format
        if let openParen = dataType.lastIndex(of: "("),
           let closeParen = dataType.lastIndex(of: ")"),
           closeParen > openParen {
            let oidStr = dataType[dataType.index(after: openParen)..<closeParen]
            return UInt32(oidStr)
        }
        // Fallback: map known type names to OIDs
        switch dataType.uppercased() {
        case "BOOLEAN": return 16
        case "BYTEA": return 17
        case "BIGINT", "INT8": return 20
        case "SMALLINT", "INT2": return 21
        case "INTEGER", "INT4": return 23
        case "TEXT": return 25
        case "OID": return 26
        case "JSON": return 114
        case "REAL", "FLOAT4": return 700
        case "DOUBLE PRECISION", "FLOAT8": return 701
        case "VARCHAR", "CHARACTER VARYING": return 1043
        case "DATE": return 1082
        case "TIME", "TIME WITHOUT TIME ZONE": return 1083
        case "TIMESTAMP", "TIMESTAMP WITHOUT TIME ZONE": return 1114
        case "TIMESTAMP WITH TIME ZONE", "TIMESTAMPTZ": return 1184
        case "NUMERIC": return 1700
        case "UUID": return 2950
        case "JSONB": return 3802
        default: return nil
        }
    }
}

/// Fast binary-to-string decoder that interprets Postgres wire format directly
/// without creating ByteBuffer or PostgresCell objects. Used for spool decode.
enum DirectBinaryDecoder {
    nonisolated static func format(_ data: Data.SubSequence, oid: UInt32) -> String? {
        guard !data.isEmpty else { return "" }
        switch oid {
        // Boolean (OID 16)
        case 16:
            return data.first == 1 ? "true" : "false"
        // Int2 / Smallint (OID 21)
        case 21:
            guard data.count >= 2 else { return textFallback(data) }
            let value = Int16(bigEndian: data.withUnsafeBytes { $0.loadUnaligned(as: Int16.self) })
            return String(value)
        // Int4 / Integer (OID 23), OID type (26)
        case 23, 26:
            guard data.count >= 4 else { return textFallback(data) }
            let value = Int32(bigEndian: data.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) })
            return String(value)
        // Int8 / Bigint (OID 20)
        case 20:
            guard data.count >= 8 else { return textFallback(data) }
            let value = Int64(bigEndian: data.withUnsafeBytes { $0.loadUnaligned(as: Int64.self) })
            return String(value)
        // Float4 (OID 700)
        case 700:
            guard data.count >= 4 else { return textFallback(data) }
            let bits = UInt32(bigEndian: data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
            let value = Float(bitPattern: bits)
            return String(value)
        // Float8 (OID 701)
        case 701:
            guard data.count >= 8 else { return textFallback(data) }
            let bits = UInt64(bigEndian: data.withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) })
            let value = Double(bitPattern: bits)
            return String(value)
        // Text, Varchar, Name, Char, JSON, JSONB header, XML, etc.
        case 18, 19, 25, 114, 142, 143, 1042, 1043, 3802:
            if oid == 3802, data.count > 1 {
                // JSONB: skip version byte (0x01)
                let jsonSlice = data.dropFirst()
                return String(data: Data(jsonSlice), encoding: .utf8) ?? textFallback(data)
            }
            return String(data: Data(data), encoding: .utf8) ?? textFallback(data)
        // UUID (OID 2950) — 16 bytes
        case 2950:
            guard data.count >= 16 else { return textFallback(data) }
            return data.withUnsafeBytes { ptr in
                let b = ptr.bindMemory(to: UInt8.self)
                return String(format: "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
                    b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                    b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15])
            }
        // Date (OID 1082) — Int32 days since 2000-01-01
        case 1082:
            guard data.count >= 4 else { return textFallback(data) }
            let days = Int32(bigEndian: data.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) })
            return formatPostgresDate(days: Int(days))
        // Timestamp (OID 1114) — Int64 microseconds since 2000-01-01
        case 1114:
            guard data.count >= 8 else { return textFallback(data) }
            let microseconds = Int64(bigEndian: data.withUnsafeBytes { $0.loadUnaligned(as: Int64.self) })
            return formatPostgresTimestamp(microseconds: microseconds, withTimeZone: false)
        // Timestamptz (OID 1184)
        case 1184:
            guard data.count >= 8 else { return textFallback(data) }
            let microseconds = Int64(bigEndian: data.withUnsafeBytes { $0.loadUnaligned(as: Int64.self) })
            return formatPostgresTimestamp(microseconds: microseconds, withTimeZone: true)
        // Time (OID 1083) — Int64 microseconds since midnight
        case 1083:
            guard data.count >= 8 else { return textFallback(data) }
            let us = Int64(bigEndian: data.withUnsafeBytes { $0.loadUnaligned(as: Int64.self) })
            let totalSeconds = us / 1_000_000
            let h = totalSeconds / 3600
            let m = (totalSeconds % 3600) / 60
            let s = totalSeconds % 60
            let frac = us % 1_000_000
            if frac == 0 { return String(format: "%02d:%02d:%02d", h, m, s) }
            return String(format: "%02d:%02d:%02d.%06d", h, m, s, frac)
        // Numeric (OID 1700) — complex BCD format, fall back to PostgresPayloadFormatter
        case 1700:
            return nil // Caller should fall back to slow path
        // Bytea (OID 17)
        case 17:
            return "\\x" + data.map { String(format: "%02x", $0) }.joined()
        // Default: try UTF-8 text
        default:
            return String(data: Data(data), encoding: .utf8) ?? textFallback(data)
        }
    }

    private nonisolated static func textFallback(_ data: Data.SubSequence) -> String {
        data.map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    /// Postgres epoch: 2000-01-01 00:00:00 UTC
    private static let postgresEpoch: TimeInterval = 946_684_800 // Unix timestamp of 2000-01-01

    private nonisolated static func formatPostgresDate(days: Int) -> String {
        let timestamp = postgresEpoch + Double(days) * 86400
        let date = Date(timeIntervalSince1970: timestamp)
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC") ?? .current, from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private nonisolated static func formatPostgresTimestamp(microseconds: Int64, withTimeZone: Bool) -> String {
        let seconds = Double(microseconds) / 1_000_000.0
        let timestamp = postgresEpoch + seconds
        let date = Date(timeIntervalSince1970: timestamp)
        let calendar = Calendar(identifier: .gregorian)
        let tz = withTimeZone ? TimeZone.current : (TimeZone(identifier: "UTC") ?? .current)
        let components = calendar.dateComponents(in: tz, from: date)
        let frac = microseconds % 1_000_000
        let base = String(format: "%04d-%02d-%02d %02d:%02d:%02d",
            components.year ?? 0, components.month ?? 0, components.day ?? 0,
            components.hour ?? 0, components.minute ?? 0, components.second ?? 0)
        if frac == 0 { return base }
        return base + String(format: ".%06d", abs(frac))
    }
}

struct PostgresPayloadFormatter: Sendable {
    private let allocator = ByteBufferAllocator()
    private let formatter = PostgresCellFormatter()

    nonisolated func stringValue(for payload: ResultCellPayload, columnIndex: Int) -> String? {
        let dataType = PostgresDataType(rawValue: payload.dataTypeOID) ?? .text
        let postgresFormat = PostgresFormat(rawValue: Int16(payload.format.rawValue)) ?? .text

        var buffer: ByteBuffer?
        if let data = payload.bytes {
            var byteBuffer = allocator.buffer(capacity: data.count)
            byteBuffer.writeBytes(data)
            buffer = byteBuffer
        }

        let cell = PostgresCell(
            bytes: buffer,
            dataType: dataType,
            format: postgresFormat,
            columnName: "",
            columnIndex: columnIndex
        )
        return formatter.stringValue(for: cell)
    }
}
