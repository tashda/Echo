import Foundation
import Testing
@testable import Echo

@MainActor
@Suite("Tool tab header (TT2)")
struct ToolTabKindsTests {
    @Test func editorsHaveNoToolHeader() {
        for kind: WorkspaceTab.Kind in [.query, .psql] {
            #expect(!kind.isToolTab)
        }
    }

    /// Round 37.1: the structure editor, the diagram and extension details get the shared header too.
    @Test func toolsGetTheSharedHeader() {
        for kind: WorkspaceTab.Kind in [.maintenance, .serverSecurity, .errorLog, .profiler, .serverProperties, .schemaDiff,
                                        .structure, .diagram, .extensionStructure] {
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
