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

    private func serverFolderKinds(_ blueprint: ExplorerBlueprint) -> [ExplorerNodeKind] {
        blueprint.server.compactMap(\.kind)
    }

    /// Round 19: SSMS's grouping in five sections.
    @Test func sqlServerFoldersFollowSSMSInFive() {
        #expect(serverFolderKinds(.sqlServer) == [.databases, .serverSecurity, .serverObjects, .agentJobs, .management])
    }

    /// Round 19: no database type has more than five server-level sections.
    @Test(arguments: DatabaseType.allCases)
    func noTypeHasMoreThanFiveSections(_ databaseType: DatabaseType) {
        #expect(ExplorerBlueprint.blueprint(for: databaseType).server.count <= ExplorerDock.capsuleLimit)
    }

    @Test func databaseSnapshotsFollowTheDatabases() throws {
        let nodes = build(makeSession(.microsoftSQL), ObjectBrowserSidebarViewModel())
        let databases = try #require(nodes.first)
        #expect(databases.children.first.map { if case .database = $0.row { true } else { false } } == true)
        #expect(databases.children.last.flatMap(folder)?.kind == .databaseSnapshots)
        #expect(folder(databases)?.count == 1)
    }

    @Test func serverObjectsHoldLinkedServersAndServerTriggers() throws {
        let nodes = build(makeSession(.microsoftSQL), ObjectBrowserSidebarViewModel())
        let objects = try #require(nodes.first { folder($0)?.kind == .serverObjects })
        #expect(objects.children.compactMap { folder($0)?.kind } == [.linkedServers, .serverTriggers])
        let management = try #require(nodes.first { folder($0)?.kind == .management })
        #expect(management.children.last.flatMap(folder)?.kind == .integrationServices)
    }

    /// Round 16: PostgreSQL's server tools became sections.
    @Test func postgresHasActivityManagementAndTablespaces() {
        #expect(serverFolderKinds(.postgreSQL) == [.databases, .serverSecurity, .activity, .management, .tablespaces])
    }

    @Test func everyTypeDocksAllItsSectionsByDefault() {
        for type in DatabaseType.allCases {
            #expect(ExplorerBlueprint.blueprint(for: type).dock == nil)
        }
    }

    @Test func postgresActivityToolsOpenEveryMonitorPage() throws {
        let nodes = build(makeSession(.postgresql), ObjectBrowserSidebarViewModel())
        let activity = try #require(nodes.first { folder($0)?.kind == .activity })
        let pages = activity.children.compactMap { node -> PostgresActivityMonitorView.PostgresActivitySection? in
            guard case .action(_, let kind) = node.row else { return nil }
            return ObjectBrowserSidebarView.postgresActivityPage(for: kind)
        }
        #expect(pages == PostgresActivityMonitorView.PostgresActivitySection.allCases.filter { pages.contains($0) })
        #expect(Set(pages) == Set(PostgresActivityMonitorView.PostgresActivitySection.allCases))
    }

    @Test func postgresManagementHoldsTheServerTools() throws {
        let nodes = build(makeSession(.postgresql), ObjectBrowserSidebarViewModel())
        let management = try #require(nodes.first { folder($0)?.kind == .management })
        let tools: [ExplorerNodeKind] = management.children.compactMap {
            if case .action(_, let kind) = $0.row { kind } else { nil }
        }
        #expect(tools == [.maintenance, .backUpServer, .backUpGlobals, .psqlConsole])
    }

    @Test func mySQLAndSQLiteKeepToolsUnderManagement() {
        #expect(serverFolderKinds(.mySQL) == [.databases, .management])
        #expect(serverFolderKinds(.sqlite) == [.databases, .management])
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

    @Test func serverChildrenAreFoldersInBlueprintOrder() {
        let nodes = build(makeSession(.microsoftSQL), ObjectBrowserSidebarViewModel())
        #expect(nodes.compactMap { folder($0)?.kind } == serverFolderKinds(.sqlServer))
        #expect(nodes.allSatisfy { if case .folder = $0.row { true } else { false } })
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

    @Test func aLoadingSectionShowsASpinnerRowAfterItsTools() throws {
        let session = makeSession(.microsoftSQL)
        let viewModel = ObjectBrowserSidebarViewModel()
        viewModel.beginLoading(ExplorerSourceKey(connectionID: session.connection.id, source: .agentJobs))

        let jobs = try #require(build(session, viewModel).first { folder($0)?.kind == .agentJobs })
        #expect(folder(jobs)?.isLoading == true)
        #expect(jobs.children.count == 2)
        if case .action(_, let kind) = jobs.children[0].row { #expect(kind == .jobQueue) } else { Issue.record("Expected the job queue tool") }
        if case .loading(_, .spinnerRow) = jobs.children[1].row {} else { Issue.record("Expected a spinner row") }
    }

    /// Folders first (round 16): while a server connects, its sections are there and Databases
    /// says it is loading.
    @Test func aConnectingServerShowsItsSectionsWithDatabasesLoading() throws {
        let session = makeSession(.microsoftSQL)
        session.databaseStructure = nil
        session.structureLoadingState = .loading(progress: 0)
        let nodes = build(session, ObjectBrowserSidebarViewModel())
        #expect(nodes.compactMap { folder($0)?.kind } == serverFolderKinds(.sqlServer))
        let databases = try #require(nodes.first)
        #expect(folder(databases)?.isLoading == true)
        #expect(folder(databases)?.count == nil)
        if case .loading(let title, .spinnerRow) = try #require(databases.children.first).row {
            #expect(title == "Loading databases")
        } else {
            Issue.record("Expected a spinner row")
        }
    }

    /// Round 30.3: Tables, Views, Functions and Procedures always show; an empty one opens to a
    /// grey "No views" row, and the rarer folders still hide when empty.
    @Test func mainObjectFoldersShowEvenWhenEmpty() throws {
        let session = makeSession(.microsoftSQL)
        let table = SchemaObjectInfo(name: "orders", schema: "dbo", type: .table)
        session.databaseStructure = DatabaseStructure(serverVersion: nil, databases: [
            DatabaseInfo(name: "AdventureWorks", schemas: [SchemaInfo(name: "dbo", objects: [table])]),
        ])
        let viewModel = ObjectBrowserSidebarViewModel()
        // Only an open database builds its folders.
        viewModel.expandedNodeIDs.insert(ObjectBrowserSidebarViewModel.databaseNodeID(connectionID: session.connection.id, databaseName: "AdventureWorks"))
        let databases = try #require(build(session, viewModel).first)
        let database = try #require(databases.children.first { if case .database = $0.row { true } else { false } })
        let kinds = database.children.compactMap { folder($0)?.kind }
        #expect(kinds.contains(.views))
        #expect(kinds.contains(.functions))
        #expect(kinds.contains(.procedures))
        #expect(!kinds.contains(.synonyms))
        let views = try #require(database.children.first { folder($0)?.kind == .views })
        #expect(folder(views)?.count == 0)
        guard case .placeholder(let title, _) = try #require(views.children.first).row else {
            Issue.record("An empty Views folder should open to a grey row")
            return
        }
        #expect(title == "No views")
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
