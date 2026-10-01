import Foundation
import PostgresKit

/// Postgres column types as Echo stores them: `ColumnInfo.dataType` is `"NAME(OID)"`
/// (from `PostgresRowExtractor.columns(from:)`), e.g. `"INTEGER(23)"` or `"TEXT[](1009)"`.
enum PostgresSpoolColumns {
    /// The type OID when `dataType` has the driver's `"NAME(OID)"` form. Names are upper-case, which
    /// keeps SQL Server type names such as `varchar(50)` from being mistaken for Postgres OIDs.
    nonisolated static func oid(for dataType: String) -> UInt32? {
        guard let first = dataType.unicodeScalars.first, CharacterSet.uppercaseLetters.contains(first),
              dataType.last == ")", let open = dataType.lastIndex(of: "(") else { return nil }
        let name = dataType[..<open]
        guard !name.unicodeScalars.contains(where: { CharacterSet.lowercaseLetters.contains($0) }) else { return nil }
        return PostgresRowExtractor.oid(fromDataType: dataType)
    }

    /// OIDs for every column, or `nil` when these are not (all) Postgres columns.
    nonisolated static func oids(for columns: [ColumnInfo]) -> [UInt32]? {
        guard !columns.isEmpty else { return nil }
        var oids: [UInt32] = []
        oids.reserveCapacity(columns.count)
        for column in columns {
            guard let oid = oid(for: column.dataType) else { return nil }
            oids.append(oid)
        }
        return oids
    }

    /// Decodes one spooled row (per cell `0x00` for NULL or `0x01` + UInt32-LE length + the
    /// server's text bytes) with the driver's formatter, so spooled rows read exactly like the live preview rows.
    nonisolated static let formatter = PostgresCellFormatter()

    nonisolated static func decodeRow(_ data: Data, oids: [UInt32], formatter: PostgresCellFormatter = formatter) -> [String?] {
        var values: [String?] = []
        values.reserveCapacity(oids.count)
        data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count, values.count < oids.count {
                let flag = bytes[offset]
                offset += 1
                if flag == 0 {
                    values.append(nil)
                    continue
                }
                guard offset + 4 <= bytes.count else { break }
                let length = Int(UInt32(littleEndian: bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self)))
                offset += 4
                guard offset + length <= bytes.count else { break }
                let cell = UnsafeRawBufferPointer(rebasing: bytes[offset..<(offset + length)])
                offset += length
                values.append(formatter.stringValue(oid: oids[values.count], bytes: cell))
            }
        }
        while values.count < oids.count { values.append(nil) }
        return values
    }
}

/// Formats deferred Postgres cell payloads with the driver's formatter.
struct PostgresPayloadFormatter: Sendable {
    private let formatter = PostgresCellFormatter()

    nonisolated func stringValue(for payload: ResultCellPayload, columnIndex: Int) -> String? {
        guard let data = payload.bytes else { return nil }
        if payload.format == .text {
            return String(decoding: data, as: UTF8.self)
        }
        return formatter.stringValue(oid: payload.dataTypeOID, data: data)
    }
}
