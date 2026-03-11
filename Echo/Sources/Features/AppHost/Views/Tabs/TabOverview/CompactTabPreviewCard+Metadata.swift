import SwiftUI

extension CompactTabPreviewCard {
    var metrics: [(icon: String, text: String, color: Color)] {
        switch tab.kind {
        case .query:
            guard let query = tab.query else { return [] }
            var items: [(String, String, Color)] = []
            let rows = query.rowProgress.displayCount
            if rows > 0 {
                items.append(("tablecells", "\(EchoFormatters.compactNumber(rows))", Color.secondary))
            }
            if let event = query.messages.last(where: { $0.severity != .debug }) {
                items.append(("clock.arrow.circlepath", relativeDescription(for: event.timestamp), Color.secondary))
            }
            return items
        case .diagram:
            guard let diagram = tab.diagram else { return [] }
            return [("square.grid.2x2", "\(diagram.nodes.count)", Color.secondary)]
        case .structure:
            guard let editor = tab.structureEditor else { return [] }
            return [("tablecells", "\(editor.columns.count)", Color.secondary)]
        case .jobQueue:
            return []
        case .psql:
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
        }
    }

    var status: (icon: String, text: String, color: Color) {
        tabOverviewStatus(for: tab, appearanceStore: appearanceStore)
    }

    func relativeDescription(for date: Date) -> String {
        EchoFormatters.relativeDate(date).capitalized
    }
}
