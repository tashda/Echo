import SwiftUI

/// The two servers from the owner's screenshots. SQL Server's sections are Echo's blueprint;
/// PostgreSQL's add the server tools Echo already has (Activity Monitor pages, Maintenance,
/// backup and restore, tablespaces), which today are only reachable from menus.
extension LabSCServer {
    private typealias Nodes = LabSCSampleNodes

    static let mssql: LabSCServer = {
        let explorer = ColorTokens.Explorer.self
        let tmpDatabases = ["tmp_ap_5A1411A1", "tmp_ap_6CE81A59", "tmp_cc_2CE50761", "tmp_cmt_58F42B42", "tmp_cq_1805540E", "tmp_cr_2633391E", "tx_204E94ADDDB3", "tx_58FAB56721A9"]
        let databases = [
            Nodes.database("mssql", "AdventureWorks2022",
                           tables: ["HumanResources.Department", "HumanResources.Employee", "HumanResources.Shift", "Person.Address", "Person.Person", "Production.Product", "Sales.Customer", "Sales.SalesOrderHeader", "Sales.Store"],
                           views: ["HumanResources.vEmployee", "Sales.vSalesPerson"],
                           functions: ["dbo.ufnGetStock"]),
        ] + (["master", "model", "msdb"] + tmpDatabases).map { Nodes.database("mssql", $0, tables: ["dbo.sample"]) }
        let jobs = ["51955A83", "CEC45B01", "41D91DED", "7B311D9B", "35DD92B5", "30CE9D36"].map { "agent_test_\($0)" }
        let tools: [(String, String)] = [("Activity Monitor", "gauge.high"), ("Extended Events", "list.bullet.rectangle"), ("Database Mail", "envelope"), ("SQL Profiler", "chart.line.uptrend.xyaxis"), ("Resource Governor", "slider.horizontal.3"), ("Policy Management", "checkmark.shield"), ("SQL Server Logs", "doc.text")]
        return LabSCServer(
            id: "mssql", name: "Test MSSQL", engine: .sqlServer, rawVersion: "Microsoft SQL Server 16.0.4250.1",
            sections: [
                LabSCSection(id: "databases", title: "Databases", symbol: "cylinder.split.1x2", color: explorer.databaseFolder, nodes: databases,
                             menu: [.init(title: "New Database", symbol: "plus"), .init(title: "Attach Database", symbol: "paperclip"), .init(title: "Restore Database", symbol: "arrow.counterclockwise"), .divider, .init(title: "Hide Offline Databases", symbol: "eye.slash"), .init(title: "Refresh", symbol: "arrow.clockwise")],
                             loadsOnOpen: false),
                LabSCSection(id: "security", title: "Security", symbol: "shield", color: explorer.security, nodes: [
                    Nodes.folder("mssql.logins", "Logins", symbol: "person.2", color: explorer.logins, loadsOnOpen: true, Nodes.leaves("mssql.logins", ["##MS_PolicyEventProcessingLogin##", "BUILTIN\\Administrators", "echo_app", "etl_service", "reporting_ro", "sa", "web_api"], symbol: "person.crop.circle", color: explorer.logins)),
                    Nodes.folder("mssql.roles", "Server Roles", symbol: "shield", color: explorer.serverRoles, Nodes.leaves("mssql.roles", ["bulkadmin", "dbcreator", "public", "securityadmin", "sysadmin"], symbol: "shield", color: explorer.serverRoles)),
                    Nodes.folder("mssql.creds", "Credentials", symbol: "key", color: explorer.credentials, Nodes.leaves("mssql.creds", ["AzureBackup"], symbol: "key", color: explorer.credentials)),
                ], menu: [.init(title: "New Login", symbol: "person.badge.plus"), .divider, .init(title: "Open Security Management", symbol: "lock.shield"), .init(title: "Refresh", symbol: "arrow.clockwise")]),
                LabSCSection(id: "agent", title: "Agent Jobs", symbol: "clock", color: explorer.jobs, nodes: [
                    Nodes.tool("mssql.jobqueue", "Agent Jobs Overview", symbol: "list.bullet.rectangle", color: explorer.jobs),
                ] + Nodes.leaves("mssql.jobs", jobs, symbol: "clock", color: explorer.jobs),
                             menu: [.init(title: "Open in Tab", symbol: "list.bullet.rectangle"), .init(title: "Open in New Window", symbol: "rectangle.portrait.and.arrow.right"), .divider, .init(title: "Refresh", symbol: "arrow.clockwise")]),
                LabSCSection(id: "management", title: "Management", symbol: "gearshape", color: explorer.management,
                             nodes: tools.map { Nodes.tool("mssql.tool.\($0.0)", $0.0, symbol: $0.1) },
                             menu: [.init(title: "Activity Monitor", symbol: "gauge.high"), .init(title: "Maintenance", symbol: "wrench.and.screwdriver")], loadsOnOpen: false),
                LabSCSection(id: "snapshots", title: "Database Snapshots", symbol: "camera.aperture", color: explorer.databaseSnapshots,
                             nodes: Nodes.leaves("mssql.snap", ["AdventureWorks_snap_0929"], symbol: "camera", color: explorer.databaseSnapshots),
                             menu: [.init(title: "New Snapshot", symbol: "camera.badge.ellipsis"), .init(title: "Refresh", symbol: "arrow.clockwise")]),
                LabSCSection(id: "ssis", title: "Integration Services Catalogs", symbol: "shippingbox", color: explorer.integrationServices,
                             nodes: Nodes.leaves("mssql.ssis", ["SSISDB"], symbol: "folder", color: explorer.integrationServices),
                             menu: [.init(title: "Refresh", symbol: "arrow.clockwise")]),
                LabSCSection(id: "linked", title: "Linked Servers", symbol: "link", color: explorer.linkedServers,
                             nodes: Nodes.leaves("mssql.linked", ["AZURE_SQL", "REPORTING01"], symbol: "link", color: explorer.linkedServers),
                             menu: [.init(title: "New Linked Server", symbol: "link.badge.plus"), .init(title: "Refresh", symbol: "arrow.clockwise")]),
                LabSCSection(id: "triggers", title: "Server Triggers", symbol: "bolt.badge.clock", color: explorer.triggers,
                             nodes: Nodes.leaves("mssql.trig", ["trg_audit_logon"], symbol: "bolt", color: explorer.triggers),
                             menu: [.init(title: "New Server Trigger", symbol: "bolt"), .init(title: "Refresh", symbol: "arrow.clockwise")]),
            ]
        )
    }()

