import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("DetachDatabaseSheet")
struct DetachDatabaseSheetTests {

    // MARK: - System Database Detection

    @Test func systemDatabasesAreDetected() {
        #expect(DetachDatabaseSheet.isSystemDatabase("master") == true)
        #expect(DetachDatabaseSheet.isSystemDatabase("tempdb") == true)
        #expect(DetachDatabaseSheet.isSystemDatabase("model") == true)
        #expect(DetachDatabaseSheet.isSystemDatabase("msdb") == true)
    }

    @Test func systemDatabaseDetectionIsCaseInsensitive() {
        #expect(DetachDatabaseSheet.isSystemDatabase("Master") == true)
        #expect(DetachDatabaseSheet.isSystemDatabase("TEMPDB") == true)
        #expect(DetachDatabaseSheet.isSystemDatabase("Model") == true)
        #expect(DetachDatabaseSheet.isSystemDatabase("MSDB") == true)
    }

    @Test func userDatabasesAreNotSystem() {
        #expect(DetachDatabaseSheet.isSystemDatabase("AdventureWorks") == false)
        #expect(DetachDatabaseSheet.isSystemDatabase("MyApp") == false)
        #expect(DetachDatabaseSheet.isSystemDatabase("") == false)
    }

    // MARK: - Skip Checks Logic

    @Test func skipChecksWhenUpdateStatisticsDisabled() {
        #expect(DetachDatabaseSheet.shouldSkipChecks(updateStatistics: false) == true)
    }

    @Test func doNotSkipChecksWhenUpdateStatisticsEnabled() {
        #expect(DetachDatabaseSheet.shouldSkipChecks(updateStatistics: true) == false)
    }

    // MARK: - System Databases Set

    @Test func systemDatabaseSetContainsExactlyFourEntries() {
        #expect(DetachDatabaseSheet.systemDatabases.count == 4)
    }
}
