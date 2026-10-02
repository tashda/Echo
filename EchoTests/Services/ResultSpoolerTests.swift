import XCTest
import EchoLocalStorage
@testable import Echo

final class ResultSpoolerTests: XCTestCase {
    private var fixture: LocalStorageFixture!
    private var tempRoot: URL!
    private var manager: ResultSpooler!

    override func setUp() async throws {
        fixture = try LocalStorageFixture()
        tempRoot = fixture.directory.appendingPathComponent("Results")
        let config = ResultSpoolConfiguration.defaultConfiguration(rootDirectory: tempRoot)
        manager = ResultSpooler(configuration: config, storage: fixture.storage)
    }

    override func tearDown() async throws {
        await manager.clearAll()
        fixture.cleanup()
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
