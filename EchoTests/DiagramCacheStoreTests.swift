import XCTest
import CryptoKit
@testable import Echo

final class DiagramCacheStoreTests: XCTestCase {
    private func makeSampleDetails(columnName: String = "id") -> TableStructureDetails {
        let column = TableStructureDetails.Column(
            name: columnName,
            dataType: "int4",
            isNullable: false,
            defaultValue: nil,
            generatedExpression: nil
        )
        return TableStructureDetails(
            columns: [column],
            primaryKey: TableStructureDetails.PrimaryKey(name: "pk", columns: [columnName]),
            indexes: [],
            uniqueConstraints: [],
            foreignKeys: [],
            dependencies: []
        )
    }

    func testDiagramChecksumIsDeterministic() {
        let base = makeSampleDetails(columnName: "id")
        let relatedEntry = DiagramStructureSnapshot.TableEntry(
            schema: "public",
            name: "child",
            details: makeSampleDetails(columnName: "parent_id")
        )

        let checksumA = DiagramChecksum.makeChecksum(base: base, related: [relatedEntry])
        let checksumB = DiagramChecksum.makeChecksum(base: base, related: [relatedEntry])

        XCTAssertEqual(checksumA, checksumB)
    }

    func testCacheManagerStashAndRetrievePayload() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let manager = DiagramCacheStore(configuration: DiagramCacheStore.Configuration(rootDirectory: tempRoot))
        let key = DiagramCacheKey(
            projectID: UUID(),
            connectionID: UUID(),
            schema: "public",
            table: "teams"
        )
        let structure = DiagramStructureSnapshot(
            baseTable: .init(schema: "public", name: "teams", details: makeSampleDetails()),
            relatedTables: []
        )
        await manager.updateKeyProvider { _ in
            let data = Data([0, 1, 2, 3, 4, 5, 6, 7,
                             8, 9, 10, 11, 12, 13, 14, 15,
                             16, 17, 18, 19, 20, 21, 22, 23,
                             24, 25, 26, 27, 28, 29, 30, 31])
            return SymmetricKey(data: data)
        }

        let payload = DiagramCachePayload(
            key: key,
            checksum: "abc123",
            structure: structure,
            layout: DiagramLayoutSnapshot(layoutID: DiagramLayoutSnapshot.defaultLayoutIdentifier, nodePositions: [])
        )

        try await manager.stashPayload(payload)
        let restored = try await manager.payload(for: key)

        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.key, key)
        XCTAssertEqual(restored?.checksum, "abc123")
    }
}
