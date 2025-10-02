import SwiftUI

struct TabbedQueryView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 0) {
            tabBar

            if appState.showTabOverview {
                TabOverviewView(
                    tabs: appModel.tabManager.tabs,
                    activeTabId: appModel.tabManager.activeTabId,
                    onSelectTab: { tabId in
                        appModel.tabManager.activeTabId = tabId
                        appState.showTabOverview = false
                    },
                    onCloseTab: { tabId in
                        appModel.tabManager.closeTab(id: tabId)
                    }
                )
            } else if let activeTab = appModel.tabManager.activeTab {
                WorkspaceContentView(
                    tab: activeTab,
                    runQuery: { sql in await runQuery(tabId: activeTab.id, sql: sql) },
                    cancelQuery: { cancelQuery(tabId: activeTab.id) }
                )
            } else {
                ContentUnavailableView {
                    Label("No Tabs", systemImage: "doc.text")
                } description: {
                    Text("Open a connection to start working")
                } actions: {
                    Button("New Query", action: createNewTab)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .toolbar {
            if !appState.showInfoSidebar {
                ToolbarItemGroup(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        Button(action: createNewTab) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(appModel.sessionManager.activeSession == nil)
                        .help("New Tab")

                        Button(action: { appState.showTabOverview.toggle() }) {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Tab Overview")

                        if let namespace {
                            Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { appState.showInfoSidebar.toggle() } }) {
                                Image(systemName: "sidebar.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Toggle Info Sidebar")
                            .matchedGeometryEffect(id: "sidebarToggle", in: namespace)
                        }
                    }
                }
            }
        }
        .onAppear(perform: createInitialTabIfNeeded)
        .onChange(of: appModel.selectedConnection) { _, _ in
            createInitialTabIfNeeded()
        }
    }

    @ViewBuilder
    private var tabBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(appModel.tabManager.tabs) { tab in
                        WorkspaceTabButton(
                            tab: tab,
                            isActive: appModel.tabManager.activeTabId == tab.id,
                            onSelect: { appModel.tabManager.activeTabId = tab.id },
                            onClose: { appModel.tabManager.closeTab(id: tab.id) }
                        )
                        .id(tab.id)
                    }
                }
                .padding(.leading, 12)
                .padding(.vertical, 6)
            }

            Spacer(minLength: 0)
        }
        .frame(height: 40)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .bottom)
    }

    private func createInitialTabIfNeeded() {
        guard appModel.tabManager.tabs.isEmpty,
              let activeSession = appModel.sessionManager.activeSession else { return }

        appModel.openQueryTab(for: activeSession)
    }

    private func createNewTab() {
        guard let activeSession = appModel.sessionManager.activeSession else { return }
        appModel.openQueryTab(for: activeSession)
    }

    private func runQuery(tabId: UUID, sql: String) async {
        guard let tab = appModel.tabManager.getTab(id: tabId),
              let queryState = tab.query else { return }

        let task = Task { [weak queryState] in
            guard let queryState else { return }

            do {
                let result = try await tab.session.simpleQuery(sql)
                try Task.checkCancellation()
                await MainActor.run {
                    queryState.results = result
                    queryState.updateRowCount(result.rows.count)
                    queryState.finishExecution()

                    var metadata: [String: String] = [
                        "rows": "\(result.rows.count)"
                    ]
                    let columnNames = result.columns.map(\.name).joined(separator: ", ")
                    if !columnNames.isEmpty {
                        metadata["columns"] = columnNames
                    }
                    if let commandTag = result.commandTag, !commandTag.isEmpty {
                        metadata["commandTag"] = commandTag
                    }

                    queryState.appendMessage(
                        message: "Returned \(result.rows.count) row\(result.rows.count == 1 ? "" : "s")",
                        severity: .info,
                        metadata: metadata
                    )
                    appState.addToQueryHistory(sql, resultCount: result.rows.count, duration: queryState.lastExecutionTime ?? 0)
                }
            } catch is CancellationError {
                await MainActor.run {
                    queryState.markCancellationCompleted()
                }
            } catch {
                await MainActor.run {
                    queryState.errorMessage = error.localizedDescription
                    queryState.failExecution(with: "Query execution failed: \(error.localizedDescription)")
                }
            }
        }

        await MainActor.run {
            queryState.errorMessage = nil
            queryState.results = nil
            queryState.startExecution()
            queryState.setExecutingTask(task)
        }
    }

    private func cancelQuery(tabId: UUID) {
        guard let tab = appModel.tabManager.getTab(id: tabId),
              let queryState = tab.query else { return }
        queryState.cancelExecution()
    }
}

// MARK: - Workspace Content

private struct WorkspaceContentView: View {
    @ObservedObject var tab: WorkspaceTab
    let runQuery: (String) async -> Void
    let cancelQuery: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Group {
            if let structureEditor = tab.structureEditor {
                TableStructureEditorView(tab: tab, viewModel: structureEditor)
                    .background(themeManager.windowBackground)
            } else if let query = tab.query {
                QueryEditorContainer(
                    tab: tab,
                    query: query,
                    runQuery: runQuery,
                    cancelQuery: cancelQuery
                )
            } else {
                EmptyView()
            }
        }
    }
}

