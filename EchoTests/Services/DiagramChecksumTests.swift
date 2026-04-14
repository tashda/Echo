import XCTest
@testable import Echo

final class DiagramChecksumTests: XCTestCase {

    // MARK: - Determinism

    func testSameInputSameChecksum() {
        let details = TestFixtures.tableStructureDetails(columnCount: 3, primaryKeyName: "pk")
        let related: [DiagramStructureSnapshot.TableEntry] = []

        let checksum1 = DiagramChecksum.makeChecksum(base: details, related: related)
        let checksum2 = DiagramChecksum.makeChecksum(base: details, related: related)

        XCTAssertEqual(checksum1, checksum2, "Same input should produce same checksum")
    }

    // MARK: - Sensitivity

    func testDifferentColumnsProduceDifferentChecksum() {
        let details1 = TestFixtures.tableStructureDetails(columnCount: 3)
        let details2 = TestFixtures.tableStructureDetails(columnCount: 5)

        let checksum1 = DiagramChecksum.makeChecksum(base: details1, related: [])
        let checksum2 = DiagramChecksum.makeChecksum(base: details2, related: [])

        XCTAssertNotEqual(checksum1, checksum2, "Different column counts should produce different checksums")
    }

    func testDifferentPrimaryKeyProducesDifferentChecksum() {
        let details1 = TestFixtures.tableStructureDetails(primaryKeyName: "pk_a")
        let details2 = TestFixtures.tableStructureDetails(primaryKeyName: "pk_b")

        let checksum1 = DiagramChecksum.makeChecksum(base: details1, related: [])
        let checksum2 = DiagramChecksum.makeChecksum(base: details2, related: [])

        XCTAssertNotEqual(checksum1, checksum2)
    }

    // MARK: - Related Table Ordering

    func testRelatedTableOrderDoesNotAffectChecksum() {
        let base = TestFixtures.tableStructureDetails(columnCount: 2)

        let relatedA = DiagramStructureSnapshot.TableEntry(
            schema: "public",
            name: "a_table",
            details: TestFixtures.tableStructureDetails(columnCount: 2)
        )
        let relatedB = DiagramStructureSnapshot.TableEntry(
            schema: "public",
            name: "b_table",
            details: TestFixtures.tableStructureDetails(columnCount: 3)
        )

        let checksum1 = DiagramChecksum.makeChecksum(base: base, related: [relatedA, relatedB])
        let checksum2 = DiagramChecksum.makeChecksum(base: base, related: [relatedB, relatedA])

        XCTAssertEqual(checksum1, checksum2, "Related table order should not affect checksum (sorted internally)")
    }

    // MARK: - With Foreign Keys

    func testForeignKeysAffectChecksum() {
        let fk = TableStructureDetails.ForeignKey(
            name: "fk_user",
            columns: ["user_id"],
            referencedSchema: "public",
            referencedTable: "users",
            referencedColumns: ["id"],
            onUpdate: nil,
            onDelete: nil
        )
        let detailsWithFK = TestFixtures.tableStructureDetails(foreignKeys: [fk])
        let detailsWithoutFK = TestFixtures.tableStructureDetails()

        let checksum1 = DiagramChecksum.makeChecksum(base: detailsWithFK, related: [])
        let checksum2 = DiagramChecksum.makeChecksum(base: detailsWithoutFK, related: [])

        XCTAssertNotEqual(checksum1, checksum2)
    }
}
