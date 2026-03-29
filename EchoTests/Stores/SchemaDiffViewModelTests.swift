import Foundation
import Testing
@testable import Echo

struct SchemaDiffViewModelTests {
    @Test func resolvedSchemasPrefersRequestedSourceAndFindsTarget() {
        let resolved = SchemaDiffViewModel.resolvedSchemas(
            availableSchemas: ["analytics", "mysql", "test"],
            preferredSource: "mysql",
            currentSource: "",
            currentTarget: ""
        )

        #expect(resolved.source == "mysql")
        #expect(resolved.target == "analytics")
    }

    @Test func resolvedSchemasKeepsExistingTargetWhenValid() {
        let resolved = SchemaDiffViewModel.resolvedSchemas(
            availableSchemas: ["a", "b", "c"],
            preferredSource: nil,
            currentSource: "b",
            currentTarget: "c"
        )

        #expect(resolved.source == "b")
        #expect(resolved.target == "c")
    }

    @Test func filteredDiffsApplyStatusTypeAndSearch() {
        let viewModel = SchemaDiffViewModel(
            session: MockDatabaseSession(),
            connectionID: UUID(),
            connectionSessionID: UUID()
        )

        viewModel.diffs = [
            SchemaDiffItem(objectType: "table", objectName: "customers", status: .modified, sourceDDL: "A", targetDDL: "B"),
            SchemaDiffItem(objectType: "view", objectName: "customer_summary", status: .added, sourceDDL: nil, targetDDL: "C"),
            SchemaDiffItem(objectType: "procedure", objectName: "refresh_summary", status: .removed, sourceDDL: "D", targetDDL: nil)
        ]

        viewModel.filterStatus = .modified
        #expect(viewModel.filteredDiffs.map(\.objectName) == ["customers"])

        viewModel.filterStatus = nil
        viewModel.filterObjectType = "view"
        #expect(viewModel.filteredDiffs.map(\.objectName) == ["customer_summary"])

        viewModel.filterObjectType = nil
        viewModel.searchText = "refresh"
        #expect(viewModel.filteredDiffs.map(\.objectName) == ["refresh_summary"])
    }

    @Test func migrationSQLForFilteredDiffsSkipsIdenticalObjects() {
        let viewModel = SchemaDiffViewModel(
            session: MockDatabaseSession(),
            connectionID: UUID(),
            connectionSessionID: UUID()
        )

        viewModel.sourceSchema = "source_db"
        viewModel.targetSchema = "target_db"
        viewModel.diffs = [
            SchemaDiffItem(objectType: "table", objectName: "customers", status: .added, sourceDDL: nil, targetDDL: "CREATE TABLE customers (id INT);"),
            SchemaDiffItem(objectType: "view", objectName: "customer_summary", status: .identical, sourceDDL: "same", targetDDL: "same")
        ]

        let sql = viewModel.generateMigrationSQLForFilteredDiffs()

        #expect(sql.contains("CREATE TABLE customers"))
        #expect(!sql.contains("No changes needed"))
    }

    @Test func migrationExportFilenameReflectsSchemaSelection() {
        let viewModel = SchemaDiffViewModel(
            session: MockDatabaseSession(),
            connectionID: UUID(),
            connectionSessionID: UUID()
        )

        viewModel.sourceSchema = "inventory"
        viewModel.targetSchema = "inventory_next"

        #expect(viewModel.migrationExportFilename == "schema-diff-inventory-to-inventory_next.sql")
    }
}
