import Foundation

/// Every kind of thing the Explorer tree shows, with its title, symbol and colour role. This is
/// the one catalogue the blueprints, rows, menus and palette read (Design/05-components.md ›
/// Explorer tree › How a tree is described).
nonisolated enum ExplorerNodeKind: String, CaseIterable, Sendable {
    // Server-level folders
    case databases
    case serverSecurity
    case logins, certificateLogins, serverRoles, credentials, loginRoles, groupRoles
    case databaseSnapshots, agentJobs, management, integrationServices, linkedServers, serverTriggers
    case activity, tablespaces, serverObjects

    // Tools
    case maintenance, serverProperties, activityMonitor, extendedEvents, databaseMail, sqlProfiler
    case resourceGovernor, tuningAdvisor, policyManagement, sqlServerLogs, jobQueue
    case backUpServer, backUpGlobals, psqlConsole
    // PostgreSQL Activity Monitor pages, each a tool that opens the monitor on that page
    case pgSessions, pgLocks, pgDatabaseStatistics, pgOperations, pgQueries, pgReplication
    case pgIOStatistics, pgWAL, pgBackgroundWriter, pgPreparedTransactions, pgConfiguration

    // Database-level folders
    case tables, views, materializedViews, functions, procedures, triggers, sequences, types, extensions, synonyms
    case databaseSecurity, users, databaseRoles, applicationRoles, schemas
    case databaseTriggers
    case serviceBroker, messageTypes, contracts, queues, services, routes, remoteServiceBindings
    case externalResources, externalDataSources, externalTables, externalFileFormats

    // Loaded items
    case login, serverRole, credential, databaseSnapshot, agentJob, ssisFolder, linkedServer, serverTrigger
    case user, databaseRole, applicationRole, schema, databaseTrigger, brokerObject, externalObject
    case tablespace

    var title: String {
        if let objectType { return objectType.pluralDisplayName }
        switch self {
        case .databases: return "Databases"
        case .serverSecurity, .databaseSecurity: return "Security"
        case .logins: return "Logins"
        case .certificateLogins: return "Certificate Logins"
        case .serverRoles: return "Server Roles"
        case .credentials: return "Credentials"
        case .loginRoles: return "Login Roles"
        case .groupRoles: return "Group Roles"
        case .databaseSnapshots: return "Database Snapshots"
        case .agentJobs: return "Agent Jobs"
        case .management: return "Management"
        case .integrationServices: return "Integration Services Catalogs"
        case .linkedServers: return "Linked Servers"
        case .serverTriggers: return "Server Triggers"
        case .maintenance: return "Maintenance"
        case .serverProperties: return "Server Properties"
        case .activityMonitor: return "Activity Monitor"
        case .extendedEvents: return "Extended Events"
        case .databaseMail: return "Database Mail"
        case .sqlProfiler: return "SQL Profiler"
        case .resourceGovernor: return "Resource Governor"
        case .tuningAdvisor: return "Tuning Advisor"
        case .policyManagement: return "Policy Management"
        case .sqlServerLogs: return "SQL Server Logs"
        case .jobQueue: return "Agent Jobs Overview"
        case .activity: return "Activity"
        case .serverObjects: return "Server Objects"
        case .tablespaces: return "Tablespaces"
        case .tablespace: return "Tablespace"
        case .backUpServer: return "Back Up Server"
        case .backUpGlobals: return "Back Up Globals"
        case .psqlConsole: return "PSQL Console"
        case .pgSessions: return "Sessions"
        case .pgLocks: return "Locks"
        case .pgDatabaseStatistics: return "Database Statistics"
        case .pgOperations: return "Operations"
        case .pgQueries: return "Queries"
        case .pgReplication: return "Replication"
        case .pgIOStatistics: return "I/O Statistics"
        case .pgWAL: return "WAL"
        case .pgBackgroundWriter: return "Background Writer"
        case .pgPreparedTransactions: return "Prepared Transactions"
        case .pgConfiguration: return "Configuration"
        case .users: return "Users"
        case .databaseRoles: return "Database Roles"
        case .applicationRoles: return "Application Roles"
        case .schemas: return "Schemas"
        case .databaseTriggers: return "Database Triggers"
        case .serviceBroker: return "Service Broker"
        case .messageTypes: return "Message Types"
        case .contracts: return "Contracts"
        case .queues: return "Queues"
        case .services: return "Services"
        case .routes: return "Routes"
        case .remoteServiceBindings: return "Remote Service Bindings"
        case .externalResources: return "External Resources"
        case .externalDataSources: return "External Data Sources"
        case .externalTables: return "External Tables"
        case .externalFileFormats: return "External File Formats"
        case .login: return "Login"
        case .serverRole: return "Server Role"
        case .credential: return "Credential"
        case .databaseSnapshot: return "Snapshot"
        case .agentJob: return "Job"
        case .ssisFolder: return "Folder"
        case .linkedServer: return "Linked Server"
        case .serverTrigger: return "Server Trigger"
        case .user: return "User"
        case .databaseRole: return "Database Role"
        case .applicationRole: return "Application Role"
        case .schema: return "Schema"
        case .databaseTrigger: return "Database Trigger"
        case .brokerObject, .externalObject: return "Object"
        case .tables, .views, .materializedViews, .functions, .procedures, .triggers, .sequences, .types, .extensions, .synonyms:
            return ""
        }
    }

    /// The SF Symbol drawn for this kind. `ExplorerNodeKindTests` checks every one exists.
    var symbol: String {
        if let objectType { return objectType.systemImage }
        switch self {
        case .databases: return "cylinder.split.1x2"
        case .serverSecurity, .databaseSecurity, .serverRoles, .serverRole, .databaseRoles, .databaseRole: return "shield"
        case .logins: return "person.2"
        case .certificateLogins: return "checkmark.seal"
        case .credentials, .credential: return "key"
        case .loginRoles, .login: return "person.crop.circle"
        case .groupRoles: return "person.2.circle"
        case .databaseSnapshots: return "camera.aperture"
        case .databaseSnapshot: return "camera.fill"
        case .agentJobs, .agentJob: return "clock"
        case .management: return "gearshape"
        case .integrationServices: return "shippingbox"
        case .ssisFolder, .schemas, .schema: return "folder"
        case .linkedServers, .linkedServer: return "link"
        case .serverTriggers: return "bolt.badge.clock"
        case .serverTrigger, .databaseTrigger: return "bolt"
        case .maintenance: return "wrench.and.screwdriver"
        case .activity: return "gauge.high"
        case .serverObjects: return "square.grid.2x2"
        case .tablespaces, .tablespace: return "square.stack.3d.up"
        case .backUpServer: return "externaldrive.badge.timemachine"
        case .backUpGlobals: return "globe"
        case .psqlConsole: return "terminal"
        case .pgSessions: return "person.2.wave.2"
        case .pgLocks: return "lock"
        case .pgDatabaseStatistics: return "cylinder"
        case .pgOperations: return "hourglass"
        case .pgQueries: return "text.magnifyingglass"
        case .pgReplication: return "arrow.triangle.2.circlepath"
        case .pgIOStatistics: return "internaldrive"
        case .pgWAL: return "doc.on.doc"
        case .pgBackgroundWriter: return "square.and.pencil"
        case .pgPreparedTransactions: return "checklist"
        case .pgConfiguration: return "slider.horizontal.3"
        case .serverProperties: return "gearshape.2"
        case .activityMonitor: return "gauge.high"
        case .extendedEvents, .jobQueue: return "list.bullet.rectangle"
        case .databaseMail: return "envelope"
        case .sqlProfiler: return "chart.line.uptrend.xyaxis"
        case .resourceGovernor: return "slider.horizontal.3"
        case .tuningAdvisor: return "wand.and.stars"
        case .policyManagement: return "checkmark.shield"
        case .sqlServerLogs: return "doc.text"
        case .users, .user: return "person"
        case .applicationRoles, .applicationRole: return "app.badge"
        case .databaseTriggers: return "bolt.horizontal"
        case .serviceBroker: return "tray.2"
        case .messageTypes, .contracts, .queues, .services, .routes, .remoteServiceBindings: return "tray"
        case .externalResources, .externalDataSources, .externalTables, .externalFileFormats: return "externaldrive"
        case .brokerObject, .externalObject: return "doc"
        case .tables, .views, .materializedViews, .functions, .procedures, .triggers, .sequences, .types, .extensions, .synonyms:
            return ""
        }
    }

    /// Which colour the symbol takes in colourful mode.
    var role: ExplorerIconRole {
        switch self {
        case .databases: .databases
        case .tables: .tables
        case .views: .views
        case .materializedViews: .materializedViews
        case .functions: .functions
        case .procedures: .procedures
        case .triggers: .triggers
        case .sequences: .sequences
        case .types: .types
        case .extensions: .extensions
        case .synonyms, .maintenance, .serverProperties, .backUpServer, .backUpGlobals, .psqlConsole: .neutral
        case .activity, .pgSessions, .pgLocks, .pgDatabaseStatistics, .pgOperations, .pgQueries, .pgReplication,
             .pgIOStatistics, .pgWAL, .pgBackgroundWriter, .pgPreparedTransactions, .pgConfiguration: .activityMonitor
        case .tablespaces, .tablespace: .extensions
        case .serverSecurity, .databaseSecurity: .security
        case .logins, .certificateLogins, .loginRoles, .login: .logins
        case .groupRoles, .databaseRoles, .applicationRoles, .schemas, .databaseRole, .applicationRole, .schema: .roles
        case .serverRoles, .serverRole: .serverRoles
        case .credentials, .credential: .credentials
        case .users, .user: .users
        case .databaseSnapshots, .databaseSnapshot: .snapshots
        case .agentJobs, .agentJob, .jobQueue: .jobs
        case .management, .sqlServerLogs: .management
        case .integrationServices, .ssisFolder: .integrationServices
        case .linkedServers, .linkedServer, .serverObjects: .linkedServers
        case .serverTriggers, .serverTrigger: .serverTriggers
        case .databaseTriggers, .databaseTrigger: .databaseTriggers
        case .activityMonitor: .activityMonitor
        case .extendedEvents: .extendedEvents
        case .databaseMail: .databaseMail
        case .sqlProfiler: .sqlProfiler
        case .resourceGovernor: .resourceGovernor
        case .tuningAdvisor: .tuningAdvisor
        case .policyManagement: .policyManagement
        case .serviceBroker, .messageTypes, .contracts, .queues, .services, .routes, .remoteServiceBindings, .brokerObject: .serviceBroker
        case .externalResources, .externalDataSources, .externalTables, .externalFileFormats, .externalObject: .externalResources
        }
    }

    /// The object type an object folder lists, such as `.table` for Tables.
    var objectType: SchemaObjectInfo.ObjectType? {
        switch self {
        case .tables: .table
        case .views: .view
        case .materializedViews: .materializedView
        case .functions: .function
        case .procedures: .procedure
        case .triggers: .trigger
        case .sequences: .sequence
        case .types: .type
        case .extensions: .extension
        case .synonyms: .synonym
        default: nil
        }
    }

    /// The object folder for an object type.
    init(objectFolderFor type: SchemaObjectInfo.ObjectType) {
        self = switch type {
        case .table: .tables
        case .view: .views
        case .materializedView: .materializedViews
        case .function: .functions
        case .procedure: .procedures
        case .trigger: .triggers
        case .sequence: .sequences
        case .type: .types
        case .extension: .extensions
        case .synonym: .synonyms
        }
    }

    /// The kind of the items a folder lists once loaded (Logins lists logins).
    var itemKind: ExplorerNodeKind {
        switch self {
        case .logins, .certificateLogins, .loginRoles, .groupRoles: .login
        case .serverRoles: .serverRole
        case .credentials: .credential
        case .databaseSnapshots: .databaseSnapshot
        case .agentJobs: .agentJob
        case .integrationServices: .ssisFolder
        case .linkedServers: .linkedServer
        case .serverTriggers: .serverTrigger
        case .tablespaces: .tablespace
        case .users: .user
        case .databaseRoles: .databaseRole
        case .applicationRoles: .applicationRole
        case .schemas: .schema
        case .databaseTriggers: .databaseTrigger
        case .messageTypes, .contracts, .queues, .services, .routes, .remoteServiceBindings: .brokerObject
        case .externalDataSources, .externalTables, .externalFileFormats: .externalObject
        default: self
        }
    }

    /// The part of a node ID naming this kind. Unchanged from the kinds it replaced, so saved
    /// expansion state still matches.
    var idComponent: String {
        switch self {
        case .serverSecurity, .databaseSecurity: "security"
        case .integrationServices: "ssis"
        case .loginRoles: "pgLoginRoles"
        case .groupRoles: "pgGroupRoles"
        case .jobQueue: "openJobQueue"
        default: rawValue
        }
    }

    var loadingTitle: String { "Loading \(title.lowercased())" }
    var emptyTitle: String { "No \(title.lowercased())" }
}
