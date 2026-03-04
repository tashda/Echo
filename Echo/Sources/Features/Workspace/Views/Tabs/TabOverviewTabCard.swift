import SwiftUI

struct TabPreviewCard: View {
    @ObservedObject var tab: WorkspaceTab
    let isActive: Bool
    let isFocused: Bool
    let isDropTarget: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false
    @State private var isHoveringClose = false
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                previewBackground
                    .overlay(previewContent)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(4)

                closeButton
                    .padding(12)
            }
            .frame(height: 140)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    statusIndicator

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tabTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let subtitle = tabSubtitle {
                            Text(subtitle)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    if isActive {
                        activeBadge
                    } else {
                        statusBadge
                    }
                }

                footerMetrics
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(cardBorder)
        .overlay(focusRing)
        .shadow(color: cardShadow, radius: isFocused ? 20 : 12, y: isFocused ? 12 : 6)
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .onHover { hovering in
            isHovering = hovering
#if os(macOS)
            if !hovering { isHoveringClose = false }
#endif
        }
        .onTapGesture(perform: onSelect)
    }

    @ViewBuilder
    private var closeButton: some View {
#if os(macOS)
        if isHovering, !tab.isPinned {
            Button(action: onClose) {
                Image(systemName: isHoveringClose ? "xmark.circle.fill" : "xmark.circle.fill")
                    .resizable()
                    .frame(width: 18, height: 18)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(isHoveringClose ? Color.primary : Color.secondary, .ultraThinMaterial)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringClose = hovering
            }
        }
#else
        if !tab.isPinned {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
        }
#endif
    }

    private var activeBadge: some View {
        let accent = themeManager.accentColor
        return Text("Active")
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(colorScheme == .dark ? 0.4 : 0.18))
            )
            .foregroundStyle(accent)
    }

    private var statusBadge: some View {
        let status = tabStatus
        return Label {
            Text(status.text)
        } icon: {
            Image(systemName: status.icon)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(status.color.opacity(colorScheme == .dark ? 0.24 : 0.1))
        )
        .foregroundStyle(status.color)
    }

    private var footerMetrics: some View {
        HStack(alignment: .center, spacing: 10) {
            ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                HStack(spacing: 6) {
                    Image(systemName: metric.icon)
                    Text(metric.text)
                }
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(metric.color.opacity(colorScheme == .dark ? 0.22 : 0.12))
                )
                .foregroundStyle(metric.color)
            }
            Spacer(minLength: 0)
        }
    }

    private var metrics: [Metric] {
        switch tab.kind {
        case .query:
            return queryMetrics
        case .diagram:
            return diagramMetrics
        case .structure:
            return structureMetrics
        case .jobManagement:
            return []
        }
    }

    private var queryMetrics: [Metric] {
        guard let query = tab.query else { return [] }
        var items: [Metric] = []

        if let event = query.messages.last(where: { $0.severity != .debug }) {
            items.append(Metric(icon: "clock.arrow.circlepath", text: relativeDescription(for: event.timestamp), color: Color.secondary))
        }

        let rows = query.rowProgress.displayCount
        if rows > 0 {
            items.append(Metric(icon: "tablecells", text: "\(formattedNumber(rows)) rows", color: Color.secondary))
        }

        return items
    }

    private var diagramMetrics: [Metric] {
        guard let diagram = tab.diagram else { return [] }
        var items: [Metric] = []
        items.append(Metric(icon: "square.grid.2x2.fill", text: "\(diagram.nodes.count) node\(diagram.nodes.count == 1 ? "" : "s")", color: Color.secondary))
        switch diagram.loadSource {
        case .live(let date):
            items.append(Metric(icon: "clock.arrow.circlepath", text: relativeDescription(for: date), color: Color.secondary))
        case .cache(let date):
            items.append(Metric(icon: "archivebox.fill", text: "Cached \(relativeDescription(for: date))", color: Color.secondary))
        }
        return items
    }

    private var structureMetrics: [Metric] {
        guard let editor = tab.structureEditor else { return [] }
        return [
            Metric(icon: "tablecells", text: "\(editor.columns.count) column\(editor.columns.count == 1 ? "" : "s")", color: Color.secondary),
            Metric(icon: "wrench.and.screwdriver.fill", text: editor.isApplying ? "Pending changes" : "Editable", color: Color.secondary)
        ]
    }

    private func relativeDescription(for date: Date) -> String {
        let value = TabPreviewCard.relativeFormatter.localizedString(for: date, relativeTo: Date())
        return value.capitalized
    }

    private var statusIndicator: some View {
        Circle()
            .fill(tabStatus.color.opacity(0.9))
            .frame(width: 10, height: 10)
            .shadow(color: tabStatus.color.opacity(0.35), radius: 4, y: 1)
    }

    private var tabStatus: (icon: String, text: String, color: Color) {
        tabOverviewStatus(for: tab, themeManager: themeManager)
    }

    private var tabTitle: String {
        let title = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Untitled" : title
    }

    private var tabSubtitle: String? {
        switch tab.kind {
        case .query:
            return nil
        case .diagram:
            return "Diagram"
        case .structure:
            return "Table Structure"
        case .jobManagement:
            return "Jobs"
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch tab.kind {
        case .query:
            if let query = tab.query {
                QueryTabPreview(query: query)
            } else {
                EmptyPreviewPlaceholder(message: "Query unavailable")
            }
        case .diagram:
            if let diagram = tab.diagram {
                DiagramTabPreview(diagram: diagram)
            } else {
                EmptyPreviewPlaceholder(message: "Diagram unavailable")
            }
        case .structure:
            if let editor = tab.structureEditor {
                StructureTabPreview(editor: editor)
            } else {
                EmptyPreviewPlaceholder(message: "Structure unavailable")
            }
        case .jobManagement:
            EmptyPreviewPlaceholder(message: "Jobs")
        }
    }

    private var previewBackground: LinearGradient {
        LinearGradient(
            colors: [
                themeManager.accentColor.opacity(colorScheme == .dark ? 0.28 : 0.18),
                Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.12 : 0.65),
                        Color.white.opacity(colorScheme == .dark ? 0.05 : 0.45)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(borderColor, lineWidth: isDropTarget ? 2.8 : (isFocused ? 1.4 : 0.9))
    }

    private var borderColor: Color {
        if isDropTarget {
            return themeManager.accentColor
        }
        if isFocused {
            return themeManager.accentColor.opacity(colorScheme == .dark ? 0.55 : 0.4)
        }
        return Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.08)
    }

    private var focusRing: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(themeManager.accentColor.opacity(isFocused ? 0.38 : 0), lineWidth: 2.8)
    }

    private var cardShadow: Color {
        Color.black.opacity(colorScheme == .dark ? (isFocused ? 0.42 : 0.32) : (isFocused ? 0.16 : 0.08))
    }

    private func formattedNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private struct Metric {
        let icon: String
        let text: String
        let color: Color
    }
}

