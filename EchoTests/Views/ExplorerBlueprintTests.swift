import AppKit
import Foundation
import Testing
@testable import Echo

@MainActor
@Suite("Explorer Blueprints")
struct ExplorerBlueprintTests {

    // MARK: - Catalogue

    /// A missing symbol name draws nothing, so every kind's symbol must exist.
    @Test(arguments: ExplorerNodeKind.allCases)
    func everyKindHasATitleAndARealSymbol(_ kind: ExplorerNodeKind) {
        #expect(!kind.title.isEmpty)
        #expect(NSImage(systemSymbolName: kind.symbol, accessibilityDescription: nil) != nil, "\(kind.symbol)")
    }

    @Test(arguments: SchemaObjectInfo.ObjectType.allCases)
    func objectFoldersRoundTrip(_ type: SchemaObjectInfo.ObjectType) {
        let kind = ExplorerNodeKind(objectFolderFor: type)
        #expect(kind.objectType == type)
        #expect(kind.title == type.pluralDisplayName)
    }

    // MARK: - Order per database type

    private func sectionKinds(_ blueprint: ExplorerBlueprint) -> [ExplorerNodeKind] {
        blueprint.server.compactMap(\.kind)
    }

    @Test func sqlServerSectionsFollowSSMS() {
        #expect(sectionKinds(.sqlServer) == [
            .databases, .serverSecurity, .databaseSnapshots, .agentJobs, .management,
            .integrationServices, .linkedServers, .serverTriggers,
        ])
    }

    @Test func postgresSectionsAreDatabasesAndSecurity() {
        #expect(sectionKinds(.postgreSQL) == [.databases, .serverSecurity])
    }

    @Test func mySQLAndSQLiteKeepToolsUnderManagement() {
        #expect(sectionKinds(.mySQL) == [.databases, .management])
        #expect(sectionKinds(.sqlite) == [.databases, .management])
    }

    /// The object folders keep the order the tree had before blueprints.
    @Test(arguments: DatabaseType.allCases)
    func objectFoldersFollowTheSupportedTypes(_ databaseType: DatabaseType) throws {
        let blueprint = ExplorerBlueprint.blueprint(for: databaseType)
        guard case .objectFolderList(let kinds) = try #require(blueprint.database.first) else {
            Issue.record("The first database entry should be the object folders")
            return
        }
        #expect(kinds.compactMap(\.objectType) == SchemaObjectInfo.ObjectType.supported(for: databaseType))
    }

    /// Items can only be listed where something loads them.
    @Test(arguments: DatabaseType.allCases)
    func everyItemListHasASource(_ databaseType: DatabaseType) {
        let blueprint = ExplorerBlueprint.blueprint(for: databaseType)
        func check(_ entries: [ExplorerBlueprintNode], source: ExplorerChildSource?) {
            for entry in entries {
                switch entry {
                case .group(_, let own, _, let children):
                    check(children, source: own ?? source)
                case .items(let kind):
                    #expect(source != nil, "\(kind) has no source in \(databaseType)")
                case .onlineOnly(let children):
                    check(children, source: source)
                case .databases, .objectFolderList, .action:
                    break
                }
            }
        }
        check(blueprint.server, source: nil)
        check(blueprint.database, source: nil)
    }

    // MARK: - Saved IDs

    @Test func folderIDsMatchTheOnesSavedBeforeBlueprints() {
        let id = UUID()
        let prefix = id.uuidString
        #expect(ObjectBrowserSidebarViewModel.serverFolderNodeID(connectionID: id, kind: .databases) == "\(prefix)#folder#databases")
        #expect(ObjectBrowserSidebarViewModel.serverFolderNodeID(connectionID: id, kind: .serverSecurity) == "\(prefix)#server-folder#security")
        #expect(ObjectBrowserSidebarViewModel.serverFolderNodeID(connectionID: id, kind: .integrationServices) == "\(prefix)#server-folder#ssis")
        #expect(ObjectBrowserSidebarViewModel.databaseFolderNodeID(connectionID: id, databaseName: "db", kind: .databaseSecurity) == "\(prefix)#db#db#folder#security")
        #expect(ObjectBrowserSidebarViewModel.actionNodeID(connectionID: id, parentID: "p", kind: .jobQueue) == "p#action#openJobQueue")
    }

    // MARK: - Building a server

    private func makeSession(_ databaseType: DatabaseType) -> ConnectionSession {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExplorerBlueprintTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let session = ConnectionSession(
            connection: TestFixtures.savedConnection(databaseType: databaseType),
            session: MockDatabaseSession(),
            spoolManager: ResultSpooler(configuration: .defaultConfiguration(rootDirectory: root))
        )
        session.databaseStructure = DatabaseStructure(serverVersion: nil, databases: [DatabaseInfo(name: "AdventureWorks", schemas: [])])
        session.structureLoadingState = .ready
        return session
    }

    private func build(_ session: ConnectionSession, _ viewModel: ObjectBrowserSidebarViewModel) -> [ObjectBrowserNode] {
        ObjectBrowserSnapshotBuilder.serverChildren(for: session, settings: GlobalSettings(), viewModel: viewModel)
    }

    private func folder(_ node: ObjectBrowserNode) -> ExplorerFolder? {
        switch node.row {
        case .section(let folder), .folder(let folder): folder
        default: nil
        }
    }

    @Test func serverChildrenAreSectionsInBlueprintOrder() {
        let nodes = build(makeSession(.microsoftSQL), ObjectBrowserSidebarViewModel())
        #expect(nodes.compactMap { folder($0)?.kind } == sectionKinds(.sqlServer))
        #expect(nodes.allSatisfy { if case .section = $0.row { true } else { false } })
        #expect(folder(nodes[0])?.count == 1)
    }

    @Test func loadedLoginsFillTheirFoldersAndCertificateLoginsNest() throws {
        let session = makeSession(.microsoftSQL)
        let viewModel = ObjectBrowserSidebarViewModel()
        viewModel.finishLoading(
            ExplorerSourceKey(connectionID: session.connection.id, source: .serverSecurity),
            items: [
                .logins: [ExplorerItem(id: "sa", name: "sa", payload: .login(type: "SQL"))],
                .certificateLogins: [ExplorerItem(id: "cert", name: "cert", payload: .login(type: "Certificate"))],
            ]
        )

        let security = try #require(build(session, viewModel).first { folder($0)?.kind == .serverSecurity })
        let logins = try #require(security.children.first)
        #expect(folder(logins)?.kind == .logins)
        #expect(folder(logins)?.count == 1)
        #expect(logins.children.count == 2)
        #expect(folder(logins.children[1])?.kind == .certificateLogins)
        guard case .placeholder(let title, _) = try #require(security.children[1].children.first).row else {
            Issue.record("Server Roles should say it's empty")
            return
        }
        #expect(title == ExplorerNodeKind.serverRoles.emptyTitle)
    }

    @Test func certificateLoginsHideWhenThereAreNone() throws {
        let session = makeSession(.microsoftSQL)
        let viewModel = ObjectBrowserSidebarViewModel()
        viewModel.finishLoading(
            ExplorerSourceKey(connectionID: session.connection.id, source: .serverSecurity),
            items: [.logins: [ExplorerItem(id: "sa", name: "sa", payload: .login(type: "SQL"))]]
        )
        let security = try #require(build(session, viewModel).first { folder($0)?.kind == .serverSecurity })
        #expect(security.children[0].children.count == 1)
    }

    @Test func aLoadingFolderShowsAShimmerAfterItsTools() throws {
        let session = makeSession(.microsoftSQL)
        let viewModel = ObjectBrowserSidebarViewModel()
        viewModel.beginLoading(ExplorerSourceKey(connectionID: session.connection.id, source: .agentJobs))

        let jobs = try #require(build(session, viewModel).first { folder($0)?.kind == .agentJobs })
        #expect(folder(jobs)?.isLoading == true)
        #expect(jobs.children.count == 2)
        if case .action(_, let kind) = jobs.children[0].row { #expect(kind == .jobQueue) } else { Issue.record("Expected the job queue tool") }
        if case .loading = jobs.children[1].row {} else { Issue.record("Expected a loading row") }
    }

    @Test func mySQLToolsSitUnderManagement() throws {
        let nodes = build(makeSession(.mysql), ObjectBrowserSidebarViewModel())
        let management = try #require(nodes.first { folder($0)?.kind == .management })
        let tools: [ExplorerNodeKind] = management.children.compactMap {
            if case .action(_, let kind) = $0.row { kind } else { nil }
        }
        #expect(tools == [.maintenance, .serverProperties, .activityMonitor])
    }
}
