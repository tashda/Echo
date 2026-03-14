import XCTest
@testable import Echo

@MainActor
final class ConnectionStoreTests: XCTestCase {
    private var mockRepo: MockConnectionRepository!
    private var store: ConnectionStore!

    override func setUp() async throws {
        mockRepo = MockConnectionRepository()
        store = ConnectionStore(repository: mockRepo)
    }

    // MARK: - Load

    func testLoadPopulatesFromRepository() async throws {
        let conn = TestFixtures.savedConnection(connectionName: "Prod")
        let folder = TestFixtures.savedFolder(name: "DevOps")
        let identity = TestFixtures.savedIdentity(name: "Admin")

        mockRepo.connections = [conn]
        mockRepo.folders = [folder]
        mockRepo.identities = [identity]

        try await store.load()

        XCTAssertEqual(store.connections.count, 1)
        XCTAssertEqual(store.connections[0].connectionName, "Prod")
        XCTAssertEqual(store.folders.count, 1)
        XCTAssertEqual(store.identities.count, 1)
    }

    // MARK: - Connection CRUD

    func testAddConnection() async throws {
        let conn = TestFixtures.savedConnection(connectionName: "New")
        try await store.addConnection(conn)

        XCTAssertEqual(store.connections.count, 1)
        XCTAssertEqual(mockRepo.saveConnectionsCallCount, 1)
    }

    func testUpdateConnection() async throws {
        var conn = TestFixtures.savedConnection(connectionName: "Old")
        try await store.addConnection(conn)

        conn.connectionName = "Updated"
        try await store.updateConnection(conn)

        XCTAssertEqual(store.connections[0].connectionName, "Updated")
        XCTAssertEqual(mockRepo.saveConnectionsCallCount, 2) // add + update
    }

    func testUpdateConnectionInsertsIfNew() async throws {
        let conn = TestFixtures.savedConnection(connectionName: "New Connection")
        try await store.updateConnection(conn)

        XCTAssertEqual(store.connections.count, 1)
        XCTAssertEqual(store.connections[0].connectionName, "New Connection")
    }

    func testDeleteConnection() async throws {
        let conn = TestFixtures.savedConnection()
        try await store.addConnection(conn)
        XCTAssertEqual(store.connections.count, 1)

        try await store.deleteConnection(conn)
        XCTAssertEqual(store.connections.count, 0)
    }

    // MARK: - Folder CRUD

    func testUpdateFolderInsertsIfNew() async throws {
        let folder = TestFixtures.savedFolder(name: "New Folder")
        try await store.updateFolder(folder)

        XCTAssertEqual(store.folders.count, 1)
        XCTAssertEqual(store.folders[0].name, "New Folder")
    }

    func testDeleteFolder() async throws {
        let folder = TestFixtures.savedFolder(name: "To Delete")
        try await store.updateFolder(folder)
        XCTAssertEqual(store.folders.count, 1)

        try await store.deleteFolder(folder)
        XCTAssertEqual(store.folders.count, 0)
    }

    // MARK: - Identity CRUD

    func testUpdateIdentityInsertsIfNew() async throws {
        let identity = TestFixtures.savedIdentity(name: "New Identity")
        try await store.updateIdentity(identity)

        XCTAssertEqual(store.identities.count, 1)
        XCTAssertEqual(store.identities[0].name, "New Identity")
    }

    func testDeleteIdentity() async throws {
        let identity = TestFixtures.savedIdentity()
        try await store.updateIdentity(identity)
        XCTAssertEqual(store.identities.count, 1)

        try await store.deleteIdentity(identity)
        XCTAssertEqual(store.identities.count, 0)
    }

    // MARK: - Selection

    func testSelectedConnection() async throws {
        let conn = TestFixtures.savedConnection()
        try await store.addConnection(conn)

        store.selectedConnectionID = conn.id
        XCTAssertEqual(store.selectedConnection?.id, conn.id)

        store.selectedConnectionID = nil
        XCTAssertNil(store.selectedConnection)
    }
}
