import SwiftUI

/// Round 14 · TC1: the server card's sections, one per dock button.
enum LabDockSection: String, CaseIterable, Identifiable {
    case databases = "Databases"
    case security = "Security"
    case agent = "Agent"
    case management = "Management"
    case more = "More"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .databases: "cylinder"
        case .security: "shield"
        case .agent: "clock"
        case .management: "gearshape"
        case .more: "ellipsis.circle"
        }
    }

    var color: Color {
        switch self {
        case .databases: ColorTokens.Explorer.databaseInstance
        case .security: ColorTokens.Explorer.security
        case .agent: ColorTokens.Explorer.jobs
        case .management: ColorTokens.Text.secondary
        case .more: ColorTokens.Explorer.integrationServices
        }
    }

    var nodes: [LabDockNode] { LabDockSamples.nodes(for: self) }
    var initiallyExpanded: Set<String> { LabDockSamples.expanded(for: self) }
}

enum LabDockIconMode: String, CaseIterable, Identifiable {
    case duotone = "IC2 · Duotone"
    case mono = "IC1 · Mono"
    var id: String { rawValue }
}

enum LabDockLabels: String, CaseIterable, Identifiable {
    case iconsOnly = "Icons only"
    case currentTitle = "Icons + current title"
    var id: String { rawValue }
}

enum LabDockEdge: String, CaseIterable, Identifiable {
    case soft = "Soft edge"
    case hard = "Hard edge"
    var id: String { rawValue }
    var style: ScrollEdgeEffectStyle { self == .soft ? .soft : .hard }
}

struct LabDockNode: Identifiable, Hashable {
    let id: String
    let title: String
    var prefix: String? = nil
    let symbol: String
    let color: Color
    var count: Int? = nil
    var children: [LabDockNode] = []

    var isFolder: Bool { !children.isEmpty }
}

/// Sample content for the Test MSSQL server in the owner's screenshots.
enum LabDockSamples {
    private static func folder(_ id: String, _ title: String, symbol: String = "folder", _ color: Color, _ children: [LabDockNode]) -> LabDockNode {
        LabDockNode(id: id, title: title, symbol: symbol, color: color, count: children.count, children: children)
    }

    private static func leaves(_ parent: String, _ names: [String], symbol: String, color: Color) -> [LabDockNode] {
        names.map { name in
            let parts = name.split(separator: ".", maxSplits: 1).map(String.init)
            return LabDockNode(id: "\(parent).\(name)", title: parts.last ?? name, prefix: parts.count == 2 ? parts[0] : nil, symbol: symbol, color: color)
        }
    }

    static let tables = ["HumanResources.Department", "HumanResources.Employee", "HumanResources.EmployeeDepartmentHistory", "HumanResources.EmployeePayHistory", "HumanResources.JobCandidate", "HumanResources.Shift", "Person.Address", "Person.AddressType", "Person.BusinessEntity", "Person.EmailAddress", "Person.Person", "Person.PersonPhone", "Production.Product", "Production.ProductCategory", "Production.ProductInventory", "Sales.Customer", "Sales.SalesOrderDetail", "Sales.SalesOrderHeader", "Sales.SalesPerson", "Sales.SalesTerritory", "Sales.Store"]
    static let jobs = ["51955A83", "CEC45B01", "41D91DED", "7B311D9B", "35DD92B5", "30CE9D36", "2A6B73D0", "F4F23E87", "0B5945FC", "BF1B4323", "C94644E8", "CE9F8C37", "63C3341B", "39F70A4A", "19517532", "58CD9745", "1B0E266E", "7B426821", "A07686EF", "47EE8696", "3841C0DE", "8BAA0F12", "E1C2D3B4"]

