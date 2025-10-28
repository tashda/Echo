import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

private enum InspectorTab: CaseIterable {
    case dataInspector
    case connection

    var icon: String {
        switch self {
        case .dataInspector: return "tablecells"
        case .connection: return "server.rack"
        }
    }

    var activeIcon: String {
        switch self {
        case .dataInspector: return "tablecells.fill"
        case .connection: return "server.rack"
        }
    }

    var title: String {
        switch self {
        case .dataInspector: return "Data Inspector"
        case .connection: return "Connection"
        }
    }
}

private enum InspectorLayout {
    static let horizontalPadding: CGFloat = 12
}

struct InfoSidebarView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var selectedTab: InspectorTab = .dataInspector

    private var hasDataInspectorContent: Bool {
        appModel.dataInspectorContent != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            InspectorTabSelector(selectedTab: $selectedTab)
                .padding(.horizontal, InspectorLayout.horizontalPadding)
                .padding(.top, 0)
                .padding(.bottom, 8)

            Divider()
                .opacity(0.08)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .dataInspector:
                        dataInspectorContent
                    case .connection:
                        connectionInspectorContent
                    }
                }
                .padding(.horizontal, InspectorLayout.horizontalPadding)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear(perform: updateSelectionForAvailableContent)
        .onChange(of: appModel.dataInspectorContent) { _, _ in
            updateSelectionForAvailableContent()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func updateSelectionForAvailableContent() {
        if hasDataInspectorContent {
            selectedTab = .dataInspector
        } else if selectedTab == .dataInspector {
            selectedTab = .connection
        }
    }

    // MARK: - Data Inspector

    @ViewBuilder
    private var dataInspectorContent: some View {
        if let content = appModel.dataInspectorContent {
            VStack(alignment: .leading, spacing: 16) {
                switch content {
                case .foreignKey(let foreignKeyContent):
                    InspectorPanelView(content: foreignKeyContent, depth: 0)
                    if !appModel.globalSettings.foreignKeyIncludeRelated {
                        Text("Enable related foreign keys in Settings › Query Results to automatically expand referenced rows when available.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                case .json(let jsonContent):
                    JsonInspectorPanelView(content: jsonContent)
                }
            }
        } else {
            InspectorEmptyState(
                title: "No Selection",
                message: "Select a cell to inspect its related data."
            )
        }
    }

    // MARK: - Connection Inspector

    @ViewBuilder
    private var connectionInspectorContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let connection = appModel.selectedConnection {
                let connectionFields: [ForeignKeyInspectorContent.Field] = [
                    .init(label: "Name", value: connection.connectionName),
                    .init(label: "Host", value: connection.host),
                    .init(label: "User", value: connection.username),
                    .init(label: "Database", value: connection.database.isEmpty ? "Not selected" : connection.database)
                ]
                let connectionContent = ForeignKeyInspectorContent(
                    title: "Connection",
                    subtitle: connection.databaseType.displayName,
                    fields: connectionFields
                )
                InspectorPanelView(content: connectionContent, depth: 0)
            } else {
                InspectorEmptyState(
                    title: "No Connection",
                    message: "Connect to a server to view connection details."
                )
            }

            if let session = appModel.sessionManager.activeSession {
                let sessionFields: [ForeignKeyInspectorContent.Field] = [
                    .init(label: "Active Database", value: session.selectedDatabaseName ?? "None"),
                    .init(
                        label: "Last Activity",
                        value: session.lastActivity.formatted(date: .abbreviated, time: .shortened)
                    )
                ]
                let sessionContent = ForeignKeyInspectorContent(
                    title: "Session",
                    subtitle: session.connection.connectionName,
                    fields: sessionFields
                )
                InspectorPanelView(content: sessionContent, depth: 0)
            }
        }
    }
}

// MARK: - Components

private struct InspectorTabSelector: View {
    @Binding var selectedTab: InspectorTab

    var body: some View {
        let controlHeight: CGFloat = WorkspaceChromeMetrics.chromeBackgroundHeight
        let controlCornerRadius: CGFloat = controlHeight / 2
        let segmentCornerRadius: CGFloat = controlCornerRadius - 4

        RoundedRectangle(cornerRadius: controlCornerRadius, style: .continuous)
            .fill(Color.primary.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: controlCornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .overlay(
                HStack(spacing: 0) {
                    ForEach(Array(InspectorTab.allCases.enumerated()), id: \.offset) { index, tab in
                        let isEdgeSegment = index == 0 || index == InspectorTab.allCases.count - 1
                        let highlightCornerRadius = isEdgeSegment ? controlCornerRadius : segmentCornerRadius

                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedTab = tab
                            }
                        } label: {
                            ZStack {
                                Rectangle()
                                    .fill(Color.clear)
                                    .contentShape(Rectangle())

                                Image(systemName: selectedTab == tab ? tab.activeIcon : tab.icon)
                                    .font(.system(size: 14, weight: selectedTab == tab ? .medium : .regular))
                                    .foregroundStyle(selectedTab == tab ? Color.white : Color.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: highlightCornerRadius, style: .continuous)
                                .fill(Color.accentColor)
                                .opacity(selectedTab == tab ? 1 : 0)
                                .animation(.easeInOut(duration: 0.15), value: selectedTab)
                        )
                        .help(tab.title)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if index < InspectorTab.allCases.count - 1 {
                            let shouldShowDivider = selectedTab != tab &&
                                selectedTab != InspectorTab.allCases[index + 1]

                            Rectangle()
                                .fill(Color.primary.opacity(0.12))
                                .frame(width: 0.5)
                                .opacity(shouldShowDivider ? 1 : 0)
                                .animation(.easeInOut(duration: 0.15), value: shouldShowDivider)
                        }
                    }
                }
                .padding(.horizontal, 0)
                .padding(.vertical, 0)
            )
            .frame(height: controlHeight)
    }
}

