import Foundation
import SQLServerKit

extension ResultSpoolHandle {
    func decodeRowData(_ data: Data) -> [String?] {
        // Postgres spools hold binary cells in every row (preview rows included): format them with the
        // driver so rows after the preview read exactly like the preview rows.
        if metadata.rowEncoding == "binary_v1", let oids = postgresColumnOIDs() {
            return PostgresSpoolColumns.decodeRow(data, oids: oids)
        }
        // SQL Server spools hold wire bytes in every row too, formatted by the driver.
        if metadata.rowEncoding == "binary_v1", let types = sqlServerCellTypes() {
            return SQLServerSpoolColumns.decodeRow(data, types: types)
        }
        if metadata.rowEncoding == "binary_v1" {
            let binaryRow = ResultBinaryRow(data: data)
            let columnCount = max(metadata.columns.count, 1)
            var values = ResultBinaryRowCodec.decode(binaryRow, columnCount: columnCount)
            normalizeValues(&values)
            return values
        } else {
            return decodeLegacyJSONRow(from: data)
        }
    }

    func decodeLegacyJSONRow(from data: Data) -> [String?] {
        let decoder = makeJSONDecoder()
        if let row = try? decoder.decode([String?].self, from: data) {
            return row
        }
        return []
    }

    nonisolated func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    nonisolated func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func normalizeValues(_ values: inout [String?]) {
        guard !values.isEmpty else { return }
        let columns = metadata.columns
        for index in 0..<min(values.count, columns.count) {
            guard let raw = values[index] else { continue }
            let type = columns[index].dataType.lowercased()
            if type.contains("bool") {
                let lower = raw.lowercased()
                if lower == "t" || lower == "true" {
                    values[index] = "true"
                } else if lower == "f" || lower == "false" {
                    values[index] = "false"
                }
            }
        }
    }

    /// Cell types for a SQL Server spool (parsed once per spool), `nil` for other engines.
    func sqlServerCellTypes() -> [SQLServerCellType]? {
        if let cached = cachedSQLServerCellTypes { return cached.value }
        let types = SQLServerSpoolColumns.cellTypes(for: metadata.columns)
        if !metadata.columns.isEmpty { cachedSQLServerCellTypes = CachedCellTypes(value: types) }
        return types
    }

    /// Column OIDs for a Postgres spool (computed once per spool), `nil` for other engines.
    func postgresColumnOIDs() -> [UInt32]? {
        if let cached = cachedPostgresOIDs { return cached.value }
        let oids = PostgresSpoolColumns.oids(for: metadata.columns)
        if !metadata.columns.isEmpty { cachedPostgresOIDs = CachedOIDs(value: oids) }
        return oids
    }
}