struct CompactTabPreviewCard: View {
    @ObservedObject var tab: WorkspaceTab
    let isActive: Bool
    let isDropTarget: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false
    @State private var isHoveringClose = false
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let container = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tabTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if let subtitle = tabSubtitle {
                        Text(subtitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }

            if let snippet = snippet {
                Text(snippet)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            statusBadge

            if !metrics.isEmpty {
                HStack(alignment: .center, spacing: 8) {
                    ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                        HStack(spacing: 4) {
                            Image(systemName: metric.icon)
                            Text(metric.text)
                        }
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(metric.color.opacity(colorScheme == .dark ? 0.25 : 0.12))
                        )
                        .foregroundStyle(metric.color)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            container
                .fill(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.6))
        )
        .overlay(
            container.stroke(compactBorderColor, lineWidth: isDropTarget ? 2.2 : (isActive ? 1.2 : 0.7))
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: isActive ? 12 : 6, y: isActive ? 10 : 5)
        .overlay(closeButton.padding(6), alignment: .topTrailing)
        .onHover { hovering in
            isHovering = hovering
#if os(macOS)
            if !hovering { isHoveringClose = false }
#endif
        }
        .onTapGesture(perform: onSelect)
    }

    private var compactBorderColor: Color {
        if isDropTarget {
            return themeManager.accentColor
        }
        if isActive {
            return themeManager.accentColor.opacity(colorScheme == .dark ? 0.5 : 0.35)
        }
        return Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.08)
    }

    private var metrics: [(icon: String, text: String, color: Color)] {
        switch tab.kind {
        case .query:
            guard let query = tab.query else { return [] }
            var items: [(String, String, Color)] = []
            let rows = query.rowProgress.displayCount
            if rows > 0 {
                items.append(("tablecells", "\(formattedNumber(rows))", Color.secondary))
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
        case .jobManagement:
            return []
        }
    }

    private var tabTitle: String {
        let title = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Untitled" : title
    }

    private var tabSubtitle: String? {
        switch tab.kind {
        case .query:
            return nil
        case .diagram:
            return "Diagram"
        case .structure:
            return "Structure"
        case .jobManagement:
            return "Jobs"
        }
    }

    private var snippet: String? {
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
        case .jobManagement:
            return nil
        }
    }

    private var status: (icon: String, text: String, color: Color) {
        tabOverviewStatus(for: tab, themeManager: themeManager)
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: status.icon)
            Text(status.text)
        }
        .font(.system(size: 10, weight: .semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(status.color.opacity(colorScheme == .dark ? 0.25 : 0.12))
        )
        .foregroundStyle(status.color)
    }

    private func formattedNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func relativeDescription(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date()).capitalized
    }

    @ViewBuilder
    private var closeButton: some View {
#if os(macOS)
        if isHovering, !tab.isPinned {
            Button(action: onClose) {
                Image(systemName: isHoveringClose ? "xmark.circle.fill" : "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isHoveringClose ? Color.secondary : Color.secondary.opacity(0.8))
                    .padding(4)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringClose = hovering
            }
        }
#else
        if !tab.isPinned {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.secondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
#endif
    }
}

@MainActor
func tabOverviewStatus(for tab: WorkspaceTab, themeManager: ThemeManager) -> (icon: String, text: String, color: Color) {
    switch tab.kind {
    case .query:
        guard let query = tab.query else { return ("clock", "Not run", Color.secondary) }
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
        return ("clock", "Not run", Color.secondary)
    case .diagram:
        if let diagram = tab.diagram {
            if diagram.isLoading {
                return ("progress.indicator", "Loading", .orange)
            }
            if let error = diagram.errorMessage, !error.isEmpty {
                return ("exclamationmark.triangle.fill", "Diagram error", .orange)
            }
            return ("chart.xyaxis.line", "Ready", Color.secondary)
        }
        return ("circle", "Unavailable", Color.secondary.opacity(0.4))
    case .structure:
        if let editor = tab.structureEditor {
            if editor.isApplying {
                return ("hammer.fill", "Applying…", themeManager.accentColor)
            }
            if editor.isLoading {
                return ("arrow.triangle.2.circlepath", "Refreshing", themeManager.accentColor)
            }
            if let error = editor.lastError, !error.isEmpty {
                return ("exclamationmark.triangle.fill", "Error", .orange)
            }
            if let success = editor.lastSuccessMessage, !success.isEmpty {
                return ("checkmark.circle.fill", success, .green)
            }
            return ("tablecells", "Ready", Color.secondary)
        }
        return ("circle", "Unavailable", Color.secondary.opacity(0.4))
    case .jobManagement:
        if tab.jobManagement != nil {
            return ("wrench.and.screwdriver", "Ready", Color.secondary)
        }
        return ("circle", "Unavailable", Color.secondary.opacity(0.4))
    }
}

struct EmptyPreviewPlaceholder: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(12)
    }
}

