import Foundation
import Testing
@testable import Echo

@Suite("Workspace toolbar context")
struct WorkspaceToolbarContextTests {
    @Test func queryTabsShowRunAndEditorActions() {
        let context = WorkspaceToolbarContext(kind: .query, databaseType: .postgresql)
        #expect(context.isQuery && !context.hasTabTools && !context.hasDatabaseToggles)
    }

    @Test func sqlServerQueryTabsShowToggles() {
        #expect(WorkspaceToolbarContext(kind: .query, databaseType: .microsoftSQL).hasDatabaseToggles)
    }

    @Test func toolTabsShowTheContextualCapsule() {
        for kind in [WorkspaceTab.Kind.structure, .activityMonitor, .jobQueue, .errorLog, .maintenance, .mssqlMaintenance] {
            let context = WorkspaceToolbarContext(kind: kind, databaseType: .microsoftSQL)
            #expect(context.hasTabTools && !context.isQuery)
        }
    }

    @Test func noTabShowsNeither() {
        #expect(WorkspaceToolbarContext(kind: nil, databaseType: nil) == WorkspaceToolbarContext(kind: .diagram, databaseType: nil))
    }
}
