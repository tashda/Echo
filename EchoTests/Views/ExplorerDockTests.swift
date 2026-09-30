import CoreGraphics
import Foundation
import Testing
@testable import Echo

@MainActor
@Suite("Explorer section dock")
struct ExplorerDockTests {
    private let session: ConnectionSession = {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ExplorerDockTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return ConnectionSession(
            connection: TestFixtures.savedConnection(connectionName: "Test"),
            session: MockDatabaseSession(),
            spoolManager: ResultSpooler(configuration: .defaultConfiguration(rootDirectory: root))
        )
    }()

    private func leaf(_ id: String) -> ObjectBrowserNode { ObjectBrowserNode(id: id, row: .placeholder(id, kind: nil)) }

    private func folder(_ id: String, _ kind: ExplorerNodeKind, children: [ObjectBrowserNode]) -> ObjectBrowserNode {
        ObjectBrowserNode(id: id, row: .folder(ExplorerFolder(kind: kind, session: session, databaseName: nil, count: children.count, isLoading: false, source: nil)), children: children)
    }

    private func server(_ kinds: [ExplorerNodeKind]) -> ObjectBrowserNode {
        let folders = kinds.enumerated().map { index, kind in folder("f\(index)", kind, children: [leaf("f\(index).a"), leaf("f\(index).b")]) }
        return ObjectBrowserNode(id: "server", row: .server(session), children: folders)
    }

    private var connectionID: UUID { session.connection.id }

    private func dockLayout(_ roots: [ObjectBrowserNode]) -> ExplorerDockLayout? {
        guard case .dock(_, let layout, _) = roots[0].children.first?.row else { return nil }
        return layout
    }

    @Test func serverShowsItsDockAndTheFirstSectionByDefault() {
        let roots = ExplorerDock.apply(to: [server([.databases, .serverSecurity, .agentJobs])], selections: [:])
        let children = roots[0].children
        #expect(children.first?.id == ExplorerDock.dockNodeID(connectionID))
        #expect(children.dropFirst().map(\.id) == ["f0.a", "f0.b"])
    }

    @Test func aSavedSelectionShowsThatSection() {
        let roots = ExplorerDock.apply(to: [server([.databases, .serverSecurity, .agentJobs])], selections: [connectionID: "f1"])
        #expect(roots[0].children.dropFirst().map(\.id) == ["f1.a", "f1.b"])
    }

    @Test func aStaleSelectionFallsBackToTheFirstSection() {
        let roots = ExplorerDock.apply(to: [server([.databases, .serverSecurity])], selections: [connectionID: "gone"])
        #expect(roots[0].children.dropFirst().map(\.id) == ["f0.a", "f0.b"])
    }

    @Test func withNoChoiceEverySectionIsInTheCapsule() throws {
        let kinds: [ExplorerNodeKind] = [.databases, .serverSecurity, .databaseSnapshots, .agentJobs, .management, .integrationServices]
        let layout = try #require(dockLayout(ExplorerDock.apply(to: [server(kinds)], selections: [:])))
        #expect(layout.shown.map(\.key) == kinds.map(\.rawValue))
        #expect(layout.overflow.isEmpty)
    }

    @Test func aSavedDockSetsTheCapsuleAndTheRestGoUnderMore() throws {
        let kinds: [ExplorerNodeKind] = [.databases, .serverSecurity, .agentJobs, .management]
        let saved = [ExplorerNodeKind.agentJobs.rawValue, ExplorerNodeKind.databases.rawValue]
        let layout = try #require(dockLayout(ExplorerDock.apply(to: [server(kinds)], selections: [:], savedKeys: { _ in saved })))
        #expect(layout.shown.map(\.key) == saved)
        #expect(layout.overflow.map(\.key) == [ExplorerNodeKind.serverSecurity.rawValue, ExplorerNodeKind.management.rawValue])
    }

    @Test func aSectionUnderMoreCanBeShown() {
        let kinds: [ExplorerNodeKind] = [.databases, .serverSecurity, .agentJobs]
        let roots = ExplorerDock.apply(to: [server(kinds)], selections: [connectionID: "f2"], savedKeys: { _ in [ExplorerNodeKind.databases.rawValue] })
        #expect(roots[0].children.dropFirst().map(\.id) == ["f2.a", "f2.b"])
    }

    @Test func arrangeKeepsTheSavedOrderAndDropsUnknownKeys() {
        let arranged = ExplorerDock.arrange(keys: ["a", "b", "c", "d"], saved: ["c", "gone", "a"], preferred: ["a", "b"])
        #expect(arranged.shown == ["c", "a"])
        #expect(arranged.overflow == ["b", "d"])
    }

    @Test func arrangeFallsBackToTheBlueprintThenToEverything() {
        #expect(ExplorerDock.arrange(keys: ["a", "b", "c"], saved: nil, preferred: ["b"]).shown == ["b"])
        #expect(ExplorerDock.arrange(keys: ["a", "b", "c"], saved: nil, preferred: nil).shown == ["a", "b", "c"])
    }

    @Test func theCapsuleIsNeverEmpty() {
        let arranged = ExplorerDock.arrange(keys: ["a", "b"], saved: ["gone"], preferred: nil)
        #expect(arranged.shown == ["a", "b"])
        #expect(arranged.overflow.isEmpty)
    }

    @Test func aSingleSectionKeepsTheTree() {
        let original = server([.databases])
        let roots = ExplorerDock.apply(to: [original], selections: [:])
        #expect(roots[0].children.map(\.id) == ["f0"])
    }

    @Test func serverAndDockPinAsOneHeader() {
        let roots = ExplorerDock.apply(to: [server([.databases, .serverSecurity])], selections: [:])
        let layout = ExplorerTreeLayout(roots: roots, expandedNodeIDs: ["server"], baseRowHeight: 24)
        let groups = layout.groups
        #expect(groups.count == 1)
        #expect(groups[0].header.map(\.id) == ["server", ExplorerDock.dockNodeID(connectionID)])
        #expect(groups[0].rows.map(\.id) == ["f0.a", "f0.b"])
        #expect(layout.rows.map(\.depth) == [0, 0, 0, 0])
    }
}
