import SwiftUI

/// The colour family a tree symbol belongs to in colourful mode. Colours are chosen by role,
/// never by a row's title, and come from `ColorTokens.Explorer` (the Vivid palette, softened
/// towards grey by `ObjectBrowserRowView.explorerIconColor(_:)`).
nonisolated enum ExplorerIconRole: Sendable, CaseIterable {
    case neutral
    case databases, database
    case tables, views, materializedViews, functions, procedures, triggers, sequences, types, extensions
    case security, logins, serverRoles, credentials, users, roles
    case jobs, snapshots, integrationServices, linkedServers, serverTriggers, databaseTriggers
    case management, activityMonitor, extendedEvents, databaseMail, sqlProfiler, resourceGovernor, tuningAdvisor, policyManagement
    case serviceBroker, externalResources

    var color: Color {
        switch self {
        case .neutral: ColorTokens.Text.secondary
        case .databases: ColorTokens.Explorer.databaseFolder
        case .database: ColorTokens.Explorer.databaseInstance
        case .tables: ColorTokens.Explorer.tables
        case .views: ColorTokens.Explorer.views
        case .materializedViews: ColorTokens.Explorer.materializedViews
        case .functions: ColorTokens.Explorer.functions
        case .procedures: ColorTokens.Explorer.procedures
        case .triggers: ColorTokens.Explorer.triggers
        case .sequences: ColorTokens.Explorer.sequences
        case .types: ColorTokens.Explorer.types
        case .extensions: ColorTokens.Explorer.extensions
        case .security: ColorTokens.Explorer.security
        case .logins: ColorTokens.Explorer.logins
        case .serverRoles: ColorTokens.Explorer.serverRoles
        case .credentials: ColorTokens.Explorer.credentials
        case .users: ColorTokens.Explorer.users
        case .roles: ColorTokens.Explorer.roles
        case .jobs: ColorTokens.Explorer.jobs
        case .snapshots: ColorTokens.Explorer.databaseSnapshots
        case .integrationServices: ColorTokens.Explorer.integrationServices
        case .linkedServers: ColorTokens.Explorer.linkedServers
        case .serverTriggers: ColorTokens.Explorer.serverTriggers
        case .databaseTriggers: ColorTokens.Explorer.databaseTriggers
        case .management: ColorTokens.Explorer.management
        case .activityMonitor: ColorTokens.Explorer.activityMonitor
        case .extendedEvents: ColorTokens.Explorer.extendedEvents
        case .databaseMail: ColorTokens.Explorer.databaseMail
        case .sqlProfiler: ColorTokens.Explorer.sqlProfiler
        case .resourceGovernor: ColorTokens.Explorer.resourceGovernor
        case .tuningAdvisor: ColorTokens.Explorer.tuningAdvisor
        case .policyManagement: ColorTokens.Explorer.policyManagement
        case .serviceBroker: ColorTokens.Explorer.serviceBroker
        case .externalResources: ColorTokens.Explorer.externalResources
        }
    }
}
