import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("AttachDatabaseSheet")
struct AttachDatabaseSheetTests {

    // MARK: - Validation

    @Test func cannotAttachWithEmptyPath() {
        #expect(AttachDatabaseSheet.isAttachValid(filePath: "", databaseName: "MyDB", isAttaching: false) == false)
    }

    @Test func cannotAttachWithWhitespacePath() {
        #expect(AttachDatabaseSheet.isAttachValid(filePath: "   ", databaseName: "MyDB", isAttaching: false) == false)
    }

    @Test func cannotAttachWithEmptyName() {
        #expect(AttachDatabaseSheet.isAttachValid(filePath: "/data/MyDB.mdf", databaseName: "", isAttaching: false) == false)
    }

    @Test func cannotAttachWithWhitespaceName() {
        #expect(AttachDatabaseSheet.isAttachValid(filePath: "/data/MyDB.mdf", databaseName: "   ", isAttaching: false) == false)
    }

    @Test func cannotAttachWhileAlreadyAttaching() {
        #expect(AttachDatabaseSheet.isAttachValid(filePath: "/data/MyDB.mdf", databaseName: "MyDB", isAttaching: true) == false)
    }

    @Test func canAttachWithValidPathAndName() {
        #expect(AttachDatabaseSheet.isAttachValid(filePath: "/data/MyDB.mdf", databaseName: "MyDB", isAttaching: false) == true)
    }

    @Test func canAttachTrimsWhitespaceForValidation() {
        // Path and name with leading/trailing whitespace but non-empty trimmed content
        #expect(AttachDatabaseSheet.isAttachValid(filePath: "  /data/MyDB.mdf  ", databaseName: "  MyDB  ", isAttaching: false) == true)
    }

    // MARK: - Database Name from File Path

    @Test func databaseNameFromMdfFile() {
        let url = URL(fileURLWithPath: "/var/opt/mssql/data/AdventureWorks.mdf")
        #expect(AttachDatabaseSheet.databaseNameFromFilePath(url) == "AdventureWorks")
    }

    @Test func databaseNameStripsExtension() {
        let url = URL(fileURLWithPath: "/data/MyDatabase.mdf")
        #expect(AttachDatabaseSheet.databaseNameFromFilePath(url) == "MyDatabase")
    }

    @Test func databaseNameFromNestedPath() {
        let url = URL(fileURLWithPath: "/mnt/sql/backups/Production_DB.mdf")
        #expect(AttachDatabaseSheet.databaseNameFromFilePath(url) == "Production_DB")
    }

    @Test func databaseNameFromFileWithMultipleDots() {
        let url = URL(fileURLWithPath: "/data/My.Database.v2.mdf")
        #expect(AttachDatabaseSheet.databaseNameFromFilePath(url) == "My.Database.v2")
    }
}
