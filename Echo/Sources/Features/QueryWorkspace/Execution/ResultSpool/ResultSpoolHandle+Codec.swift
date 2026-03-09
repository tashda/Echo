import Foundation

extension ResultSpoolHandle {
    func decodeRowData(_ data: Data) -> [String?] {
        if metadata.rowEncoding == "binary_v1" {
            let binaryRow = ResultBinaryRow(data: data)
            var values = ResultBinaryRowCodec.decode(binaryRow, columnCount: metadata.columns.count)
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
}