private struct InspectorPanelView: View {
    let content: ForeignKeyInspectorContent
    let depth: Int
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(content.title)
                        .font(.system(.title3, design: .default).weight(.semibold))
                    if let subtitle = content.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if let query = resolvedLookupQuery {
                    let targetTitle = content.title.isEmpty ? "record" : content.title
                    Button {
                        openForeignRecord(with: query)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Open \(targetTitle) in a new query tab")
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(content.fields) { field in
                    InspectorFieldRow(field: field)
                }
            }

            if !content.related.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Related Records")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(content.related.enumerated()), id: \.offset) { _, related in
                    RelatedInspectorSection(content: related, depth: depth + 1)
                }
            }
        }
        .padding(.top, depth == 0 ? 4 : 0)
        .padding(.bottom, 4)
    }

    private var resolvedLookupQuery: String? {
        guard let raw = content.lookupQuerySQL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        return raw
    }

    private func openForeignRecord(with sql: String) {
        appModel.openQueryTab(presetQuery: sql, autoExecute: true)
    }
}

private struct InspectorFieldRow: View {
    let field: ForeignKeyInspectorContent.Field
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(field.label.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(field.value.isEmpty ? "—" : field.value)
                .font(.callout.weight(.medium))
                .foregroundStyle(themeManager.surfaceForegroundColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(themeManager.activePaletteTone == .dark ? 0.18 : 0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(themeManager.activePaletteTone == .dark ? 0.08 : 0.18), lineWidth: 0.6)
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contextMenu {
                    Button {
                        copyToGeneralPasteboard(field.value)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
        }
    }
}

private struct JsonInspectorPanelView: View {
    let content: JsonInspectorContent

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(content.title)
                    .font(.system(.title3, design: .default).weight(.semibold))
                if let subtitle = content.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if content.outline.children.isEmpty {
                JsonInspectorLeafRow(node: content.outline)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(content.outline.children) { child in
                        JsonInspectorNodeRow(node: child, depth: 0)
                    }
                }
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 4)
    }
}

private struct JsonInspectorNodeRow: View {
    let node: JsonOutlineNode
    let depth: Int
    @State private var isExpanded: Bool = true

    var body: some View {
        if node.hasChildren {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(node.children) { child in
                        JsonInspectorNodeRow(node: child, depth: depth + 1)
                    }
                }
                .padding(.top, 8)
            } label: {
                JsonInspectorRowHeader(title: node.title, subtitle: node.subtitle, depth: depth)
            }
        } else {
            JsonInspectorLeafRow(node: node, depth: depth)
        }
    }
}

private struct JsonInspectorRowHeader: View {
    let title: String
    let subtitle: String
    let depth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.leading, CGFloat(depth) * 4)
    }
}

private struct JsonInspectorLeafRow: View {
    let node: JsonOutlineNode
    var depth: Int = 0
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = node.key.displayTitle {
                Text(title.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(node.value.kind.displayName.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(node.subtitle.isEmpty ? "—" : node.subtitle)
                .font(.callout.weight(.medium))
                .foregroundStyle(themeManager.surfaceForegroundColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(themeManager.activePaletteTone == .dark ? 0.18 : 0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(themeManager.activePaletteTone == .dark ? 0.08 : 0.18), lineWidth: 0.6)
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contextMenu {
                    Button {
                        copyToGeneralPasteboard(node.subtitle)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
        }
        .padding(.leading, CGFloat(depth) * 6)
    }
}

private struct RelatedInspectorSection: View {
    let content: ForeignKeyInspectorContent
    let depth: Int
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            InspectorPanelView(content: content, depth: depth + 1)
                .padding(.top, 10)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(content.title)
                    .font(.subheadline.weight(.semibold))
                if let subtitle = content.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct InspectorEmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

private func copyToGeneralPasteboard(_ value: String) {
#if os(macOS)
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(value, forType: .string)
#else
    UIPasteboard.general.string = value
#endif
}
