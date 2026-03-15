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
        case .queryStore:
            return []
        case .extendedEvents:
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
        case .queryStore:
            return "Query Store"
        case .extendedEvents:
            return "Extended Events"
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
        case .queryStore:
            return "Query Store analysis and plan management"
        case .extendedEvents:
            return "Extended Events session monitoring"
        }
        }

    var status: (icon: String, text: String, color: Color) {
        tabOverviewStatus(for: tab, appearanceStore: appearanceStore)
    }

    func relativeDescription(for date: Date) -> String {
        EchoFormatters.relativeDate(date).capitalized
    }
}
