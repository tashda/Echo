import SwiftUI

extension CompactTabPreviewCard {
    var metrics: [(icon: String, text: String, color: Color)] {
        switch tab.kind {
        case .query:
            guard let query = tab.query else { return [] }
            var items: [(String, String, Color)] = []
            let rows = query.rowProgress.displayCount
            if rows > 0 {
                items.append(("tablecells", "\(EchoFormatters.compactNumber(rows))", ColorTokens.Text.secondary))
            }
            if let event = query.messages.last(where: { $0.severity != .debug }) {
                items.append(("clock.arrow.circlepath", relativeDescription(for: event.timestamp), ColorTokens.Text.secondary))
            }
            return items
        case .diagram:
            guard let diagram = tab.diagram else { return [] }
            return [("square.grid.2x2", "\(diagram.nodes.count)", ColorTokens.Text.secondary)]
        case .structure:
            guard let editor = tab.structureEditor else { return [] }
            return [("tablecells", "\(editor.columns.count)", ColorTokens.Text.secondary)]
        case .jobQueue:
            return []
        case .psql:
            return []
        case .extensionStructure:
            return []
        case .extensionsManager:
            return []
        case .activityMonitor:
            return []
        case .maintenance, .mssqlMaintenance:
            return []
        case .queryStore:
            return []
        case .extendedEvents:
            return []
        case .availabilityGroups:
            return []
        case .databaseSecurity, .serverSecurity:
            return []
        case .errorLog:
            return []
        case .profiler, .resourceGovernor, .serverProperties, .tuningAdvisor, .policyManagement:
            return []
        }
        }

        var tabTitle: String {
        let title = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Untitled" : title
        }

        var tabSubtitle: String? {
        switch tab.kind {
        case .query:
            return nil
        case .diagram:
            return "Diagram"
        case .structure:
            return "Structure"
        case .jobQueue:
            return "Jobs"
        case .psql:
            return "Postgres Console"
        case .extensionStructure:
            return "Extension"
        case .extensionsManager:
            return "Extension Manager"
        case .activityMonitor:
            return "Activity"
        case .maintenance, .mssqlMaintenance:
            return "Maintenance"
        case .queryStore:
            return "Query Store"
        case .extendedEvents:
            return "Extended Events"
        case .availabilityGroups:
            return "Availability Groups"
        case .databaseSecurity:
            return "Database Security"
        case .serverSecurity:
            return "Server Security"
        case .errorLog:
            return "Error Log"
        case .profiler:
            return "SQL Profiler"
        case .resourceGovernor:
            return "Resource Governor"
        case .serverProperties:
            return "Server Properties"
        case .tuningAdvisor:
            return "Tuning Advisor"
        case .policyManagement:
            return "Policy Management"
        }
        }

        var snippet: String? {
        switch tab.kind {
        case .query:
            guard let query = tab.query else { return nil }
            let trimmed = query.sql.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return String(trimmed.prefix(120))
        case .diagram:
            return tab.diagram?.title
        case .structure:
            if let editor = tab.structureEditor {
                return "\(editor.schemaName).\(editor.tableName)"
            }
            return nil
        case .jobQueue:
            return nil
        case .psql:
            return nil
        case .extensionStructure:
            return nil
        case .extensionsManager:
            return "Manage database extensions"
        case .activityMonitor:
            return "Live system performance monitoring"
        case .maintenance, .mssqlMaintenance:
            return "Database health and maintenance operations"
        case .queryStore:
            return "Query Store analysis and plan management"
        case .extendedEvents:
            return "Extended Events session monitoring"
        case .availabilityGroups:
            return "Always On Availability Groups dashboard"
        case .databaseSecurity:
            return "Database security management"
        case .serverSecurity:
            return "Server security management"
        case .errorLog:
            return "SQL Server error log viewer"
        case .profiler:
            return "SQL Profiler session and trace management"
        case .resourceGovernor:
            return "Configure and monitor Resource Governor"
        case .serverProperties:
            return "View and modify server configuration properties"
        case .tuningAdvisor:
            return "Database Engine Tuning Advisor recommendations"
        case .policyManagement:
            return "Manage database policies and compliance"
        }
        }

    var status: (icon: String, text: String, color: Color) {
        tabOverviewStatus(for: tab, appearanceStore: appearanceStore)
    }

    func relativeDescription(for date: Date) -> String {
        EchoFormatters.relativeDate(date).capitalized
    }
}
