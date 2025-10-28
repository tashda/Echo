import Foundation
import PostgresWire
import PostgresNIO

public actor PreparedServerCache {
    public struct Entry: Sendable {
        public let key: String
        public let prepared: WirePreparedQuery
    }

    private var dict: [String: WirePreparedQuery] = [:]
    private var order: [String] = []
    private let capacity: Int

    public init(capacity: Int) {
        precondition(capacity > 0, "capacity must be > 0")
        self.capacity = capacity
    }

    public func lookup(_ key: String) -> WirePreparedQuery? {
        guard let prepared = dict[key] else { return nil }
        touch(key)
        return prepared
    }

    public func insert(_ key: String, prepared: WirePreparedQuery) {
        if dict[key] != nil {
            dict[key] = prepared
            touch(key)
            return
        }
        if order.count == capacity, let lru = order.first, let evicted = dict.removeValue(forKey: lru) {
            order.removeFirst()
            Task { _ = try? await evicted.deallocate().get() }
        }
        order.append(key)
        dict[key] = prepared
    }

    public func remove(_ key: String) {
        if let ev = dict.removeValue(forKey: key) {
            Task { _ = try? await ev.deallocate().get() }
        }
        if let idx = order.firstIndex(of: key) {
            order.remove(at: idx)
        }
    }

    private func touch(_ key: String) {
        if let idx = order.firstIndex(of: key) {
            order.remove(at: idx)
            order.append(key)
        }
    }
}

public enum ServerPrepareKey {
    public static func make(sql: String, types: [PostgresDataType]) -> String {
        var s = sql
        s.append("|#")
        for (i, t) in types.enumerated() {
            s.append(String(t.rawValue))
            if i != types.count - 1 { s.append(",") }
        }
        return s
    }
}
