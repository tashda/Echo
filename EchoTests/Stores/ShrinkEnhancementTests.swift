import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("ShrinkEnhancements")
struct ShrinkEnhancementTests {

    // MARK: - Factory

    private func makeViewModel(database: String? = "testdb") -> MSSQLMaintenanceViewModel {
        let session = MockDatabaseSession()
        return MSSQLMaintenanceViewModel(
            session: session,
            connectionID: UUID(),
            connectionSessionID: UUID(),
            initialDatabase: database
        )
    }

    // MARK: - ShrinkOptionChoice Enum

    @Test func shrinkOptionChoiceHasExpectedCases() {
        let allCases = ShrinkOptionChoice.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.defaultBehavior))
        #expect(allCases.contains(.noTruncate))
        #expect(allCases.contains(.truncateOnly))
    }

    @Test func shrinkOptionChoiceRawValues() {
        #expect(ShrinkOptionChoice.defaultBehavior.rawValue == "Default")
        #expect(ShrinkOptionChoice.noTruncate.rawValue == "No Truncate")
        #expect(ShrinkOptionChoice.truncateOnly.rawValue == "Truncate Only")
    }

    @Test func shrinkOptionChoiceIdentifiable() {
        let defaultOpt = ShrinkOptionChoice.defaultBehavior
        let noTruncate = ShrinkOptionChoice.noTruncate
        let truncateOnly = ShrinkOptionChoice.truncateOnly

        #expect(defaultOpt.id == "Default")
        #expect(noTruncate.id == "No Truncate")
        #expect(truncateOnly.id == "Truncate Only")
        #expect(defaultOpt.id != noTruncate.id)
        #expect(noTruncate.id != truncateOnly.id)
    }

    // MARK: - Default Shrink State

    @Test func defaultShrinkTargetPercent() {
        let vm = makeViewModel()
        #expect(vm.shrinkTargetPercent == 10)
    }

    @Test func defaultShrinkOption() {
        let vm = makeViewModel()
        #expect(vm.shrinkOption == .defaultBehavior)
    }

    @Test func defaultShrinkFileName() {
        let vm = makeViewModel()
        #expect(vm.shrinkFileName == "")
    }

    @Test func defaultShrinkFileTargetMB() {
        let vm = makeViewModel()
        #expect(vm.shrinkFileTargetMB == 0)
    }

    @Test func defaultDatabaseFiles() {
        let vm = makeViewModel()
        #expect(vm.databaseFiles.isEmpty)
    }

    @Test func defaultShrinkingFlags() {
        let vm = makeViewModel()
        #expect(vm.isShrinking == false)
        #expect(vm.isShrinkingFile == false)
        #expect(vm.isLoadingFiles == false)
    }

    // MARK: - Initial ViewModel State

    @Test func initialStateWithDatabase() {
        let vm = makeViewModel(database: "mydb")
        #expect(vm.selectedDatabase == "mydb")
        #expect(vm.selectedSection == .health)
        #expect(vm.databaseList.isEmpty)
        #expect(vm.isInitialLoading == true)
        #expect(vm.isInitialized == false)
        #expect(vm.healthStats == nil)
        #expect(vm.healthPermissionError == nil)
        #expect(vm.isCheckingIntegrity == false)
    }

    @Test func initialStateWithoutDatabase() {
        let vm = makeViewModel(database: nil)
        #expect(vm.selectedDatabase == nil)
    }

    // MARK: - MaintenanceSection Enum

    @Test func maintenanceSectionHasExpectedCases() {
        let allCases = MSSQLMaintenanceViewModel.MaintenanceSection.allCases
        #expect(allCases.count == 5)
        #expect(allCases.contains(.health))
        #expect(allCases.contains(.tables))
        #expect(allCases.contains(.indexes))
        #expect(allCases.contains(.backups))
        #expect(allCases.contains(.queryStore))
    }

    @Test func maintenanceSectionRawValues() {
        #expect(MSSQLMaintenanceViewModel.MaintenanceSection.health.rawValue == "Health")
        #expect(MSSQLMaintenanceViewModel.MaintenanceSection.tables.rawValue == "Tables")
        #expect(MSSQLMaintenanceViewModel.MaintenanceSection.indexes.rawValue == "Indexes")
        #expect(MSSQLMaintenanceViewModel.MaintenanceSection.backups.rawValue == "Backups")
    }

    @Test func maintenanceSectionIdentifiable() {
        let health = MSSQLMaintenanceViewModel.MaintenanceSection.health
        let tables = MSSQLMaintenanceViewModel.MaintenanceSection.tables
        #expect(health.id == "Health")
        #expect(tables.id == "Tables")
        #expect(health.id != tables.id)
    }

    // MARK: - Shrink State Mutation

    @Test func shrinkTargetPercentCanBeSet() {
        let vm = makeViewModel()
        vm.shrinkTargetPercent = 25
        #expect(vm.shrinkTargetPercent == 25)
    }

    @Test func shrinkOptionCanBeChanged() {
        let vm = makeViewModel()
        vm.shrinkOption = .truncateOnly
        #expect(vm.shrinkOption == .truncateOnly)

        vm.shrinkOption = .noTruncate
        #expect(vm.shrinkOption == .noTruncate)
    }

    @Test func shrinkFileNameCanBeSet() {
        let vm = makeViewModel()
        vm.shrinkFileName = "mydb_log"
        #expect(vm.shrinkFileName == "mydb_log")
    }

    @Test func shrinkFileTargetMBCanBeSet() {
        let vm = makeViewModel()
        vm.shrinkFileTargetMB = 512
        #expect(vm.shrinkFileTargetMB == 512)
    }

    // MARK: - Memory Estimation

    @Test func estimatedMemoryUsageBytesBaselineWhenEmpty() {
        let vm = makeViewModel()
        let bytes = vm.estimatedMemoryUsageBytes()
        // Base: 64 * 1024 + 1024 (health) = 66560
        #expect(bytes == 66560)
    }
}
