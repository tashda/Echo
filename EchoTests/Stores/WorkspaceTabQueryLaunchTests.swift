import Foundation
import Testing
@testable import Echo

@MainActor
@Suite("WorkspaceTabQueryLaunch")
struct WorkspaceTabQueryLaunchTests {
    @Test func configureQueryLaunchEnablesAutoExecution() throws {
        let tab = makeQueryTab()

        tab.configureQueryLaunch(autoExecute: true)

        #expect(tab.query?.shouldAutoExecuteOnAppear == true)
    }

    @Test func configureQueryLaunchLeavesAutoExecutionDisabledWhenRequested() throws {
        let tab = makeQueryTab()

        tab.configureQueryLaunch(autoExecute: false)

        #expect(tab.query?.shouldAutoExecuteOnAppear == false)
    }

    private func makeQueryTab() -> WorkspaceTab {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkspaceTabQueryLaunchTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let spoolManager = ResultSpooler(
            configuration: .defaultConfiguration(rootDirectory: tempRoot)
        )
        let queryState = QueryEditorState(sql: "SELECT 1", spoolManager: spoolManager)
        return WorkspaceTab(
            connection: TestFixtures.savedConnection(databaseType: .mysql),
            session: MockDatabaseSession(),
            connectionSessionID: UUID(),
            title: "Query",
            content: .query(queryState)
        )
    }
}
