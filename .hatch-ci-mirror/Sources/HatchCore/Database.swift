import Foundation
#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif

/// A value that can be bound to or read from SQLite.
public enum SQLValue: Equatable, Sendable {
    case null
    case int(Int64)
    case double(Double)
    case text(String)
    case blob(Data)
}

extension SQLValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByNilLiteral, ExpressibleByBooleanLiteral {
    public init(stringLiteral value: String) { self = .text(value) }
    public init(integerLiteral value: Int64) { self = .int(value) }
    public init(floatLiteral value: Double) { self = .double(value) }
    public init(nilLiteral: ()) { self = .null }
    public init(booleanLiteral value: Bool) { self = .int(value ? 1 : 0) }
}

public extension SQLValue {
    static func opt(_ value: String?) -> SQLValue { value.map { .text($0) } ?? .null }
    static func opt(_ value: Int?) -> SQLValue { value.map { .int(Int64($0)) } ?? .null }
    static func opt(_ value: Int64?) -> SQLValue { value.map { .int($0) } ?? .null }
    static func opt(_ value: Double?) -> SQLValue { value.map { .double($0) } ?? .null }
    static func date(_ value: Date) -> SQLValue { .double(value.timeIntervalSince1970) }
    static func int(_ value: Int) -> SQLValue { .int(Int64(value)) }
}

public struct DatabaseError: Error, CustomStringConvertible, Sendable {
    public let message: String
    public let code: Int32
    public let sql: String
    public var description: String { "SQLite error \(code): \(message) [\(sql)]" }
}

/// One result row, read by column name.
public struct Row {
    fileprivate let columns: [String: Int]
    fileprivate let values: [SQLValue]

    public func value(_ name: String) -> SQLValue {
        guard let index = columns[name] else { return .null }
        return values[index]
    }
    public func string(_ name: String) -> String? {
        if case .text(let s) = value(name) { return s }
        if case .int(let i) = value(name) { return String(i) }
        return nil
    }
    public func int(_ name: String) -> Int? {
        switch value(name) {
        case .int(let i): return Int(i)
        case .double(let d): return Int(d)
        case .text(let s): return Int(s)
        default: return nil
        }
    }
    public func double(_ name: String) -> Double? {
        switch value(name) {
        case .double(let d): return d
        case .int(let i): return Double(i)
        default: return nil
        }
    }
    public func bool(_ name: String) -> Bool { (int(name) ?? 0) != 0 }
    public var firstValue: SQLValue { values.first ?? .null }
    public func date(_ name: String) -> Date? { double(name).map { Date(timeIntervalSince1970: $0) } }
}

private let SQLITE_TRANSIENT_DESTRUCTOR = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// A small, thread-safe wrapper over the system SQLite. One connection, a recursive lock, WAL mode.
public final class Database: @unchecked Sendable {
    private var handle: OpaquePointer?
    private let lock = NSRecursiveLock()
    private var transactionDepth = 0
    public let path: String

