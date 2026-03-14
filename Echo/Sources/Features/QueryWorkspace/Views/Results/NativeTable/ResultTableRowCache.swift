#if os(macOS)
import Foundation

@MainActor
struct ResultTableRowCache {
    private var storage: [Int: [String?]] = [:]
    private var accessOrder: [Int] = []
    let capacity: Int

    init(capacity: Int = 512) {
        self.capacity = capacity
    }

    mutating func get(_ key: Int) -> [String?]? {
        guard let value = storage[key] else { return nil }
        if let index = accessOrder.lastIndex(of: key) {
            accessOrder.remove(at: index)
            accessOrder.append(key)
        }
        return value
    }

    mutating func put(_ key: Int, value: [String?]) {
        if storage[key] != nil {
            if let index = accessOrder.lastIndex(of: key) {
                accessOrder.remove(at: index)
            }
        } else if storage.count >= capacity {
            let evicted = accessOrder.removeFirst()
            storage.removeValue(forKey: evicted)
        }
        storage[key] = value
        accessOrder.append(key)
    }

    mutating func clear() {
        storage.removeAll(keepingCapacity: true)
        accessOrder.removeAll(keepingCapacity: true)
    }

    var count: Int { storage.count }
}
#endif
