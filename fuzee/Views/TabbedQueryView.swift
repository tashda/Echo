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
                QueryWorkspaceView(
                    tab: activeTab,
                    runQuery: { sql in await runQuery(tabId: activeTab.id, sql: sql) },
                    cancelQuery: { cancelQuery(tabId: activeTab.id) }
                )
            } else {
                ContentUnavailableView {
                    Label("No Query Tabs", systemImage: "doc.text")
                } description: {
                    Text("Open a connection to start querying")
                } actions: {
                    Button("New Tab", action: createNewTab)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                TabBarControls(
                    onShare: { /* TODO */ },
                    onNewTab: createNewTab,
                    onTabOverview: { appState.showTabOverview.toggle() },
                    onInfo: { appState.showInfoSidebar.toggle() },
                    isNewTabDisabled: appModel.sessionManager.activeSession == nil
                )
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
            HStack(spacing: 4) {
                ForEach(appModel.tabManager.tabs) { tab in
                    TahoeTabButton(
                        tab: tab,
                        isActive: appModel.tabManager.activeTabId == tab.id,
                        onSelect: { appModel.tabManager.activeTabId = tab.id },
                        onClose: {
                            appModel.tabManager.closeTab(id: tab.id)
                        }
                    )
                    .id(tab.id)
                    .transition(.identity)
                }
            }
            .padding(.leading, 12)
            .animation(.none, value: appModel.tabManager.tabs.count)

            Spacer()
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
        guard let tab = appModel.tabManager.getTab(id: tabId), tab.structureEditor == nil else { return }

        let task = Task { [weak tab] in
            guard let tab else { return }

            do {
                let result = try await tab.session.simpleQuery(sql)
                try Task.checkCancellation()
                await MainActor.run {
                    tab.results = result
                    tab.updateRowCount(result.rows.count)
                    tab.finishExecution()
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
                    tab.appendMessage(
                        message: "Returned \(result.rows.count) row\(result.rows.count == 1 ? "" : "s")",
                        severity: .info,
                        metadata: metadata
                    )
                    tab.sql = sql
                    appState.addToQueryHistory(sql, resultCount: result.rows.count, duration: tab.lastExecutionTime ?? 0)
                }
            } catch is CancellationError {
                await MainActor.run {
                    tab.markCancellationCompleted()
                }
            } catch {
                await MainActor.run {
                    tab.errorMessage = error.localizedDescription
                    tab.failExecution(with: "Query execution failed: \(error.localizedDescription)")
                }
            }
        }

        await MainActor.run {
            tab.errorMessage = nil
            tab.results = nil
            tab.startExecution()
            tab.setExecutingTask(task)
        }
    }

    private func cancelQuery(tabId: UUID) {
        guard let tab = appModel.tabManager.getTab(id: tabId), tab.structureEditor == nil else { return }
        tab.cancelExecution()
    }
}

private struct QueryWorkspaceView: View {
    @ObservedObject var tab: QueryTab
    let runQuery: (String) async -> Void
    let cancelQuery: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager

    private let minRatio: CGFloat = 0.25
    private let maxRatio: CGFloat = 0.8

    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height
            let ratioBinding = Binding<CGFloat>(
                get: { min(max(tab.splitRatio, minRatio), maxRatio) },
                set: { newValue in
                    tab.splitRatio = min(max(newValue, minRatio), maxRatio)
                }
            )

            if let editor = tab.structureEditor {
                TableStructureEditorView(tab: tab, viewModel: editor)
                    .background(themeManager.windowBackground)
            } else {
                VStack(spacing: 0) {
                    QueryInputSection(
                        tab: tab,
                        onExecute: { sql in await runQuery(sql) },
                        onCancel: cancelQuery
                    )
                    .frame(height: tab.hasExecutedAtLeastOnce ? totalHeight * ratioBinding.wrappedValue : totalHeight)

                    if tab.hasExecutedAtLeastOnce {
                        ResizeHandle(
                            ratio: ratioBinding,
                            minRatio: minRatio,
                            maxRatio: maxRatio,
                            availableHeight: totalHeight
                        )

                        QueryResultsSection(tab: tab)
                            .frame(height: totalHeight * (1 - ratioBinding.wrappedValue))
                            .transition(.opacity)
                    }
                }
                .background(themeManager.windowBackground)
            }
        }
    }
}

