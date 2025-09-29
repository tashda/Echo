import SwiftUI

struct TabbedQueryView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var splitViewHeight: CGFloat = 0.33

    var body: some View {
        VStack(spacing: 0) {
            tabBar

            if let activeTab = appModel.tabManager.activeTab {
                GeometryReader { geometry in
                    let totalHeight = geometry.size.height
                    let queryHeight = totalHeight * splitViewHeight
                    let resultsHeight = totalHeight * (1 - splitViewHeight)

                    VStack(spacing: 0) {
                        QueryInputSection(tab: activeTab) { sql in
                            await runQuery(tabId: activeTab.id, sql: sql)
                        }
                        .frame(height: queryHeight)

                        ResizeHandle(
                            splitRatio: $splitViewHeight,
                            minRatio: 0.2,
                            maxRatio: 0.8,
                            availableHeight: totalHeight
                        )

                        QueryResultsSection(tab: activeTab)
                            .frame(height: resultsHeight)
                    }
                }
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
        .onAppear(perform: createInitialTabIfNeeded)
        .onChange(of: appModel.selectedConnection) { _, _ in
            createInitialTabIfNeeded()
        }
    }

    @ViewBuilder
    private var tabBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(appModel.tabManager.tabs) { tab in
                        TabButton(
                            tab: tab,
                            isActive: appModel.tabManager.activeTabId == tab.id,
                            onSelect: { appModel.tabManager.activeTabId = tab.id },
                            onClose: { appModel.tabManager.closeTab(id: tab.id) }
                        )
                    }
                }
            }

            Spacer()

            Button(action: createNewTab) {
                Image(systemName: "plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 8)
            .disabled(appModel.sessionManager.activeSession == nil)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(themeManager.windowBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.separator),
            alignment: .bottom
        )
    }

    private func createInitialTabIfNeeded() {
        guard appModel.tabManager.tabs.isEmpty,
              let connection = appModel.selectedConnection,
              let activeSession = appModel.sessionManager.activeSession else { return }

        appModel.tabManager.addTab(connection: connection, session: activeSession.session)
    }

    private func createNewTab() {
        guard let connection = appModel.selectedConnection,
              let activeSession = appModel.sessionManager.activeSession else { return }

        let tabNumber = appModel.tabManager.tabs.count + 1
        appModel.tabManager.addTab(
            connection: connection,
            session: activeSession.session,
            title: "\(connection.connectionName) \(tabNumber)"
        )
    }

    private func runQuery(tabId: UUID, sql: String) async {
        guard let tab = appModel.tabManager.getTab(id: tabId) else { return }

        await MainActor.run {
            tab.errorMessage = nil
            tab.results = nil
            tab.startExecution()
        }

        do {
            let result = try await tab.session.simpleQuery(sql)
            await MainActor.run {
                tab.results = result
                tab.finishExecution()
                tab.sql = sql
                appState.addToQueryHistory(sql, resultCount: result.rows.count, duration: tab.lastExecutionTime ?? 0)
            }
        } catch {
            await MainActor.run {
                tab.errorMessage = error.localizedDescription
                tab.finishExecution()
            }
        }
    }
}

struct TabButton: View {
    let tab: QueryTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tab.connection.color)
                .frame(width: 8, height: 8)

            Text(tab.title)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(isActive ? .primary : .secondary)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .opacity(isActive ? 1 : 0.7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

private struct ResizeHandle: View {
    @Binding var splitRatio: CGFloat
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
                        dragStartRatio = splitRatio
                        isDragging = true
                    }

                    let delta = value.translation.height / max(availableHeight, 1)
                    let proposed = dragStartRatio + delta
                    splitRatio = min(max(proposed, minRatio), maxRatio)
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
