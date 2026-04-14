import XCTest
@testable import Echo

final class ResultSpoolerTests: XCTestCase {
    private var tempRoot: URL!
    private var manager: ResultSpooler!

    override func setUp() async throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ResultSpoolerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let config = ResultSpoolConfiguration.defaultConfiguration(rootDirectory: tempRoot)
        manager = ResultSpooler(configuration: config)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    // MARK: - Create Spool

    func testMakeSpoolHandle() async throws {
        let handle = try await manager.makeSpoolHandle()
        XCTAssertNotNil(handle)
    }

    func testHandleForID() async throws {
        let handle = try await manager.makeSpoolHandle()
        let found = await manager.handle(for: handle.id)
        XCTAssertNotNil(found)
    }

    func testHandleForNonexistentIDReturnsNil() async {
        let found = await manager.handle(for: UUID())
        XCTAssertNil(found)
    }

    // MARK: - Close and Remove

    func testCloseHandle() async throws {
        let handle = try await manager.makeSpoolHandle()
        let id = await handle.id
        await manager.closeHandle(for: id)

        let found = await manager.handle(for: id)
        XCTAssertNil(found)
    }

    func testRemoveSpool() async throws {
        let handle = try await manager.makeSpoolHandle()
        let id = await handle.id
        await manager.removeSpool(for: id)

        let found = await manager.handle(for: id)
        XCTAssertNil(found)
    }

    // MARK: - Clear All

    func testClearAll() async throws {
        _ = try await manager.makeSpoolHandle()
        _ = try await manager.makeSpoolHandle()

        await manager.clearAll()

        let usage = await manager.currentUsageBytes()
        XCTAssertEqual(usage, 0)
    }

    // MARK: - Usage Tracking

    func testCurrentUsageBytesStartsAtZeroOrSmall() async throws {
        let usage = await manager.currentUsageBytes()
        // Freshly created, should be zero or very small
        XCTAssertLessThan(usage, 1024)
    }
}
