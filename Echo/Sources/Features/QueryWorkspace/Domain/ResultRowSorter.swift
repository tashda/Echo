import Foundation

/// Orders a results grid's rows by one column (the header's sort arrow). The old way compared two
/// rows by fetching, trimming and parsing both values on every comparison, on the main thread: with
/// 121,000 rows that is millions of parses and Echo stopped answering (2026-10-01). Each row's key is
/// now made once, and a big sort runs off the main thread.
nonisolated enum ResultRowSorter {
    /// One row's value, parsed once. A NULL has no key.
    struct Key: Sendable {
        let text: String
        let number: Decimal?
        let boolean: Bool?
    }

    /// Up to this many rows the order is made at once; beyond it, off the main thread.
    static let immediateLimit = 20_000

    static func keys(for values: [String?], dataType: String) -> [Key?] {
        let type = dataType.lowercased()
        let isNumeric = isNumericType(type)
        let isBoolean = type.contains("bool")
        return values.map { value in
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return Key(text: trimmed,
                       number: isNumeric ? Decimal(string: trimmed) : nil,
                       boolean: isBoolean ? parseBoolean(trimmed) : nil)
        }
    }

    /// The row indices in sort order: NULLs last when ascending, first when descending (a NULL
    /// is the greatest); equal values keep their row order.
    static func order(keys: [Key?], ascending: Bool) -> [Int] {
        keys.indices.sorted { lhs, rhs in
            let result = compare(keys[lhs], keys[rhs])
            if result == .orderedSame { return lhs < rhs }
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    /// The same, made off the main thread.
    @concurrent
    static func sortedOrder(values: [String?], dataType: String, ascending: Bool) async -> [Int] {
        order(keys: keys(for: values, dataType: dataType), ascending: ascending)
    }

    static func compare(_ lhs: Key?, _ rhs: Key?) -> ComparisonResult {
        switch (lhs, rhs) {
        case (nil, nil): return .orderedSame
        case (nil, _): return .orderedDescending
        case (_, nil): return .orderedAscending
        case let (left?, right?):
            if let leftNumber = left.number, let rightNumber = right.number {
                return leftNumber == rightNumber ? .orderedSame : (leftNumber < rightNumber ? .orderedAscending : .orderedDescending)
            }
            if let leftBool = left.boolean, let rightBool = right.boolean {
                return leftBool == rightBool ? .orderedSame : (leftBool ? .orderedDescending : .orderedAscending)
            }
            return left.text.caseInsensitiveCompare(right.text)
        }
    }

    private static func isNumericType(_ type: String) -> Bool {
        ["int", "serial", "numeric", "decimal", "float", "double", "money"].contains { type.contains($0) }
    }

    private static func parseBoolean(_ value: String) -> Bool? {
        switch value.lowercased() {
        case "true", "t", "1", "yes", "y": true
        case "false", "f", "0", "no", "n": false
        default: nil
        }
    }
}
