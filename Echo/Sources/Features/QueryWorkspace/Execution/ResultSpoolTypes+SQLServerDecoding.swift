import Foundation
import SQLServerKit

/// SQL Server columns as Echo spools them: every row holds the cells' wire bytes, and each
/// column's `ColumnInfo.wireType` is the driver's `SQLServerCellType.encoded`. Formatting with
/// `SQLServerCellFormatter` gives exactly what `SQLServerRow.toStringArray()` gave the live
/// preview rows, so row 201 reads like row 200 (dates, money, decimals, code-page varchar).
enum SQLServerSpoolColumns {
    /// Cell types for every column, or `nil` when these are not (all) SQL Server columns.
    nonisolated static func cellTypes(for columns: [ColumnInfo]) -> [SQLServerCellType]? {
        guard !columns.isEmpty else { return nil }
        var types: [SQLServerCellType] = []
        types.reserveCapacity(columns.count)
        for column in columns {
            guard let encoded = column.wireType, let type = SQLServerCellType(encoded: encoded) else { return nil }
            types.append(type)
        }
        return types
    }

    /// Decodes one spooled row (per cell `0x00` for NULL or `0x01` + UInt32-LE length + wire bytes).
    nonisolated static func decodeRow(_ data: Data, types: [SQLServerCellType]) -> [String?] {
        var values: [String?] = []
        values.reserveCapacity(types.count)
        data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count, values.count < types.count {
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
                values.append(SQLServerCellFormatter.string(bytes: cell, type: types[values.count]))
            }
        }
        while values.count < types.count { values.append(nil) }
        return values
    }
}
