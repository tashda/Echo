import Foundation
import SQLite3

/// Confined to the owning store actor. No SQLite pointer crosses an isolation boundary.
final class SQLiteConnection {
    enum Value {
        case text(String), blob(Data), integer(Int64), real(Double), null
    }

    private let handle: OpaquePointer
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(url: URL) throws {
        var pointer: OpaquePointer?
        let status = sqlite3_open_v2(url.path, &pointer,
                                    SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
        guard status == SQLITE_OK, let pointer else {
            if let pointer { sqlite3_close_v2(pointer) }
            throw LocalStorageError.sqlite(status)
        }
        handle = pointer
        sqlite3_busy_timeout(handle, 5_000)
        do {
            try execute("PRAGMA journal_mode=WAL")
            try execute("PRAGMA synchronous=FULL")
            try execute("PRAGMA temp_store=MEMORY")
            try execute("PRAGMA foreign_keys=ON")
            try execute("PRAGMA journal_size_limit=8388608")
        } catch {
            sqlite3_close_v2(handle)
            throw error
        }
    }

    deinit { sqlite3_close_v2(handle) }

    func execute(_ sql: String, _ values: [Value] = []) throws {
        try query(sql, values) { _ in }
    }

    func query(_ sql: String, _ values: [Value] = [], row: (OpaquePointer) throws -> Void) throws {
        var statement: OpaquePointer?
        let prepared = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard prepared == SQLITE_OK, let statement else { throw LocalStorageError.sqlite(prepared) }
        defer { sqlite3_finalize(statement) }
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let status: Int32
            switch value {
            case .text(let text): status = sqlite3_bind_text(statement, index, text, -1, transient)
            case .blob(let data):
                status = data.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(bytes.count), transient)
                }
            case .integer(let integer): status = sqlite3_bind_int64(statement, index, integer)
            case .real(let real): status = sqlite3_bind_double(statement, index, real)
            case .null: status = sqlite3_bind_null(statement, index)
            }
            guard status == SQLITE_OK else { throw LocalStorageError.sqlite(status) }
        }
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { break }
            guard status == SQLITE_ROW else { throw LocalStorageError.sqlite(status) }
            try row(statement)
        }
    }

    func transaction<T>(_ body: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE")
        do {
            let result = try body()
            try execute("COMMIT")
            return result
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    static func text(_ row: OpaquePointer, _ index: Int32) -> String {
        guard let pointer = sqlite3_column_text(row, index) else { return "" }
        return String(cString: pointer)
    }

    static func data(_ row: OpaquePointer, _ index: Int32) -> Data {
        let count = Int(sqlite3_column_bytes(row, index))
        guard count > 0, let pointer = sqlite3_column_blob(row, index) else { return Data() }
        return Data(bytes: pointer, count: count)
    }
}
