import Foundation
import Testing
@testable import Echo

@Suite("DiagramPrefetcher")
struct DiagramPrefetcherTests {

    /// Thread-safe accumulator for test assertions.
    private final class Accumulator<T: Sendable>: @unchecked Sendable {
        private let lock = NSLock()
        private var _values: [T] = []
        var values: [T] { lock.withLock { _values } }
        var count: Int { lock.withLock { _values.count } }
        func append(_ value: T) { lock.withLock { _values.append(value) } }
    }

    @Test func handlerIsCalledForEnqueuedRequests() async {
        let prefetcher = DiagramPrefetcher()
        let processed = Accumulator<DiagramPrefetcher.Request>()

        let request = makeRequest(schema: "public", table: "users")

        await prefetcher.setHandler { req in
            processed.append(req)
            return true
        }

        await prefetcher.enqueue(request)
        try? await Task.sleep(for: .milliseconds(100))

        #expect(processed.count == 1)
        #expect(processed.values.first?.cacheKey.table == "users")
    }

    @Test func requestsQueuedBeforeHandlerAreProcessed() async {
        let prefetcher = DiagramPrefetcher()
        let processed = Accumulator<String>()

        let request = makeRequest(schema: "public", table: "orders")

        await prefetcher.enqueue(request)

        await prefetcher.setHandler { _ in
            processed.append("done")
            return true
        }

        try? await Task.sleep(for: .milliseconds(200))
        #expect(processed.count == 1)
    }

    @Test func duplicateRequestsAreIgnored() async {
        let prefetcher = DiagramPrefetcher()
        let processed = Accumulator<String>()

        let request = makeRequest(schema: "public", table: "products")

        // Enqueue both requests BEFORE setting the handler so the prefetcher
        // cannot process the first one before the duplicate is enqueued.
        await prefetcher.enqueue(request)
        await prefetcher.enqueue(request) // duplicate

        await prefetcher.setHandler { _ in
            processed.append("done")
            return true
        }

        try? await Task.sleep(for: .milliseconds(500))
        #expect(processed.count == 1)
    }

    @Test func cancelAllClearsQueue() async {
        let prefetcher = DiagramPrefetcher()
        let processed = Accumulator<String>()

        let request1 = makeRequest(schema: "public", table: "a")
        let request2 = makeRequest(schema: "public", table: "b")

        await prefetcher.enqueue(request1)
        await prefetcher.enqueue(request2)

        await prefetcher.cancelAll()

        await prefetcher.setHandler { _ in
            processed.append("done")
            return true
        }

        try? await Task.sleep(for: .milliseconds(100))
        #expect(processed.count == 0)
    }

    @Test func prioritizedRequestProcessedFirst() async {
        let prefetcher = DiagramPrefetcher()
        let processedOrder = Accumulator<String>()

        let request1 = makeRequest(schema: "public", table: "first")
        let request2 = makeRequest(schema: "public", table: "priority")

        await prefetcher.enqueue(request1)
        await prefetcher.enqueue(request2, prioritize: true)

        await prefetcher.setHandler { req in
            processedOrder.append(req.cacheKey.table)
            return true
        }

        try? await Task.sleep(for: .milliseconds(300))
        #expect(processedOrder.values.first == "priority")
    }

    // MARK: - Helpers

    private func makeRequest(schema: String, table: String) -> DiagramPrefetcher.Request {
        let projectID = UUID()
        let connectionID = UUID()
        let cacheKey = DiagramCacheKey(
            projectID: projectID,
            connectionID: connectionID,
            schema: schema,
            table: table
        )
        return DiagramPrefetcher.Request(
            cacheKey: cacheKey,
            connectionSessionID: connectionID,
            object: SchemaObjectInfo(name: table, schema: schema, type: .table),
            isBackgroundSweep: false
        )
    }
}

@Suite("DiagramCacheKey")
struct DiagramCacheKeyTests {

    @Test func sameInputProducesSameFilename() {
        let key1 = DiagramCacheKey(
            projectID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            connectionID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            schema: "public",
            table: "users"
        )
        let key2 = DiagramCacheKey(
            projectID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            connectionID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            schema: "public",
            table: "users"
        )
        #expect(key1.canonicalFilename == key2.canonicalFilename)
    }

    @Test func differentProjectIDProducesDifferentFilename() {
        let key1 = DiagramCacheKey(
            projectID: UUID(),
            connectionID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            schema: "public",
            table: "users"
        )
        let key2 = DiagramCacheKey(
            projectID: UUID(),
            connectionID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            schema: "public",
            table: "users"
        )
        #expect(key1.canonicalFilename != key2.canonicalFilename)
    }

    @Test func caseInsensitiveSchemaAndTable() {
        let key1 = DiagramCacheKey(
            projectID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            connectionID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            schema: "Public",
            table: "Users"
        )
        let key2 = DiagramCacheKey(
            projectID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            connectionID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            schema: "public",
            table: "users"
        )
        #expect(key1.canonicalFilename == key2.canonicalFilename)
    }
}
