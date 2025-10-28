import Foundation

// Simple LRU cache used for prepared-statement metadata.
public final class LRUCache<Key: Hashable, Value> {
    private var dict: [Key: (value: Value, index: Int)] = [:]
    private var order: [Key] = []
    private let capacity: Int

    public init(capacity: Int) {
        precondition(capacity > 0, "LRU capacity must be > 0")
        self.capacity = capacity
    }

    public func get(_ key: Key) -> Value? {
        guard let entry = dict[key] else { return nil }
        touch(key, at: entry.index)
        return entry.value
    }

    public func set(_ key: Key, value: Value) {
        if let entry = dict[key] {
            dict[key] = (value, entry.index)
            touch(key, at: entry.index)
            return
        }
        // Evict if full
        if order.count == capacity, let lru = order.first {
            dict.removeValue(forKey: lru)
            order.removeFirst()
        }
        order.append(key)
        dict[key] = (value, order.count - 1)
    }

    private func touch(_ key: Key, at index: Int) {
        guard index < order.count, order[index] == key else { return }
        order.remove(at: index)
        order.append(key)
        // Rebuild indices (small capacity keeps this cheap)
        for (i, k) in order.enumerated() {
            if let val = dict[k]?.value { dict[k] = (val, i) }
        }
    }

    public func remove(_ key: Key) {
        guard let entry = dict.removeValue(forKey: key) else { return }
        if entry.index < order.count && order[entry.index] == key {
            order.remove(at: entry.index)
            // Rebuild indices
            for (i, k) in order.enumerated() {
                if let val = dict[k]?.value { dict[k] = (val, i) }
            }
        } else {
            // If indices drifted, fallback to linear removal
            if let idx = order.firstIndex(of: key) {
                order.remove(at: idx)
                for (i, k) in order.enumerated() {
                    if let val = dict[k]?.value { dict[k] = (val, i) }
                }
            }
        }
    }
}

public struct PreparedStatementInfo: Sendable {
    public let sql: String
    public let parameterCount: Int
    public let handle: WireConnection.WirePreparedStatement
    public init(sql: String, parameterCount: Int, handle: WireConnection.WirePreparedStatement) {
        self.sql = sql
        self.parameterCount = parameterCount
        self.handle = handle
    }
}

public final class StatementCache: @unchecked Sendable {
    private let lru: LRUCache<String, PreparedStatementInfo>

    public init(capacity: Int = 256) {
        self.lru = LRUCache(capacity: capacity)
    }

    private func key(sql: String, parameterCount: Int) -> String {
        "\(sql)|#\(parameterCount)"
    }

    public func lookup(sql: String, parameterCount: Int) -> PreparedStatementInfo? {
        lru.get(key(sql: sql, parameterCount: parameterCount))
    }

    public func insert(_ info: PreparedStatementInfo) {
        lru.set(key(sql: info.sql, parameterCount: info.parameterCount), value: info)
    }

    public func remove(sql: String, parameterCount: Int) {
        let k = key(sql: sql, parameterCount: parameterCount)
        lru.remove(k)
    }
}
import PostgresWire
