import SwiftUI

/// The servers from the owner's screenshots, with Echo's blueprints: postgres18 (five sections),
/// Test MSSQL (eight, or five when grouped) with enough databases to fill the column, and MySQL
/// and SQLite (two each: Databases and Management).
enum LabSDSamples {
    private typealias N = LabSDNodes
    private static let explorer = ColorTokens.Explorer.self

    static func servers(grouping: LabSDGrouping) -> [LabSDServer] { [postgres, mssql(grouping)] }

    static func allTypes(grouping: LabSDGrouping) -> [LabSDServer] { [mssql(grouping), postgres, mysql, sqlite] }

    // MARK: - PostgreSQL

    static let postgres = LabSDServer(id: "pg", name: "postgres18", product: "PostgreSQL 18.3", build: "PostgreSQL 18.3", sections: [
        LabSDSection(id: "databases", title: "Databases", symbol: "cylinder.split.1x2", color: explorer.databaseFolder, nodes: [
            N.database("pg", "employees", tables: ["employees.department", "employees.employee", "employees.salary", "employees.title"]),
            N.database("pg", "k", tables: ["public.notes"]),
            N.database("pg", "lego", tables: ["public.lego_colors", "public.lego_parts", "public.lego_sets"]),
            N.database("pg", "postgres", tables: ["public.pg_stat_statements"]),
        ], menu: [.init(title: "New Database", symbol: "plus"), .divider, .refresh]),
        LabSDSection(id: "security", title: "Security", symbol: "shield", color: explorer.security, nodes: [
            N.folder("pg.login", "Login Roles", symbol: "person.crop.circle", color: explorer.logins,
                     N.items("pg.login", ["k", "postgres", "reporting"], symbol: "person.crop.circle", color: explorer.logins)),
            N.folder("pg.group", "Group Roles", symbol: "person.2.circle", color: explorer.roles,
                     N.items("pg.group", ["pg_monitor", "readers", "writers"], symbol: "person.2.circle", color: explorer.roles)),
        ], menu: [.init(title: "New Login Role", symbol: "person.badge.plus"), .init(title: "New Group Role", symbol: "person.2.badge.plus"), .divider, .refresh],
           loadsOnOpen: true),
        LabSDSection(id: "activity", title: "Activity", symbol: "gauge.high", color: explorer.activityMonitor, nodes:
            [("Sessions", "person.2.wave.2"), ("Locks", "lock"), ("Database Statistics", "cylinder"), ("Operations", "hourglass"),
             ("Queries", "text.magnifyingglass"), ("Replication", "arrow.triangle.2.circlepath"), ("I/O Statistics", "internaldrive"),
             ("WAL", "doc.on.doc"), ("Background Writer", "square.and.pencil"), ("Prepared Transactions", "checklist"), ("Configuration", "slider.horizontal.3")]
            .map { N.tool("pg.act.\($0.0)", $0.0, symbol: $0.1, color: explorer.activityMonitor) },
            menu: [.init(title: "Open Activity Monitor", symbol: "gauge.high")]),
        LabSDSection(id: "management", title: "Management", symbol: "gearshape", color: explorer.management, nodes:
            [("Maintenance", "wrench.and.screwdriver"), ("Back Up Server", "externaldrive.badge.timemachine"), ("Back Up Globals", "globe"), ("PSQL Console", "terminal")]
            .map { N.tool("pg.mgmt.\($0.0)", $0.0, symbol: $0.1) },
            menu: [.init(title: "Maintenance", symbol: "wrench.and.screwdriver"), .init(title: "Back Up Server", symbol: "externaldrive.badge.timemachine")]),
        LabSDSection(id: "tablespaces", title: "Tablespaces", symbol: "square.stack.3d.up", color: explorer.extensions,
                     nodes: N.items("pg.ts", ["pg_default", "pg_global", "fast_ssd"], symbol: "square.stack.3d.up", color: explorer.extensions),
                     menu: [.refresh, .divider, .init(title: "Manage Tablespaces", symbol: "square.stack.3d.up")], loadsOnOpen: true),
    ])

    // MARK: - SQL Server

    static func mssql(_ grouping: LabSDGrouping) -> LabSDServer {
        LabSDServer(id: "ms", name: "Test MSSQL", product: "SQL Server 2022", build: "Microsoft SQL Server 16.0.4250.1",
                    sections: mssqlSections(grouping))
    }

