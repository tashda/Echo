#if DEBUG
import SwiftUI

// Tree card page: sample data. Each server's tree is written as an ordered blueprint, the way the
// proposed `ExplorerBlueprint` would describe a database type: the order here is the tree's order,
// and every node carries a role (what it is) instead of a title string that picks its colour.

/// What a node is. The role picks the symbol and, in colourful mode, the colour.
enum LabNodeRole: Sendable {
    case databases, database, tables, views, materializedViews, functions, procedures, triggers
    case sequences, types, extensions, synonyms, schema
    case security, logins, roles, users, credentials
    case jobs, snapshots, management, linkedServers, serverTriggers, integration, serviceBroker, tool
    case table, view, function, procedure, installedExtension, job, login, role
    case column, keyColumn, foreignKeyColumn

    var symbol: String {
        switch self {
        case .databases: "cylinder.split.1x2"
        case .database: "cylinder"
        case .tables, .table: "tablecells"
        case .views, .view: "eye"
        case .materializedViews: "square.stack.3d.up"
        case .functions, .function: "function"
        case .procedures, .procedure: "terminal"
        case .triggers: "bolt"
        case .sequences: "number"
        case .types: "t.square"
        case .extensions, .installedExtension: "puzzlepiece.extension"
        case .synonyms: "arrow.triangle.branch"
        case .schema: "folder"
        case .security: "shield"
        case .logins, .login: "person.crop.circle"
        case .roles, .role: "person.2"
        case .users: "person"
        case .credentials: "key"
        case .jobs, .job: "clock"
        case .snapshots: "camera.aperture"
        case .management: "gearshape"
        case .linkedServers: "link"
        case .serverTriggers: "bolt.badge.clock"
        case .integration: "shippingbox"
        case .serviceBroker: "tray.2"
        case .tool: "wrench.and.screwdriver"
        case .column: ""
        case .keyColumn: "key"
        case .foreignKeyColumn: "arrow.turn.down.right"
        }
    }

    /// Symbols with a `.fill` variant (checked against SF Symbols; a missing name draws nothing).
    static let fillable: Set<String> = [
        "cylinder", "cylinder.split.1x2", "tablecells", "eye", "square.stack.3d.up", "terminal", "bolt",
        "t.square", "puzzlepiece.extension", "folder", "shield", "person.crop.circle", "person.2", "person",
        "key", "clock", "gearshape", "bolt.badge.clock", "shippingbox", "tray.2", "wrench.and.screwdriver",
        "list.bullet.rectangle", "envelope", "doc.text",
    ]

    /// Today's colour for the role (`ColorTokens.Explorer`), before softening.
    var vividColor: Color {
        switch self {
        case .databases: ColorTokens.Explorer.databaseFolder
        case .database: ColorTokens.Explorer.databaseInstance
        case .tables, .table: ColorTokens.Explorer.tables
        case .views, .view: ColorTokens.Explorer.views
        case .materializedViews: ColorTokens.Explorer.materializedViews
        case .functions, .function: ColorTokens.Explorer.functions
        case .procedures, .procedure: ColorTokens.Explorer.procedures
        case .triggers: ColorTokens.Explorer.triggers
        case .sequences: ColorTokens.Explorer.sequences
        case .types: ColorTokens.Explorer.types
        case .extensions, .installedExtension: ColorTokens.Explorer.extensions
        case .synonyms, .schema, .column: ColorTokens.Text.secondary
        case .security: ColorTokens.Explorer.security
        case .logins, .login: ColorTokens.Explorer.logins
        case .roles, .role: ColorTokens.Explorer.roles
        case .users: ColorTokens.Explorer.users
        case .credentials: ColorTokens.Explorer.credentials
        case .jobs, .job: ColorTokens.Explorer.jobs
        case .snapshots: ColorTokens.Explorer.databaseSnapshots
        case .management, .tool: ColorTokens.Explorer.management
        case .linkedServers: ColorTokens.Explorer.linkedServers
        case .serverTriggers: ColorTokens.Explorer.serverTriggers
        case .integration: ColorTokens.Explorer.integrationServices
        case .serviceBroker: ColorTokens.Explorer.serviceBroker
        case .keyColumn: .orange
        case .foreignKeyColumn: ColorTokens.Status.info
        }
    }

