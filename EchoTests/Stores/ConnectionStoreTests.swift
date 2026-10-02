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

    func testLoadReadsFolderIDs() async throws {
        let folder = TestFixtures.savedFolder(name: "Prod")
        mockRepo.folders = [folder]
        mockRepo.connections = [TestFixtures.savedConnection(folderID: folder.id)]

        try await store.load()

        XCTAssertEqual(store.connections[0].folderID, folder.id)
        XCTAssertEqual(mockRepo.loadFoldersCallCount, 1)
    }

    func testCreateFolderSavesAndNests() async throws {
        let projectID = UUID()
        let parent = try await store.createFolder(name: "Servers", projectID: projectID)
        let child = try await store.createFolder(name: "EU", projectID: projectID, parentFolderID: parent.id)

        XCTAssertEqual(store.folders.count, 2)
        XCTAssertEqual(mockRepo.folders.count, 2)
        XCTAssertEqual(child.parentFolderID, parent.id)
        XCTAssertEqual(store.folders(kind: .connections, projectID: projectID, parentID: nil).map(\.id), [parent.id])
        XCTAssertEqual(store.folders(kind: .connections, projectID: projectID, parentID: parent.id).map(\.id), [child.id])
        XCTAssertEqual(store.folderPath(to: child.id).map(\.name), ["Servers", "EU"])
    }

    func testRenameFolder() async throws {
        let folder = try await store.createFolder(name: "Old", projectID: nil)
        try await store.renameFolder(folder.id, to: "  New  ")
        XCTAssertEqual(store.folders[0].name, "New")

        try await store.renameFolder(folder.id, to: "   ")
        XCTAssertEqual(store.folders[0].name, "New")
    }

    func testDeleteFolderMovesContentsToParent() async throws {
        let projectID = UUID()
        let parent = try await store.createFolder(name: "Parent", projectID: projectID)
        let doomed = try await store.createFolder(name: "Doomed", projectID: projectID, parentFolderID: parent.id)
        let child = try await store.createFolder(name: "Child", projectID: projectID, parentFolderID: doomed.id)
        let connection = TestFixtures.savedConnection(projectID: projectID, folderID: doomed.id)
        try await store.addConnection(connection)

        try await store.deleteFolder(doomed)

        XCTAssertNil(store.folder(id: doomed.id))
        XCTAssertEqual(store.folder(id: child.id)?.parentFolderID, parent.id)
        XCTAssertEqual(store.connections.first { $0.id == connection.id }?.folderID, parent.id)
        XCTAssertEqual(mockRepo.connections.first { $0.id == connection.id }?.folderID, parent.id)
    }

    func testDeleteTopLevelFolderMovesConnectionsToTopLevel() async throws {
        let folder = try await store.createFolder(name: "Top", projectID: nil)
        let connection = TestFixtures.savedConnection(folderID: folder.id)
        try await store.addConnection(connection)

        try await store.deleteFolder(folder)

        XCTAssertTrue(store.folders.isEmpty)
        XCTAssertNil(store.connections[0].folderID)
    }

    func testDeleteFolderWithoutReparentingLeavesContents() async throws {
        let folder = try await store.createFolder(name: "Synced", projectID: nil)
        let connection = TestFixtures.savedConnection(folderID: folder.id)
        try await store.addConnection(connection)

        try await store.deleteFolder(folder, reparentContents: false)

        XCTAssertEqual(store.connections[0].folderID, folder.id)
        XCTAssertNil(store.effectiveFolderID(of: store.connections[0]))
    }

    func testMoveConnections() async throws {
        let folder = try await store.createFolder(name: "Target", projectID: nil)
        let a = TestFixtures.savedConnection(connectionName: "A")
        let b = TestFixtures.savedConnection(connectionName: "B")
        try await store.addConnection(a)
        try await store.addConnection(b)

        await store.moveConnections([a.id], toFolder: folder.id)
        XCTAssertEqual(store.connections.first { $0.id == a.id }?.folderID, folder.id)
        XCTAssertNil(store.connections.first { $0.id == b.id }?.folderID)
        XCTAssertEqual(mockRepo.connections.first { $0.id == a.id }?.folderID, folder.id)

        await store.moveConnections([a.id], toFolder: nil)
        XCTAssertNil(store.connections.first { $0.id == a.id }?.folderID)
    }

    func testMoveIdentities() async throws {
        let folder = try await store.createFolder(name: "Logins", kind: .identities, projectID: nil)
        let identity = TestFixtures.savedIdentity(name: "Admin")
        try await store.updateIdentity(identity)

        await store.moveIdentities([identity.id], toFolder: folder.id)

        XCTAssertEqual(store.identities[0].folderID, folder.id)
        XCTAssertEqual(store.effectiveFolderID(of: store.identities[0]), folder.id)
    }

    func testMoveFolderRefusesCycles() async throws {
        let outer = try await store.createFolder(name: "Outer", projectID: nil)
        let inner = try await store.createFolder(name: "Inner", projectID: nil, parentFolderID: outer.id)

        let movedIntoChild = await store.moveFolder(outer.id, toParent: inner.id)
        let movedIntoSelf = await store.moveFolder(outer.id, toParent: outer.id)
        XCTAssertFalse(movedIntoChild)
        XCTAssertFalse(movedIntoSelf)
        XCTAssertNil(store.folder(id: outer.id)?.parentFolderID)

        let movedToTop = await store.moveFolder(inner.id, toParent: nil)
        XCTAssertTrue(movedToTop)
        XCTAssertNil(store.folder(id: inner.id)?.parentFolderID)
    }

    func testEffectiveFolderIgnoresMissingOrWrongKindFolder() async throws {
        let identityFolder = try await store.createFolder(name: "Logins", kind: .identities, projectID: nil)
        let inIdentityFolder = TestFixtures.savedConnection(folderID: identityFolder.id)
        let inMissingFolder = TestFixtures.savedConnection(folderID: UUID())

        XCTAssertNil(store.effectiveFolderID(of: inIdentityFolder))
        XCTAssertNil(store.effectiveFolderID(of: inMissingFolder))
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
