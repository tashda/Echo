import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("CreateSnapshotSheet")
struct CreateSnapshotSheetTests {

    // MARK: - Validation

    @Test func cannotCreateWithEmptySourceDatabase() {
        #expect(CreateSnapshotSheet.isCreateValid(sourceDatabase: "", snapshotName: "snap", isCreating: false) == false)
    }

    @Test func cannotCreateWithEmptySnapshotName() {
        #expect(CreateSnapshotSheet.isCreateValid(sourceDatabase: "MyDB", snapshotName: "", isCreating: false) == false)
    }

    @Test func cannotCreateWithWhitespaceSnapshotName() {
        #expect(CreateSnapshotSheet.isCreateValid(sourceDatabase: "MyDB", snapshotName: "   ", isCreating: false) == false)
    }

    @Test func cannotCreateWhileAlreadyCreating() {
        #expect(CreateSnapshotSheet.isCreateValid(sourceDatabase: "MyDB", snapshotName: "snap", isCreating: true) == false)
    }

    @Test func canCreateWithValidInputs() {
        #expect(CreateSnapshotSheet.isCreateValid(sourceDatabase: "MyDB", snapshotName: "MyDB_Snapshot", isCreating: false) == true)
    }

    @Test func canCreateTrimsWhitespaceOnSnapshotName() {
        // Name has content after trimming
        #expect(CreateSnapshotSheet.isCreateValid(sourceDatabase: "MyDB", snapshotName: "  snap  ", isCreating: false) == true)
    }

    // MARK: - Snapshot Name Generation

    @Test func snapshotNameIncludesDatabaseName() {
        let name = CreateSnapshotSheet.generateSnapshotName(from: "AdventureWorks")
        #expect(name.hasPrefix("AdventureWorks_Snapshot_"))
    }

    @Test func snapshotNameIncludesDateTimestamp() {
        // Use a fixed date to verify format
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 24
        components.hour = 14
        components.minute = 30
        components.second = 45
        let calendar = Calendar(identifier: .gregorian)
        let fixedDate = calendar.date(from: components)!

        let name = CreateSnapshotSheet.generateSnapshotName(from: "MyDB", date: fixedDate)
        #expect(name == "MyDB_Snapshot_20260324_143045")
    }

    @Test func snapshotNameFormatConsistency() {
        let name = CreateSnapshotSheet.generateSnapshotName(from: "TestDB")
        // Should match pattern: DatabaseName_Snapshot_YYYYMMDD_HHmmss
        let parts = name.split(separator: "_")
        #expect(parts.count == 4)
        #expect(parts[0] == "TestDB")
        #expect(parts[1] == "Snapshot")
        // Date part should be 8 digits
        #expect(parts[2].count == 8)
        // Time part should be 6 digits
        #expect(parts[3].count == 6)
    }

    @Test func snapshotNameWithSpecialCharactersInDatabaseName() {
        let name = CreateSnapshotSheet.generateSnapshotName(from: "My-DB_v2")
        #expect(name.hasPrefix("My-DB_v2_Snapshot_"))
    }
}
