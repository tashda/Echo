import SwiftUI
import SQLServerKit
import PostgresWire

@MainActor
func tabOverviewStatus(for tab: WorkspaceTab, appearanceStore: AppearanceStore) -> (icon: String, text: String, color: Color) {
    switch tab.kind {
    case .query:
        guard let query = tab.query else { return ("clock", "Not run", ColorTokens.Text.secondary) }
        if query.isExecuting {
            return ("progress.indicator", "Executing", .orange)
        }
        if query.wasCancelled {
            return ("stop.fill", "Cancelled", .yellow)
        }
        if let message = query.errorMessage, !message.isEmpty {
            return ("exclamationmark.triangle.fill", "Error", .red)
        }
        if query.hasExecutedAtLeastOnce {
            return ("checkmark.circle.fill", "Completed", .green)
        }
        return ("clock", "Not run", ColorTokens.Text.secondary)
    case .diagram:
        if let diagram = tab.diagram {
            if diagram.isLoading {
                return ("progress.indicator", "Loading", .orange)
            }
            if let error = diagram.errorMessage, !error.isEmpty {
                return ("exclamationmark.triangle.fill", "Diagram error", .orange)
            }
            return ("chart.xyaxis.line", "Ready", ColorTokens.Text.secondary)
        }
        return ("circle", "Unavailable", ColorTokens.Text.secondary.opacity(0.4))
    case .structure:
        if let editor = tab.structureEditor {
            if editor.isApplying {
                return ("hammer.fill", "Applying…", appearanceStore.accentColor)
            }
            if editor.isLoading {
                return ("arrow.triangle.2.circlepath", "Refreshing", appearanceStore.accentColor)
            }
            if let error = editor.lastError, !error.isEmpty {
                return ("exclamationmark.triangle.fill", "Error", .orange)
            }
            if let success = editor.lastSuccessMessage, !success.isEmpty {
                return ("checkmark.circle.fill", success, .green)
            }
            return ("tablecells", "Ready", ColorTokens.Text.secondary)
        }
        return ("circle", "Unavailable", ColorTokens.Text.secondary.opacity(0.4))
    case .jobQueue:
        if tab.jobQueue != nil {
            return ("wrench.and.screwdriver", "Ready", ColorTokens.Text.secondary)
        }
        return ("circle", "Unavailable", ColorTokens.Text.secondary.opacity(0.4))
    case .psql:
        if let psql = tab.psql {
            if psql.isExecuting {
                return ("progress.indicator", "Executing", .orange)
            }
            return ("terminal", "Ready", ColorTokens.Text.secondary)
        }
        return ("circle", "Unavailable", ColorTokens.Text.secondary.opacity(0.4))
    case .extensionStructure:
        return ("puzzlepiece.fill", "Ready", ColorTokens.Text.secondary)
    case .extensionsManager:
        return ("puzzlepiece", "Ready", ColorTokens.Text.secondary)
    case .activityMonitor:
        if let vm = tab.activityMonitor {
            return (vm.isRunning ? "bolt.fill" : "pause.fill", vm.isRunning ? "Monitoring" : "Paused", vm.isRunning ? .green : .secondary)
        }
        return ("chart.bar.doc.horizontal", "Ready", ColorTokens.Text.secondary)
    case .maintenance:
        return ("wrench.and.screwdriver", "Ready", ColorTokens.Text.secondary)
    case .queryStore:
        return ("chart.bar.xaxis", "Ready", ColorTokens.Text.secondary)
    case .extendedEvents:
        return ("waveform.path.ecg", "Ready", ColorTokens.Text.secondary)
    case .availabilityGroups:
        return ("server.rack", "Ready", ColorTokens.Text.secondary)
    }
}

extension TabPreviewCard {
    struct Metric {
        let icon: String
        let text: String
        let color: Color
    }

    var metrics: [Metric] {
        switch tab.kind {
        case .query:
            return queryMetrics
        case .diagram:
            return diagramMetrics
        case .structure:
            return structureMetrics
        case .jobQueue:
            return []
        case .psql:
            return []
        case .extensionStructure:
            return []
        case .extensionsManager:
            return []
        case .activityMonitor:
            return activityMonitorMetrics
        case .maintenance:
            return []
        case .queryStore:
            return []
        case .extendedEvents:
            return []
        case .availabilityGroups:
            return []
        }
    }

    private var activityMonitorMetrics: [Metric] {
        guard let vm = tab.activityMonitor, let snap = vm.latestSnapshot else { return [] }
        var items: [Metric] = []
        
        switch snap {
        case .mssql(let s):
            if let ov = s.overview {
                items.append(Metric(icon: "cpu", text: "\(Int(ov.processorTimePercent))%", color: .secondary))
                items.append(Metric(icon: "person.2", text: "\(s.processes.count) procs", color: .secondary))
            }
        case .postgres(let s):
            if let ov = s.overview {
                items.append(Metric(icon: "person.2", text: "\(s.processes.count) procs", color: .secondary))
                items.append(Metric(icon: "arrow.left.arrow.right", text: "\(Int(ov.transactionsPerSec)) tx/s", color: .secondary))
            }
        }
        
        return items
    }

    private var queryMetrics: [Metric] {
        guard let query = tab.query else { return [] }
        var items: [Metric] = []

        if let event = query.messages.last(where: { $0.severity != .debug }) {
            items.append(Metric(icon: "clock.arrow.circlepath", text: relativeDescription(for: event.timestamp), color: ColorTokens.Text.secondary))
        }

        let rows = query.rowProgress.displayCount
        if rows > 0 {
            items.append(Metric(icon: "tablecells", text: "\(EchoFormatters.compactNumber(rows)) rows", color: ColorTokens.Text.secondary))
        }

        return items
    }

    private var diagramMetrics: [Metric] {
        guard let diagram = tab.diagram else { return [] }
        var items: [Metric] = []
        items.append(Metric(icon: "square.grid.2x2.fill", text: "\(diagram.nodes.count) node\(diagram.nodes.count == 1 ? "" : "s")", color: ColorTokens.Text.secondary))
        switch diagram.loadSource {
        case .live(let date):
            items.append(Metric(icon: "clock.arrow.circlepath", text: relativeDescription(for: date), color: ColorTokens.Text.secondary))
        case .cache(let date):
            items.append(Metric(icon: "archivebox.fill", text: "Cached \(relativeDescription(for: date))", color: ColorTokens.Text.secondary))
        }
        return items
    }

    private var structureMetrics: [Metric] {
        guard let editor = tab.structureEditor else { return [] }
        return [
            Metric(icon: "tablecells", text: "\(editor.columns.count) column\(editor.columns.count == 1 ? "" : "s")", color: ColorTokens.Text.secondary),
            Metric(icon: "wrench.and.screwdriver.fill", text: editor.isApplying ? "Pending changes" : "Editable", color: ColorTokens.Text.secondary)
        ]
    }

    func relativeDescription(for date: Date) -> String {
        EchoFormatters.relativeDate(date).capitalized
    }

    var tabStatus: (icon: String, text: String, color: Color) {
        tabOverviewStatus(for: tab, appearanceStore: appearanceStore)
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
            return "Table Structure"
        case .jobQueue:
            return "Jobs"
        case .psql:
            return "Postgres Console"
        case .extensionStructure:
            return "Extension"
        case .extensionsManager:
            return "Extensions"
        case .activityMonitor:
            return "Activity Monitor"
        case .maintenance:
            return "Maintenance"
        case .queryStore:
            return "Query Store"
        case .extendedEvents:
            return "Extended Events"
        case .availabilityGroups:
            return "Availability Groups"
        }
    }
}