    /// The "Families" palette: one hue per kind of thing instead of one per folder.
    var familyColor: Color {
        switch self {
        case .databases, .database, .tables, .table, .views, .view, .materializedViews, .synonyms, .schema: .blue
        case .functions, .function, .procedures, .procedure, .triggers, .sequences, .types: .orange
        case .security, .logins, .login, .roles, .role, .users, .credentials: .purple
        case .jobs, .job, .snapshots, .management, .linkedServers, .serverTriggers, .integration, .serviceBroker, .tool: .teal
        case .extensions, .installedExtension: .indigo
        case .column: ColorTokens.Text.secondary
        case .keyColumn: .orange
        case .foreignKeyColumn: .blue
        }
    }
}

struct LabTreeNode: Identifiable, Sendable {
    let id: String
    let title: String
    let role: LabNodeRole
    var symbol: String? = nil
    var schema: String? = nil
    var count: Int? = nil
    /// Right-hand detail that is always shown (a column's type).
    var detail: String? = nil
    /// Extra facts shown only by the Detailed style (row counts, sizes).
    var metric: String? = nil
    var children: [LabTreeNode] = []

    var resolvedSymbol: String { symbol ?? role.symbol }
}

struct LabTreeServer: Identifiable, Sendable {
    let id: String
    let name: String
    let monogram: String
    let color: Color
    let product: String
    let host: String
    let children: [LabTreeNode]
}

// MARK: - Blueprint helpers

private func folder(_ id: String, _ title: String, _ role: LabNodeRole, count: Int? = nil, _ children: [LabTreeNode] = []) -> LabTreeNode {
    LabTreeNode(id: id, title: title, role: role, count: count ?? (children.isEmpty ? nil : children.count), children: children)
}

private func objects(_ parent: String, _ role: LabNodeRole, _ names: [(String, String, String?)], columns: [String: [LabTreeNode]] = [:]) -> [LabTreeNode] {
    names.map { schema, name, metric in
        LabTreeNode(id: "\(parent).\(schema).\(name)", title: name, role: role, schema: schema, metric: metric, children: columns[name] ?? [])
    }
}

private func column(_ parent: String, _ name: String, _ type: String, _ role: LabNodeRole = .column) -> LabTreeNode {
    LabTreeNode(id: "\(parent)#\(name)", title: name, role: role, detail: type)
}

private func database(_ id: String, _ name: String, metric: String, _ children: [LabTreeNode] = []) -> LabTreeNode {
    LabTreeNode(id: id, title: name, role: .database, metric: metric, children: children)
}

// MARK: - Samples

enum LabTreeCardSamples {
    static let servers: [LabTreeServer] = [postgres, sqlServer]
    static let initiallySelected = "pg.employees.tables.employees.salary"
    static let initiallyExpanded: Set<String> = [
        "pg.databases", "pg.employees", "pg.employees.tables",
        "ms.databases", "ms.aw", "ms.aw.tables", "ms.aw.tables#HumanResources",
        "pg.security", "ms.security", "ms.management",
    ]

    private static let employeeTables: [(String, String, String?)] = [
        ("employees", "department", "9"), ("employees", "department_employee", "331k"),
        ("employees", "department_manager", "24"), ("employees", "employee", "300k"),
        ("employees", "salary", "2.8M"), ("employees", "title", "443k"),
    ]