    private static let msDatabases: [LabSDNode] = [
        N.database("ms", "AdventureWorks2022", tables: ["HumanResources.Department", "HumanResources.Employee", "Person.Address", "Person.Person",
                                                        "Production.Product", "Sales.Customer", "Sales.SalesOrderHeader", "Sales.Store"],
                   views: ["HumanResources.vEmployee", "Sales.vSalesPerson"]),
    ] + (["master", "model", "msdb", "tempdb"] + (0..<34).map { String(format: "dbprops_%08X", 0x04361588 &+ UInt32($0) &* 0x0379_2BA1) })
        .map { N.database("ms", $0, tables: ["dbo.sample"]) }

    private static let msTools: [LabSDNode] = [("Activity Monitor", "gauge.high"), ("Extended Events", "list.bullet.rectangle"), ("Database Mail", "envelope"),
                                               ("SQL Profiler", "chart.line.uptrend.xyaxis"), ("Resource Governor", "slider.horizontal.3"),
                                               ("Policy Management", "checkmark.shield"), ("SQL Server Logs", "doc.text")]
        .map { N.tool("ms.tool.\($0.0)", $0.0, symbol: $0.1) }

    private static let msSnapshots = N.folder("ms.snap", "Database Snapshots", symbol: "camera.aperture", color: explorer.databaseSnapshots,
                                              N.items("ms.snap", ["AdventureWorks_snap_0929"], symbol: "camera", color: explorer.databaseSnapshots))
    private static let msSSIS = N.folder("ms.ssis", "Integration Services Catalogs", symbol: "shippingbox", color: explorer.integrationServices,
                                         N.items("ms.ssis", ["SSISDB"], symbol: "folder", color: explorer.integrationServices))
    private static let msLinked = N.folder("ms.linked", "Linked Servers", symbol: "link", color: explorer.linkedServers,
                                           N.items("ms.linked", ["AZURE_SQL", "REPORTING01"], symbol: "link", color: explorer.linkedServers))
    private static let msTriggers = N.folder("ms.trig", "Server Triggers", symbol: "bolt.badge.clock", color: explorer.serverTriggers,
                                             N.items("ms.trig", ["trg_audit_logon"], symbol: "bolt", color: explorer.serverTriggers))

