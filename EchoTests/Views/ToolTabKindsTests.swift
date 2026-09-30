import Foundation
import Testing
@testable import Echo

@MainActor
@Suite("Tool tab header (TT2)")
struct ToolTabKindsTests {
    @Test func queryAndObjectEditorsHaveNoToolHeader() {
        for kind: WorkspaceTab.Kind in [.query, .structure, .diagram, .psql, .extensionStructure] {
            #expect(!kind.isToolTab)
        }
    }

    @Test func toolsGetTheSharedHeader() {
        for kind: WorkspaceTab.Kind in [.maintenance, .serverSecurity, .errorLog, .profiler, .serverProperties, .schemaDiff] {
            #expect(kind.isToolTab)
        }
    }

    @Test func tabsThatDrawTheirOwnCardsAreNotWrapped() {
        #expect(!WorkspaceTab.Kind.activityMonitor.isToolTab)
        #expect(!WorkspaceTab.Kind.jobQueue.isToolTab)
    }

    /// Every tab built on `TabContentWithPanel` or the query tab's cards can maximise its panel.
    @Test func tabsWithABottomPanelShareMaximising() {
        for kind: WorkspaceTab.Kind in [.query, .maintenance, .mssqlMaintenance, .extendedEvents, .serverSecurity, .serverProperties, .schemaDiff] {
            #expect(kind.hasBottomPanel)
        }
        for kind: WorkspaceTab.Kind in [.structure, .activityMonitor, .jobQueue, .errorLog, .queryBuilder] {
            #expect(!kind.hasBottomPanel)
        }
    }
}