struct QueryTabPreview: View {
    @ObservedObject var query: QueryEditorState

    private var trimmedSQL: String {
        let trimmed = query.sql.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if trimmedSQL.isEmpty {
                Text("Empty query")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                Text(trimmedSQL)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
    }
}

struct DiagramTabPreview: View {
    @ObservedObject var diagram: SchemaDiagramViewModel

    private var status: (icon: String, text: String, color: Color) {
        if diagram.isLoading {
            return ("hourglass", "Loading…", Color.accentColor)
        }
        if let error = diagram.errorMessage, !error.isEmpty {
            return ("exclamationmark.triangle.fill", "Diagram error", .orange)
        }
        return ("chart.xyaxis.line", "\(diagram.nodes.count) table\(diagram.nodes.count == 1 ? "" : "s")", .secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(diagram.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)

            Label(status.text, systemImage: status.icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(status.color)

            if let message = diagram.statusMessage, !message.isEmpty {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
    }
}

struct StructureTabPreview: View {
    @ObservedObject var editor: TableStructureEditorViewModel

    private var status: (icon: String, text: String, color: Color) {
        if editor.isApplying {
            return ("hammer.fill", "Applying changes…", Color.accentColor)
        }
        if editor.isLoading {
            return ("arrow.triangle.2.circlepath", "Refreshing…", Color.accentColor)
        }
        if let error = editor.lastError, !error.isEmpty {
            return ("exclamationmark.triangle.fill", "Last update failed", .orange)
        }
        if let message = editor.lastSuccessMessage, !message.isEmpty {
            return ("checkmark.circle.fill", message, .green)
        }
        return ("tablecells", "\(editor.columns.count) column\(editor.columns.count == 1 ? "" : "s")", .secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(editor.schemaName).\(editor.tableName)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)

            Label(status.text, systemImage: status.icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(status.color)

            if !editor.indexes.isEmpty {
                Text("\(editor.indexes.count) index\(editor.indexes.count == 1 ? "" : "es") configured")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
    }
}
