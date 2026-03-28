import Foundation
import Testing
@testable import Echo

@Suite("DiagramPrefetcher")
struct DiagramPrefetcherTests {

    @Test func handlerIsCalledForEnqueuedRequests() async {
        let prefetcher = DiagramPrefetcher()
        var processedRequests: [DiagramPrefetcher.Request] = []

        let request = makeRequest(schema: "public", table: "users")

        await prefetcher.setHandler { req in
            processedRequests.append(req)
            return true
        }

        await prefetcher.enqueue(request)
        // Give the internal Task time to process
        try? await Task.sleep(for: .milliseconds(100))

        #expect(processedRequests.count == 1)
        #expect(processedRequests.first?.cacheKey.table == "users")
    }

    @Test func requestsQueuedBeforeHandlerAreProcessed() async {
        let prefetcher = DiagramPrefetcher()
        var processedCount = 0

        let request = makeRequest(schema: "public", table: "orders")

        // Enqueue BEFORE setting handler
        await prefetcher.enqueue(request)

        // Now set handler — should drain the queue
        await prefetcher.setHandler { _ in
            processedCount += 1
            return true
        }

        try? await Task.sleep(for: .milliseconds(200))
        #expect(processedCount == 1)
    }

    @Test func duplicateRequestsAreIgnored() async {
        let prefetcher = DiagramPrefetcher()
        var processedCount = 0

        let request = makeRequest(schema: "public", table: "products")

        await prefetcher.setHandler { _ in
            processedCount += 1
            return true
        }

        await prefetcher.enqueue(request)
        await prefetcher.enqueue(request) // duplicate

        try? await Task.sleep(for: .milliseconds(200))
        #expect(processedCount == 1)
    }

    @Test func cancelAllClearsQueue() async {
        let prefetcher = DiagramPrefetcher()
        var processedCount = 0

        let request1 = makeRequest(schema: "public", table: "a")
        let request2 = makeRequest(schema: "public", table: "b")

        // Enqueue without handler
        await prefetcher.enqueue(request1)
        await prefetcher.enqueue(request2)

        // Cancel all
        await prefetcher.cancelAll()

        // Set handler — queue should be empty
        await prefetcher.setHandler { _ in
            processedCount += 1
            return true
        }

        try? await Task.sleep(for: .milliseconds(100))
        #expect(processedCount == 0)
    }

    @Test func prioritizedRequestProcessedFirst() async {
        let prefetcher = DiagramPrefetcher()
        var processedOrder: [String] = []

        let request1 = makeRequest(schema: "public", table: "first")
        let request2 = makeRequest(schema: "public", table: "priority")

        // Enqueue without handler to accumulate
        await prefetcher.enqueue(request1)
        await prefetcher.enqueue(request2, prioritize: true)

        await prefetcher.setHandler { req in
            processedOrder.append(req.cacheKey.table)
            return true
        }

        try? await Task.sleep(for: .milliseconds(300))
        #expect(processedOrder.first == "priority")
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
