import Foundation

enum JSONParseError: LocalizedError, Equatable {
    case invalidTopLevel
    case invalidObjectRow(Int)

    var errorDescription: String? {
        switch self {
        case .invalidTopLevel:
            return "The JSON file must contain an array of objects."
        case .invalidObjectRow(let index):
            return "Row \(index + 1) is not a JSON object."
        }
    }
}

nonisolated struct JSONFileParser {
    @concurrent
    static func parse(url: URL, previewLimit: Int? = nil) async throws -> CSVParseResult {
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let rows = object as? [Any] else {
            throw JSONParseError.invalidTopLevel
        }

        var headers: [String] = []
        var normalizedRows: [[String: Any]] = []
        normalizedRows.reserveCapacity(rows.count)

        for (index, row) in rows.enumerated() {
            guard let dictionary = row as? [String: Any] else {
                throw JSONParseError.invalidObjectRow(index)
            }

            for key in dictionary.keys where !headers.contains(key) {
                headers.append(key)
            }
            normalizedRows.append(dictionary)
        }

        let totalRowCount = normalizedRows.count
        let limitedRows: ArraySlice<[String: Any]>
        if let previewLimit {
            limitedRows = normalizedRows.prefix(previewLimit)
        } else {
            limitedRows = normalizedRows[...]
        }

        let values = limitedRows.map { row in
            headers.map { key in
                stringify(row[key])
            }
        }

        return CSVParseResult(headers: headers, rows: values, totalRowCount: totalRowCount)
    }

    private static func stringify(_ value: Any?) -> String {
        guard let value else { return "" }
        if value is NSNull { return "" }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return String(describing: value)
    }
}
