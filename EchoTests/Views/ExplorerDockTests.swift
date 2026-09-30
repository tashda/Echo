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

    @Test func moreThanFiveSectionsShareMore() throws {
        let kinds: [ExplorerNodeKind] = [.databases, .serverSecurity, .databaseSnapshots, .agentJobs, .management, .integrationServices, .linkedServers, .serverTriggers]
        let items = try #require(ExplorerDock.items(for: server(kinds).children, connectionID: connectionID))
        #expect(items.count == ExplorerDock.buttonLimit + 1)
        #expect(items.last?.id == ExplorerDock.moreItemID(connectionID))
        let roots = ExplorerDock.apply(to: [server(kinds)], selections: [connectionID: ExplorerDock.moreItemID(connectionID)])
        #expect(roots[0].children.dropFirst().map(\.id) == ["f4", "f5", "f6", "f7"])
    }

    @Test func exactlyFiveSectionsNeedNoMore() throws {
        let kinds: [ExplorerNodeKind] = [.databases, .serverSecurity, .databaseSnapshots, .agentJobs, .management]
        let items = try #require(ExplorerDock.items(for: server(kinds).children, connectionID: connectionID))
        #expect(items.count == 5)
        #expect(!items.contains { $0.id == ExplorerDock.moreItemID(connectionID) })
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
