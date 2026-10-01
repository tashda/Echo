import Foundation
import Testing
@testable import Echo

@Suite("Workspace toolbar context")
struct WorkspaceToolbarContextTests {
    @Test func queryTabsShowRunAndEditorActions() {
        let context = WorkspaceToolbarContext(kind: .query, databaseType: .postgresql)
        #expect(context.isQuery && !context.hasDatabaseToggles)
    }

    @Test func sqlServerQueryTabsShowToggles() {
        #expect(WorkspaceToolbarContext(kind: .query, databaseType: .microsoftSQL).hasDatabaseToggles)
    }

    /// A tool tab's buttons come from its own toolbar section (round 37.5), never Run, the editor's
    /// actions or the SQL Server toggles.
    @Test func toolTabsGetNoneOfTheEditorsToolbar() {
        for kind in WorkspaceTab.Kind.allCases where kind != .query {
            let context = WorkspaceToolbarContext(kind: kind, databaseType: .microsoftSQL)
            #expect(!context.isQuery && !context.hasDatabaseToggles)
        }
    }

    @Test func noTabShowsNeither() {
        // A schema diff neither runs queries nor reloads (round 34: a diagram reloads, so it shows Refresh).
        #expect(WorkspaceToolbarContext(kind: nil, databaseType: nil) == WorkspaceToolbarContext(kind: .schemaDiff, databaseType: nil))
    }
}
