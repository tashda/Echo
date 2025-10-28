import XCTest
@testable import PostgresKit

final class StatementCacheTests: XCTestCase {
    func testLRUEviction() throws {
        let cache = StatementCache(capacity: 2)
        cache.insert(.init(sql: "a", parameterCount: 1, handle: WireConnection.WirePreparedStatement(sql: "a")))
        cache.insert(.init(sql: "b", parameterCount: 2, handle: WireConnection.WirePreparedStatement(sql: "b")))
        XCTAssertNotNil(cache.lookup(sql: "a", parameterCount: 1))
        cache.insert(.init(sql: "c", parameterCount: 3, handle: WireConnection.WirePreparedStatement(sql: "c")))
        // "b" should be evicted since "a" was touched
        XCTAssertNil(cache.lookup(sql: "b", parameterCount: 2))
        XCTAssertNotNil(cache.lookup(sql: "a", parameterCount: 1))
        XCTAssertNotNil(cache.lookup(sql: "c", parameterCount: 3))
    }
}