    static func nodes(for section: LabDockSection) -> [LabDockNode] {
        let explorer = ColorTokens.Explorer.self
        switch section {
        case .databases:
            let aw = folder("aw", "AdventureWorks2022", symbol: "cylinder", explorer.databaseInstance, [
                folder("aw.tables", "Tables", explorer.tables, leaves("aw.tables", tables, symbol: "tablecells", color: explorer.tables)),
                folder("aw.views", "Views", explorer.views, leaves("aw.views", ["HumanResources.vEmployee", "Sales.vSalesPerson", "Sales.vStoreWithContacts", "Person.vAdditionalContactInfo"], symbol: "eye", color: explorer.views)),
                folder("aw.procs", "Stored Procedures", explorer.procedures, leaves("aw.procs", ["dbo.uspGetBillOfMaterials", "dbo.uspGetEmployeeManagers", "dbo.uspLogError"], symbol: "curlybraces", color: explorer.procedures)),
                folder("aw.funcs", "Functions", explorer.functions, leaves("aw.funcs", ["dbo.ufnGetContactInformation", "dbo.ufnGetStock"], symbol: "function", color: explorer.functions)),
            ])
            let others = ["master", "model", "msdb", "tempdb", "WideWorldImporters"].map { name in
                folder("db.\(name)", name, symbol: "cylinder", explorer.databaseInstance, [
                    folder("db.\(name).tables", "Tables", explorer.tables, leaves("db.\(name).tables", ["dbo.sample"], symbol: "tablecells", color: explorer.tables)),
                ])
            }
            return [aw] + others
        case .security:
            return [
                folder("sec.logins", "Logins", symbol: "person", explorer.logins, leaves("sec.logins", ["##MS_PolicyEventProcessingLogin##", "##MS_PolicyTsqlExecutionLogin##", "BUILTIN\\Administrators", "NT AUTHORITY\\SYSTEM", "echo_app", "etl_service", "old_etl", "reporting_ro", "sa", "test_login_1", "test_login_2", "test_login_3", "web_api", "zabbix"], symbol: "person", color: explorer.logins)),
                folder("sec.roles", "Server Roles", symbol: "person.2", explorer.serverRoles, leaves("sec.roles", ["bulkadmin", "dbcreator", "diskadmin", "processadmin", "public", "securityadmin", "serveradmin", "setupadmin", "sysadmin"], symbol: "person.2", color: explorer.serverRoles)),
                folder("sec.creds", "Credentials", symbol: "key", explorer.credentials, leaves("sec.creds", ["AzureBackup", "ProxyCredential"], symbol: "key", color: explorer.credentials)),
                folder("sec.audits", "Audits", symbol: "doc.text", explorer.security, leaves("sec.audits", ["LoginAudit"], symbol: "doc.text", color: explorer.security)),
            ]
        case .agent:
            return [
                LabDockNode(id: "agent.overview", title: "Agent Jobs Overview", symbol: "list.bullet.rectangle", color: explorer.jobs),
                folder("agent.jobs", "Jobs", symbol: "clock", explorer.jobs, leaves("agent.jobs", jobs.map { "agent_test_\($0)" }, symbol: "clock", color: explorer.jobs)),
                folder("agent.alerts", "Alerts", symbol: "bell", explorer.jobs, leaves("agent.alerts", ["Severity 017", "Severity 019", "Deadlock"], symbol: "bell", color: explorer.jobs)),
                folder("agent.ops", "Operators", symbol: "person.crop.circle", explorer.jobs, leaves("agent.ops", ["DBA team"], symbol: "person.crop.circle", color: explorer.jobs)),
            ]
        case .management:
            let tools: [(String, String)] = [("Activity Monitor", "waveform.path.ecg"), ("Maintenance", "wrench.and.screwdriver"), ("Extended Events", "bolt.horizontal"), ("Resource Governor", "slider.horizontal.3"), ("Policy Management", "checkmark.shield"), ("SQL Server Logs", "doc.plaintext"), ("Database Mail", "envelope")]
            return tools.map { LabDockNode(id: "mgmt.\($0.0)", title: $0.0, symbol: $0.1, color: ColorTokens.Text.secondary) }
        case .more:
            return [
                folder("more.snap", "Database Snapshots", symbol: "camera", explorer.databaseSnapshots, leaves("more.snap", ["AdventureWorks_snap_0929"], symbol: "camera", color: explorer.databaseSnapshots)),
                folder("more.ssis", "Integration Services Catalogs", symbol: "shippingbox", explorer.integrationServices, leaves("more.ssis", ["SSISDB"], symbol: "shippingbox", color: explorer.integrationServices)),
                folder("more.linked", "Linked Servers", symbol: "link", explorer.views, leaves("more.linked", ["AZURE_SQL", "REPORTING01"], symbol: "link", color: explorer.views)),
                folder("more.trig", "Server Triggers", symbol: "bolt", explorer.triggers, leaves("more.trig", ["trg_audit_logon"], symbol: "bolt", color: explorer.triggers)),
                LabDockNode(id: "more.props", title: "Server Properties", symbol: "server.rack", color: ColorTokens.Text.secondary),
            ]
        }
    }

    static func expanded(for section: LabDockSection) -> Set<String> {
        switch section {
        case .databases: ["aw", "aw.tables"]
        case .security: ["sec.logins"]
        case .agent: ["agent.jobs"]
        case .management, .more: []
        }
    }
}