    static let postgres = LabTreeServer(
        id: "pg", name: "postgres18", monogram: "18", color: .blue, product: "PostgreSQL 18.1", host: "localhost",
        children: [
            folder("pg.databases", "Databases", .databases, [
                database("pg.employees", "employees", metric: "6 tables · 412 MB", [
                    folder("pg.employees.tables", "Tables", .tables, objects("pg.employees.tables", .table, employeeTables, columns: [
                        "salary": [
                            column("pg.salary", "employee_id", "int8", .keyColumn),
                            column("pg.salary", "amount", "int8"),
                            column("pg.salary", "from_date", "date", .keyColumn),
                            column("pg.salary", "to_date", "date"),
                        ],
                    ])),
                    folder("pg.employees.views", "Views", .views, objects("pg.employees.views", .view, [("employees", "current_dept_emp", nil), ("employees", "dept_emp_latest_date", nil)])),
                    folder("pg.employees.functions", "Functions", .functions, objects("pg.employees.functions", .function, [("employees", "raise_salary", nil)])),
                    folder("pg.employees.sequences", "Sequences", .sequences, objects("pg.employees.sequences", .sequences, [("employees", "employee_id_seq", nil)])),
                    folder("pg.employees.extensions", "Extensions", .extensions, [LabTreeNode(id: "pg.plpgsql", title: "plpgsql", role: .installedExtension, detail: "1.0")]),
                ]),
                database("pg.k", "k", metric: "2 tables · 8 MB"),
                database("pg.lego", "lego", metric: "8 tables · 36 MB"),
                database("pg.postgres", "postgres", metric: "1 table · 7 MB"),
            ]),
            folder("pg.security", "Security", .security, [
                folder("pg.loginRoles", "Login Roles", .logins, count: 3),
                folder("pg.groupRoles", "Group Roles", .roles, count: 12),
            ]),
        ]
    )

    private static let adventureTables: [(String, String, String?)] = [
        ("HumanResources", "Department", "16"), ("HumanResources", "Employee", "290"),
        ("HumanResources", "Shift", "3"), ("Person", "Address", "19.6k"), ("Person", "Person", "19.9k"),
        ("Production", "Product", "504"), ("Sales", "Customer", "19.8k"), ("Sales", "SalesOrderHeader", "31.4k"),
    ]

    static let sqlServer = LabTreeServer(
        id: "ms", name: "Microsoft SQL Server", monogram: "MS", color: .orange, product: "SQL Server 2022", host: "echo-test-mssql",
        children: [
            folder("ms.databases", "Databases", .databases, count: 251, [
                database("ms.aw", "AdventureWorks2022", metric: "71 tables · 272 MB", [
                    folder("ms.aw.tables", "Tables", .tables, count: 71, objects("ms.aw.tables", .table, adventureTables)),
                    folder("ms.aw.views", "Views", .views, count: 20),
                    folder("ms.aw.synonyms", "Synonyms", .synonyms, count: 2),
                    folder("ms.aw.functions", "Functions", .functions, count: 11),
                    folder("ms.aw.procedures", "Stored Procedures", .procedures, count: 10),
                    folder("ms.aw.security", "Security", .security),
                    folder("ms.aw.broker", "Service Broker", .serviceBroker),
                ]),
            ] + ["cmtr_10E65763", "cmtr_EA1B6D46C93A", "cmts_1AF5C684", "cmts_57358EE7A194", "csmx_40704FC4A823", "cst_027AAEF265CD"].map {
                database("ms.\($0)", $0, metric: "0 tables · 16 MB")
            }),
            folder("ms.security", "Security", .security, [
                folder("ms.logins", "Logins", .logins, count: 14),
                folder("ms.serverRoles", "Server Roles", .roles, count: 9),
                folder("ms.credentials", "Credentials", .credentials),
            ]),
            folder("ms.snapshots", "Database Snapshots", .snapshots),
            folder("ms.jobs", "Agent Jobs", .jobs, [
                LabTreeNode(id: "ms.job.backup", title: "Nightly backup", role: .job, detail: "Succeeded"),
                LabTreeNode(id: "ms.job.index", title: "Index maintenance", role: .job, detail: "Failed"),
            ]),
            folder("ms.management", "Management", .management, [
                LabTreeNode(id: "ms.xe", title: "Extended Events", role: .tool, symbol: "list.bullet.rectangle"),
                LabTreeNode(id: "ms.mail", title: "Database Mail", role: .tool, symbol: "envelope"),
                LabTreeNode(id: "ms.activity", title: "Activity Monitor", role: .tool, symbol: "gauge.high"),
                LabTreeNode(id: "ms.logs", title: "SQL Server Logs", role: .tool, symbol: "doc.text"),
            ]),
            folder("ms.ssis", "Integration Services", .integration),
            folder("ms.linked", "Linked Servers", .linkedServers, count: 1),
            folder("ms.serverTriggers", "Server Triggers", .serverTriggers),
        ]
    )
}
#endif
