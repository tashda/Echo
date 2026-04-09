import Foundation
import SQLServerKit

enum ExperimentalObjectBrowserServerFolderKind: String {
    case security
    case databaseSnapshots
    case agentJobs
    case management
    case ssis
    case linkedServers
    case serverTriggers

    var title: String {
        switch self {
        case .security: "Security"
        case .databaseSnapshots: "Database Snapshots"
        case .agentJobs: "Agent Jobs"
        case .management: "Management"
        case .ssis: "Integration Services Catalogs"
        case .linkedServers: "Linked Servers"
        case .serverTriggers: "Server Triggers"
        }
    }

    var systemImage: String {
        switch self {
        case .security: "shield"
        case .databaseSnapshots: "camera.aperture"
        case .agentJobs: "clock"
        case .management: "gearshape"
        case .ssis: "shippingbox"
        case .linkedServers: "link"
        case .serverTriggers: "bolt.badge.clock"
        }
    }
}

enum ExperimentalObjectBrowserSecuritySectionKind: String {
    case logins
    case certificateLogins
    case serverRoles
    case credentials
    case pgLoginRoles
    case pgGroupRoles

    var title: String {
        switch self {
        case .logins: "Logins"
        case .certificateLogins: "Certificate Logins"
        case .serverRoles: "Server Roles"
        case .credentials: "Credentials"
        case .pgLoginRoles: "Login Roles"
        case .pgGroupRoles: "Group Roles"
        }
    }

    var systemImage: String {
        switch self {
        case .logins: "person.2"
        case .certificateLogins: "doc.badge.lock"
        case .serverRoles: "shield"
        case .credentials: "key"
        case .pgLoginRoles: "person.crop.circle"
        case .pgGroupRoles: "person.2.circle"
        }
    }
}

enum ExperimentalObjectBrowserActionKind: String {
    case maintenance
    case serverProperties
    case activityMonitor
    case extendedEvents
    case databaseMail
    case sqlProfiler
    case resourceGovernor
    case tuningAdvisor
    case policyManagement
    case sqlServerLogs
    case openJobQueue

    var title: String {
        switch self {
        case .maintenance: "Maintenance"
        case .serverProperties: "Server Properties"
        case .activityMonitor: "Activity Monitor"
        case .extendedEvents: "Extended Events"
        case .databaseMail: "Database Mail"
        case .sqlProfiler: "SQL Profiler"
        case .resourceGovernor: "Resource Governor"
        case .tuningAdvisor: "Tuning Advisor"
        case .policyManagement: "Policy Management"
        case .sqlServerLogs: "SQL Server Logs"
        case .openJobQueue: "Agent Jobs Overview"
        }
    }

    var systemImage: String {
        switch self {
        case .maintenance: "wrench.and.screwdriver"
        case .serverProperties: "gearshape.2"
        case .activityMonitor: "gauge.high"
        case .extendedEvents: "list.bullet.rectangle"
        case .databaseMail: "envelope"
        case .sqlProfiler: "chart.line.uptrend.xyaxis"
        case .resourceGovernor: "slider.horizontal.3"
        case .tuningAdvisor: "wand.and.stars"
        case .policyManagement: "checkmark.shield"
        case .sqlServerLogs: "doc.text"
        case .openJobQueue: "list.bullet.rectangle"
        }
    }
}

enum ExperimentalObjectBrowserDatabaseFolderKind: String {
    case security
    case databaseTriggers
    case serviceBroker
    case externalResources

    var title: String {
        switch self {
        case .security: "Security"
        case .databaseTriggers: "Database Triggers"
        case .serviceBroker: "Service Broker"
        case .externalResources: "External Resources"
        }
    }

    var systemImage: String {
        switch self {
        case .security: "shield"
        case .databaseTriggers: "bolt"
        case .serviceBroker: "tray.2"
        case .externalResources: "externaldrive"
        }
    }
}

@MainActor
final class ExperimentalObjectBrowserNode: NSObject {
    enum Row {
        case topSpacer(CGFloat)
        case pendingConnection(PendingConnection)
        case server(ConnectionSession)
        case databasesFolder(ConnectionSession, count: Int)
        case database(ConnectionSession, DatabaseInfo, isLoading: Bool)
        case objectGroup(ConnectionSession, String, SchemaObjectInfo.ObjectType, count: Int)
        case object(ConnectionSession, String, SchemaObjectInfo)
        case serverFolder(ConnectionSession, ExperimentalObjectBrowserServerFolderKind, count: Int?)
        case databaseFolder(ConnectionSession, String, ExperimentalObjectBrowserDatabaseFolderKind, count: Int?, isLoading: Bool)
        case databaseSubfolder(ConnectionSession, String, title: String, systemImage: String, paletteTitle: String, count: Int?)
        case databaseNamedItem(ConnectionSession, String, title: String, systemImage: String, paletteTitle: String, detail: String?)
        case securitySection(ConnectionSession, ExperimentalObjectBrowserSecuritySectionKind, count: Int, isLoading: Bool)
        case securityLogin(ConnectionSession, ExperimentalObjectBrowserSidebarViewModel.SecurityLoginItem)
        case securityServerRole(ConnectionSession, ExperimentalObjectBrowserSidebarViewModel.SecurityServerRoleItem)
        case securityCredential(ConnectionSession, ExperimentalObjectBrowserSidebarViewModel.SecurityCredentialItem)
        case agentJob(ConnectionSession, ExperimentalObjectBrowserSidebarViewModel.AgentJobItem)
        case databaseSnapshot(ConnectionSession, SQLServerDatabaseSnapshot)
        case linkedServer(ConnectionSession, ExperimentalObjectBrowserSidebarViewModel.LinkedServerItem)
        case ssisFolder(ConnectionSession, SQLServerSSISFolder)
        case serverTrigger(ConnectionSession, ExperimentalObjectBrowserSidebarViewModel.ServerTriggerItem)
        case action(ConnectionSession, ExperimentalObjectBrowserActionKind, depth: Int)
        case infoLeaf(String, systemImage: String, paletteTitle: String, depth: Int)
        case loading(String, depth: Int)
        case message(String, systemImage: String, depth: Int)
    }

    let id: String
    var row: Row
    var children: [ExperimentalObjectBrowserNode]

    init(id: String, row: Row, children: [ExperimentalObjectBrowserNode] = []) {
        self.id = id
        self.row = row
        self.children = children
    }
}
