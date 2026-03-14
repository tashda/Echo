import XCTest
@testable import Echo

/// Shared assertion and utility helpers for integration tests.
enum IntegrationTestHelpers {

    /// Assert that a query returns at least the expected number of rows.
    static func assertMinRowCount(
        _ result: QueryResultSet,
        expected: Int,
        message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThanOrEqual(
            result.rows.count,
            expected,
            "Expected at least \(expected) rows\(message.isEmpty ? "" : ": \(message)")",
            file: file,
            line: line
        )
    }

    /// Assert that a query returns exactly the expected number of rows.
    static func assertRowCount(
        _ result: QueryResultSet,
        expected: Int,
        message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            result.rows.count,
            expected,
            "Expected \(expected) rows\(message.isEmpty ? "" : ": \(message)")",
            file: file,
            line: line
        )
    }

    /// Assert that a result set contains a specific column by name.
    static func assertHasColumn(
        _ result: QueryResultSet,
        named columnName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let names = result.columns.map(\.name)
        XCTAssertTrue(
            names.contains(where: { $0.caseInsensitiveCompare(columnName) == .orderedSame }),
            "Expected column '\(columnName)' in \(names)",
            file: file,
            line: line
        )
    }

    /// Extract the value of a column from the first row of a result set.
    static func firstRowValue(
        _ result: QueryResultSet,
        column: String
    ) -> String? {
        guard let row = result.rows.first else { return nil }
        guard let index = result.columns.firstIndex(where: {
            $0.name.caseInsensitiveCompare(column) == .orderedSame
        }) else { return nil }
        guard index < row.count else { return nil }
        return row[index]
    }

    /// Assert that a string list contains a value (case-insensitive).
    static func assertContains(
        _ list: [String],
        value: String,
        message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            list.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }),
            "Expected '\(value)' in \(list)\(message.isEmpty ? "" : ": \(message)")",
            file: file,
            line: line
        )
    }

    /// Assert that schema objects contain an object with the given name and type.
    static func assertContainsObject(
        _ objects: [SchemaObjectInfo],
        name: String,
        type: SchemaObjectInfo.ObjectType? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let match = objects.contains { obj in
            let nameMatch = obj.name.caseInsensitiveCompare(name) == .orderedSame
            if let type { return nameMatch && obj.type == type }
            return nameMatch
        }
        let typeDesc = type.map { " of type \($0)" } ?? ""
        XCTAssertTrue(match, "Expected object '\(name)'\(typeDesc) in \(objects.map(\.name))", file: file, line: line)
    }

    /// Assert that table structure details contain a column with the given name.
    static func assertHasStructureColumn(
        _ details: TableStructureDetails,
        named columnName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let names = details.columns.map(\.name)
        XCTAssertTrue(
            names.contains(where: { $0.caseInsensitiveCompare(columnName) == .orderedSame }),
            "Expected column '\(columnName)' in structure: \(names)",
            file: file,
            line: line
        )
    }
}

/// Thread-safe wrapper for mutable state captured in closures across actor boundaries.
final class LockIsolated<Value: Sendable>: @unchecked Sendable {
    private var _value: Value
    private let lock = NSLock()

    init(_ value: Value) { _value = value }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func setValue(_ newValue: Value) {
        lock.lock()
        defer { lock.unlock() }
        _value = newValue
    }

    func withValue<R>(_ body: (inout Value) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&_value)
    }
}