    private static func mssqlSections(_ grouping: LabSDGrouping) -> [LabSDSection] {
        let dbMenu: [LabSDMenuItem] = [.init(title: "New Database", symbol: "plus"), .init(title: "Attach Database", symbol: "paperclip"),
                                       .init(title: "Restore Database", symbol: "arrow.counterclockwise"), .divider, .refresh]
        let security = LabSDSection(id: "security", title: "Security", symbol: "shield", color: explorer.security, nodes: [
            N.folder("ms.logins", "Logins", symbol: "person.2", color: explorer.logins,
                     N.items("ms.logins", ["##MS_PolicyEventProcessingLogin##", "BUILTIN\\Administrators", "echo_app", "sa"], symbol: "person.crop.circle", color: explorer.logins)),
            N.folder("ms.roles", "Server Roles", symbol: "shield", color: explorer.serverRoles,
                     N.items("ms.roles", ["bulkadmin", "dbcreator", "public", "sysadmin"], symbol: "shield", color: explorer.serverRoles)),
            N.folder("ms.creds", "Credentials", symbol: "key", color: explorer.credentials,
                     N.items("ms.creds", ["AzureBackup"], symbol: "key", color: explorer.credentials)),
        ], menu: [.init(title: "New Login", symbol: "person.badge.plus"), .divider, .init(title: "Open Security Management", symbol: "lock.shield"), .refresh],
           loadsOnOpen: true)
        let agent = LabSDSection(id: "agent", title: "Agent Jobs", symbol: "clock", color: explorer.jobs,
                                 nodes: [N.tool("ms.jobqueue", "Agent Jobs Overview", symbol: "list.bullet.rectangle", color: explorer.jobs)]
                                    + N.items("ms.jobs", ["51955A83", "CEC45B01", "41D91DED", "7B311D9B"].map { "agent_test_\($0)" }, symbol: "clock", color: explorer.jobs),
                                 menu: [.init(title: "Open in Tab", symbol: "list.bullet.rectangle"), .init(title: "New Job", symbol: "plus"), .divider, .refresh],
                                 loadsOnOpen: true)
        let management = { (extra: [LabSDNode]) in
            LabSDSection(id: "management", title: "Management", symbol: "gearshape", color: explorer.management, nodes: msTools + extra,
                         menu: [.init(title: "Activity Monitor", symbol: "gauge.high"), .init(title: "Maintenance", symbol: "wrench.and.screwdriver")])
        }
        let objectsMenu: [LabSDMenuItem] = [.init(title: "New Linked Server", symbol: "link.badge.plus"), .init(title: "New Server Trigger", symbol: "bolt"), .divider, .refresh]
        switch grouping {
        case .today:
            return [
                LabSDSection(id: "databases", title: "Databases", symbol: "cylinder.split.1x2", color: explorer.databaseFolder, nodes: msDatabases, menu: dbMenu),
                security,
                LabSDSection(id: "snapshots", title: "Database Snapshots", symbol: "camera.aperture", color: explorer.databaseSnapshots, nodes: msSnapshots.children,
                             menu: [.init(title: "New Snapshot", symbol: "camera.badge.ellipsis"), .refresh]),
                agent, management([]),
                LabSDSection(id: "ssis", title: "Integration Services Catalogs", symbol: "shippingbox", color: explorer.integrationServices, nodes: msSSIS.children),
                LabSDSection(id: "linked", title: "Linked Servers", symbol: "link", color: explorer.linkedServers, nodes: msLinked.children,
                             menu: [.init(title: "New Linked Server", symbol: "link.badge.plus"), .refresh]),
                LabSDSection(id: "triggers", title: "Server Triggers", symbol: "bolt.badge.clock", color: explorer.serverTriggers, nodes: msTriggers.children,
                             menu: [.init(title: "New Server Trigger", symbol: "bolt"), .refresh]),
            ]
        case .ssms:
            return [
                LabSDSection(id: "databases", title: "Databases", symbol: "cylinder.split.1x2", color: explorer.databaseFolder, nodes: msDatabases + [msSnapshots], menu: dbMenu),
                security,
                LabSDSection(id: "objects", title: "Server Objects", symbol: "square.grid.2x2", color: explorer.linkedServers, nodes: [msLinked, msTriggers], menu: objectsMenu),
                agent, management([msSSIS]),
            ]
        case .serverObjects:
            return [
                LabSDSection(id: "databases", title: "Databases", symbol: "cylinder.split.1x2", color: explorer.databaseFolder, nodes: msDatabases, menu: dbMenu),
                security, agent, management([]),
                LabSDSection(id: "objects", title: "Server Objects", symbol: "square.grid.2x2", color: explorer.linkedServers,
                             nodes: [msSnapshots, msSSIS, msLinked, msTriggers], menu: objectsMenu),
            ]
        }
    }

    // MARK: - MySQL and SQLite

    static let mysql = LabSDServer(id: "my", name: "mysql-lab", product: "MySQL 8.4", build: "8.4.2", sections: [
        LabSDSection(id: "databases", title: "Databases", symbol: "cylinder.split.1x2", color: explorer.databaseFolder, nodes: [
            N.database("my", "shop", tables: ["orders", "customers"]), N.database("my", "sakila", tables: ["actor", "film"]),
        ]),
        LabSDSection(id: "management", title: "Management", symbol: "gearshape", color: explorer.management, nodes:
            [("Maintenance", "wrench.and.screwdriver"), ("Server Properties", "gearshape.2"), ("Activity Monitor", "gauge.high")]
            .map { N.tool("my.\($0.0)", $0.0, symbol: $0.1) }),
    ])

    static let sqlite = LabSDServer(id: "lite", name: "notes.sqlite", product: "SQLite 3.46", build: "3.46.0", sections: [
        LabSDSection(id: "databases", title: "Databases", symbol: "cylinder.split.1x2", color: explorer.databaseFolder, nodes: [
            N.database("lite", "main", tables: ["notes", "tags"]),
        ]),
        LabSDSection(id: "management", title: "Management", symbol: "gearshape", color: explorer.management, nodes: [
            N.tool("lite.maintenance", "Maintenance", symbol: "wrench.and.screwdriver"),
        ]),
    ])
}