    static let postgres: LabSCServer = {
        let explorer = ColorTokens.Explorer.self
        let databases = [
            Nodes.database("pg", "employees", tables: ["employees.department", "employees.employee", "employees.salary", "employees.title"], views: ["employees.current_dept_emp"]),
            Nodes.database("pg", "k", tables: ["public.notes"]),
            Nodes.database("pg", "lego", tables: ["public.lego_colors", "public.lego_parts", "public.lego_sets", "public.lego_themes"]),
            Nodes.database("pg", "postgres", tables: ["public.pg_stat_statements"]),
        ]
        let activity: [(String, String)] = [("Sessions", "person.2.wave.2"), ("Locks", "lock"), ("Replication", "arrow.triangle.2.circlepath"), ("WAL", "doc.on.doc"), ("I/O Statistics", "internaldrive"), ("Background Writer", "square.and.pencil"), ("Prepared Transactions", "checklist"), ("Configuration", "slider.horizontal.3")]
        let management: [(String, String)] = [("Maintenance", "wrench.and.screwdriver"), ("Back Up Server", "externaldrive.badge.timemachine"), ("Back Up Globals", "globe"), ("Restore", "arrow.counterclockwise"), ("PSQL Console", "terminal")]
        return LabSCServer(
            id: "pg", name: "postgres18", engine: .postgres, rawVersion: "PostgreSQL 18.3",
            sections: [
                LabSCSection(id: "databases", title: "Databases", symbol: "cylinder.split.1x2", color: explorer.databaseFolder, nodes: databases,
                             menu: [.init(title: "New Database", symbol: "plus"), .init(title: "Restore Database", symbol: "arrow.counterclockwise"), .divider, .init(title: "Refresh", symbol: "arrow.clockwise")],
                             loadsOnOpen: false),
                LabSCSection(id: "security", title: "Security", symbol: "shield", color: explorer.security, nodes: [
                    Nodes.folder("pg.login", "Login Roles", symbol: "person.crop.circle", color: explorer.logins, loadsOnOpen: true, Nodes.leaves("pg.login", ["k", "postgres", "reporting", "etl"], symbol: "person.crop.circle", color: explorer.logins)),
                    Nodes.folder("pg.group", "Group Roles", symbol: "person.2.circle", color: explorer.roles, Nodes.leaves("pg.group", ["pg_monitor", "pg_read_all_data", "readers", "writers"], symbol: "person.2.circle", color: explorer.roles)),
                ], menu: [.init(title: "New Login Role", symbol: "person.badge.plus"), .init(title: "New Group Role", symbol: "person.2.badge.plus"), .divider, .init(title: "Refresh", symbol: "arrow.clockwise")]),
                LabSCSection(id: "activity", title: "Activity", symbol: "gauge.high", color: explorer.activityMonitor,
                             nodes: activity.map { Nodes.tool("pg.activity.\($0.0)", $0.0, symbol: $0.1, color: explorer.activityMonitor) },
                             menu: [.init(title: "Open Activity Monitor", symbol: "gauge.high"), .init(title: "Open in New Window", symbol: "rectangle.portrait.and.arrow.right")], loadsOnOpen: false),
                LabSCSection(id: "management", title: "Management", symbol: "gearshape", color: explorer.management,
                             nodes: management.map { Nodes.tool("pg.mgmt.\($0.0)", $0.0, symbol: $0.1) },
                             menu: [.init(title: "Maintenance", symbol: "wrench.and.screwdriver"), .init(title: "Back Up Server", symbol: "externaldrive.badge.timemachine")], loadsOnOpen: false),
                LabSCSection(id: "tablespaces", title: "Tablespaces", symbol: "square.stack.3d.up", color: explorer.extensions,
                             nodes: Nodes.leaves("pg.ts", ["pg_default", "pg_global", "fast_ssd"], symbol: "square.stack.3d.up", color: explorer.extensions),
                             menu: [.init(title: "New Tablespace", symbol: "plus"), .init(title: "Refresh", symbol: "arrow.clockwise")]),
            ]
        )
    }()
}