private struct QueryEditorContainer: View {
    @ObservedObject var tab: WorkspaceTab
    @ObservedObject var query: QueryEditorState
    let runQuery: (String) async -> Void
    let cancelQuery: () -> Void

    private let minRatio: CGFloat = 0.25
    private let maxRatio: CGFloat = 0.8

    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height
            let ratioBinding = Binding<CGFloat>(
                get: { min(max(query.splitRatio, minRatio), maxRatio) },
                set: { newValue in
                    query.splitRatio = min(max(newValue, minRatio), maxRatio)
                }
            )

            VStack(spacing: 0) {
                QueryInputSection(
                    query: query,
                    onExecute: { sql in await runQuery(sql) },
                    onCancel: cancelQuery
                )
                .frame(height: query.hasExecutedAtLeastOnce ? totalHeight * ratioBinding.wrappedValue : totalHeight)
                .background(editorBackground)

                if query.hasExecutedAtLeastOnce {
                    ResizeHandle(
                        ratio: ratioBinding,
                        minRatio: minRatio,
                        maxRatio: maxRatio,
                        availableHeight: totalHeight
                    )

                    QueryResultsSection(query: query)
                        .frame(height: totalHeight * (1 - ratioBinding.wrappedValue))
                        .background(resultsBackground)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(.ultraThinMaterial)
    }

    private var editorBackground: Color {
#if os(macOS)
        Color(nsColor: .textBackgroundColor)
#else
        Color(uiColor: .systemBackground)
#endif
    }

    private var resultsBackground: Color {
#if os(macOS)
        Color(nsColor: .textBackgroundColor)
#else
        Color(uiColor: .systemBackground)
#endif
    }
}

// MARK: - Tab Button

private struct WorkspaceTabButton: View {
    @ObservedObject var tab: WorkspaceTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    private var shouldShowClose: Bool {
#if os(macOS)
        return isHovering || isActive
#else
        return true
#endif
    }

    var body: some View {
        HStack(spacing: 6) {
            icon
            Text(tab.title)
                .font(.system(size: 11.5))
                .foregroundStyle(isActive ? .primary : .secondary)
                .lineLimit(1)

            if shouldShowClose {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.08))
                    )
                    .contentShape(Circle())
                    .onTapGesture {
                        onClose()
                    }
                    .help("Close tab")
            } else {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.clear)
                    .frame(width: 14, height: 14)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isActive ? Color.black.opacity(0.08) : (isHovering ? Color.black.opacity(0.04) : Color.clear))
        )
        .contentShape(Capsule())
#if os(macOS)
        .onHover { hovering in
            isHovering = hovering
        }
#endif
        .onTapGesture {
            onSelect()
        }
    }

    private var icon: some View {
        Group {
            switch tab.kind {
            case .structure:
                Image(systemName: "tablecells")
                    .font(.system(size: 10, weight: .medium))
            case .query:
                Image(systemName: "doc.text")
                    .font(.system(size: 10, weight: .medium))
            }
        }
        .foregroundStyle(isActive ? .primary : .secondary)
    }
}

// MARK: - Resize Handle

private struct ResizeHandle: View {
    @Binding var ratio: CGFloat
    let minRatio: CGFloat
    let maxRatio: CGFloat
    let availableHeight: CGFloat

    @State private var dragStartRatio: CGFloat = 0
    @State private var isDragging = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .frame(height: 2)
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 60, height: 3)
        }
        .frame(height: 8)
        .background(Color.clear)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isDragging {
                        dragStartRatio = ratio
                        isDragging = true
                    }

                    let delta = value.translation.height / max(availableHeight, 1)
                    let proposed = dragStartRatio + delta
                    self.ratio = min(max(proposed, minRatio), maxRatio)
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
#if os(macOS)
        .cursor(.resizeUpDown)
#endif
    }
}

// MARK: - Tab Overview

private struct TabOverviewView: View {
    let tabs: [WorkspaceTab]
    let activeTabId: UUID?
    let onSelectTab: (UUID) -> Void
    let onCloseTab: (UUID) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 20)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(tabs) { tab in
                    TabPreviewCard(
                        tab: tab,
                        isActive: tab.id == activeTabId,
                        onSelect: { onSelectTab(tab.id) },
                        onClose: { onCloseTab(tab.id) }
                    )
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct TabPreviewCard: View {
    @ObservedObject var tab: WorkspaceTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tab.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                if isHovering {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(tab.connection.connectionName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                previewContent

                if let query = tab.query {
                    if query.isExecuting {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 12, height: 12)
                            Text("Running")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.orange)
                    } else if query.hasExecutedAtLeastOnce {
                        if query.errorMessage != nil {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10))
                                Text("Error")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(.orange)
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                Text("Success")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(.green)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 160)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isActive ? Color.accentColor.opacity(0.1) : Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isActive ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(perform: onSelect)
        .platformHover { hovering in isHovering = hovering }
    }

    @ViewBuilder
    private var previewContent: some View {
        if let query = tab.query {
            if !query.sql.isEmpty {
                Text(query.sql)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Text("Empty query")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        } else if let editor = tab.structureEditor {
            VStack(alignment: .leading, spacing: 4) {
                Text("Structure view")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("\(editor.schemaName).\(editor.tableName)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
    }
}