private struct TabBarControls: View {
    let onShare: () -> Void
    let onNewTab: () -> Void
    let onTabOverview: () -> Void
    let onInfo: () -> Void
    let isNewTabDisabled: Bool

    var body: some View {
        HStack(spacing: 8) {
            TabBarButton(icon: "square.and.arrow.up", action: onShare)
            TabBarButton(icon: "plus", action: onNewTab, isDisabled: isNewTabDisabled)
            TabBarButton(icon: "square.grid.2x2", action: onTabOverview)
            TabBarButton(icon: "sidebar.right", action: onInfo)
        }
    }
}

private struct TabBarButton: View {
    let icon: String
    let action: () -> Void
    var isDisabled: Bool = false

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(isDisabled ? .quaternary : .secondary)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovering && !isDisabled ? Color.black.opacity(0.06) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
#if os(macOS)
        .onHover { hovering in
            isHovering = hovering
        }
#endif
    }
}

private struct TahoeTabButton: View {
    @ObservedObject var tab: QueryTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            if tab.structureEditor != nil {
                Image(systemName: "tablecells")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isActive ? .primary : .secondary)
            }
            Text(tab.title)
                .font(.system(size: 11.5))
                .foregroundStyle(isActive ? .primary : .secondary)
                .lineLimit(1)

            if isHovering {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 14, height: 14)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.08))
                        )
                        .accessibilityLabel("Close tab")
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(isActive ? Color.black.opacity(0.08) : (isHovering ? Color.black.opacity(0.04) : Color.clear))
        )
        .contentShape(Capsule())
#if os(macOS)
        .background(MiddleClickHandler(onMiddleClick: onClose, onLeftClick: onSelect))
        .onHover { hovering in
            isHovering = hovering
        }
#else
        .onTapGesture(perform: onSelect)
#endif
    }
}

#if os(macOS)
private struct MiddleClickHandler: NSViewRepresentable {
    let onMiddleClick: () -> Void
    let onLeftClick: () -> Void

    func makeNSView(context: Context) -> ClickCaptureView {
        let view = ClickCaptureView()
        view.onMiddleClick = onMiddleClick
        view.onLeftClick = onLeftClick
        return view
    }

    func updateNSView(_ nsView: ClickCaptureView, context: Context) {
        nsView.onMiddleClick = onMiddleClick
        nsView.onLeftClick = onLeftClick
    }

    class ClickCaptureView: NSView {
        var onMiddleClick: (() -> Void)?
        var onLeftClick: (() -> Void)?

        override func mouseDown(with event: NSEvent) {
            if event.buttonNumber == 0 {
                DispatchQueue.main.async {
                    self.onLeftClick?()
                }
            }
        }

        override func otherMouseDown(with event: NSEvent) {
            if event.buttonNumber == 2 {
                DispatchQueue.main.async {
                    self.onMiddleClick?()
                }
            }
        }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            return true
        }
    }
}
#endif

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

private struct TabOverviewView: View {
    let tabs: [QueryTab]
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
    @ObservedObject var tab: QueryTab
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

                if !tab.sql.isEmpty {
                    Text(tab.sql)
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

                HStack(spacing: 12) {
                    if tab.isExecuting {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 12, height: 12)
                            Text("Running")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.orange)
                    } else if tab.hasExecutedAtLeastOnce {
                        if tab.errorMessage != nil {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10))
                                Text("Failed")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(.red)
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

                    if let executionTime = tab.lastExecutionTime {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(String(format: "%.3fs", executionTime))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                    }

                    if let rowCount = tab.currentRowCount {
                        HStack(spacing: 6) {
                            Image(systemName: "tablecells")
                                .font(.system(size: 10))
                            Text("\(rowCount) row\(rowCount == 1 ? "" : "s")")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isActive ? Color.accentColor : Color.primary.opacity(0.1),
                    lineWidth: isActive ? 2 : 1
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(perform: onSelect)
#if os(macOS)
        .onHover { hovering in
            isHovering = hovering
        }
#endif
    }
}