    public init(path: String) throws {
        self.path = path
        if path != ":memory:" {
            let dir = (path as NSString).deletingLastPathComponent
            if !dir.isEmpty { try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true) }
        }
        var db: OpaquePointer?
        let rc = sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
        guard rc == SQLITE_OK, let db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "cannot open"
            if let db { sqlite3_close(db) }
            throw DatabaseError(message: message, code: rc, sql: "open \(path)")
        }
        handle = db
        sqlite3_busy_timeout(db, 5000)
        try execute("PRAGMA foreign_keys = ON")
        if path != ":memory:" { _ = try query("PRAGMA journal_mode = WAL") { _ in 0 } }
        try execute("PRAGMA synchronous = NORMAL")
    }

    deinit { if let handle { sqlite3_close(handle) } }

    public var lastInsertRowID: Int64 { lock.withLock { sqlite3_last_insert_rowid(handle) } }
    public var changes: Int { lock.withLock { Int(sqlite3_changes(handle)) } }

    public func execute(_ sql: String, _ params: [SQLValue] = []) throws {
        _ = try query(sql, params) { _ in 0 }
    }

    @discardableResult
    public func query<T>(_ sql: String, _ params: [SQLValue] = [], map: (Row) throws -> T) throws -> [T] {
        lock.lock(); defer { lock.unlock() }
        var statement: OpaquePointer?
        let prepared = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard prepared == SQLITE_OK, let statement else {
            throw DatabaseError(message: String(cString: sqlite3_errmsg(handle)), code: prepared, sql: sql)
        }
        defer { sqlite3_finalize(statement) }
        for (offset, value) in params.enumerated() {
            let index = Int32(offset + 1)
            switch value {
            case .null: sqlite3_bind_null(statement, index)
            case .int(let i): sqlite3_bind_int64(statement, index, i)
            case .double(let d): sqlite3_bind_double(statement, index, d)
            case .text(let s): sqlite3_bind_text(statement, index, s, -1, SQLITE_TRANSIENT_DESTRUCTOR)
            case .blob(let d): _ = d.withUnsafeBytes { sqlite3_bind_blob(statement, index, $0.baseAddress, Int32(d.count), SQLITE_TRANSIENT_DESTRUCTOR) }
            }
        }
        let columnCount = Int(sqlite3_column_count(statement))
        var names: [String: Int] = [:]
        for i in 0..<columnCount { names[String(cString: sqlite3_column_name(statement, Int32(i)))] = i }
        var results: [T] = []
        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_DONE { break }
            guard step == SQLITE_ROW else {
                throw DatabaseError(message: String(cString: sqlite3_errmsg(handle)), code: step, sql: sql)
            }
            var values: [SQLValue] = []
            values.reserveCapacity(columnCount)
            for i in 0..<columnCount {
                let c = Int32(i)
                switch sqlite3_column_type(statement, c) {
                case SQLITE_INTEGER: values.append(.int(sqlite3_column_int64(statement, c)))
                case SQLITE_FLOAT: values.append(.double(sqlite3_column_double(statement, c)))
                case SQLITE_TEXT: values.append(.text(String(cString: sqlite3_column_text(statement, c))))
                case SQLITE_BLOB:
                    let n = Int(sqlite3_column_bytes(statement, c))
                    values.append(.blob(n == 0 ? Data() : Data(bytes: sqlite3_column_blob(statement, c), count: n)))
                default: values.append(.null)
                }
            }
            results.append(try map(Row(columns: names, values: values)))
        }
        return results
    }

    public func scalarInt(_ sql: String, _ params: [SQLValue] = []) throws -> Int {
        try query(sql, params) { row -> Int in
            if case .int(let i) = row.firstValue { return Int(i) }
            return 0
        }.first ?? 0
    }

    /// Runs `body` in a transaction. Nested calls become savepoints, so an error rolls back only the inner work.
    public func transaction<T>(_ body: () throws -> T) throws -> T {
        lock.lock(); defer { lock.unlock() }
        let name = "sp\(transactionDepth)"
        try execute(transactionDepth == 0 ? "BEGIN IMMEDIATE" : "SAVEPOINT \(name)")
        transactionDepth += 1
        do {
            let result = try body()
            transactionDepth -= 1
            try execute(transactionDepth == 0 ? "COMMIT" : "RELEASE \(name)")
            return result
        } catch {
            transactionDepth -= 1
            _ = try? execute(transactionDepth == 0 ? "ROLLBACK" : "ROLLBACK TO \(name)")
            if transactionDepth > 0 { _ = try? execute("RELEASE \(name)") }
            throw error
        }
    }

    public var userVersion: Int {
        get { (try? query("PRAGMA user_version") { $0.int("user_version") ?? 0 }.first) ?? 0 }
        set { _ = try? execute("PRAGMA user_version = \(newValue)") }
    }

    public var sqliteVersion: String { String(cString: sqlite3_libversion()) }

    /// True when this SQLite build has FTS5 (needed for search).
    public var hasFTS5: Bool {
        (try? query("SELECT sqlite_compileoption_used('ENABLE_FTS5') AS v") { $0.int("v") ?? 0 }.first) == 1
    }
}
