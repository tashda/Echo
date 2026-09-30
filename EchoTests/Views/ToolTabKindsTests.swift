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
}
