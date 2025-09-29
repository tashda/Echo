import SwiftUI

struct TabbedQueryView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var splitViewHeight: CGFloat = 0.33 // Query takes 1/3, results take 2/3

    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            tabBar

            if let activeTab = appModel.tabManager.activeTab {
                // Resizable Split View
                GeometryReader { geometry in
                    let totalHeight = geometry.size.height
                    let queryHeight = totalHeight * splitViewHeight
                    let resultsHeight = totalHeight * (1 - splitViewHeight)

                    VStack(spacing: 0) {
                        // Query Section (Top)
                        QueryInputSection(
                            tab: activeTab,
                            onExecute: { sql in
                                await streamQuery(tabId: activeTab.id, sql: sql)
                            }
                        )
                        .frame(height: queryHeight)

                        // Resize Handle
                        ResizeHandle(
                            splitRatio: $splitViewHeight,
                            minRatio: 0.2,
                            maxRatio: 0.8
                        )

                        // Results Section (Bottom)
                        QueryResultsSection(tab: activeTab)
                            .frame(height: resultsHeight)
                    }
                }
            } else {
                // No tabs open
                ContentUnavailableView {
                    Label("No Query Tabs", systemImage: "doc.text")
                } description: {
                    Text("Open a connection to start querying")
                } actions: {
                    Button("New Tab") {
                        createNewTab()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .onAppear {
            // Create initial tab if connected
            createInitialTabIfNeeded()
        }
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
              let session = activeSession.session

        appModel.tabManager.addTab(connection: connection, session: session)
    }

    private func createNewTab() {
        guard let connection = appModel.selectedConnection,
              let activeSession = appModel.sessionManager.activeSession else { return }
              let session = activeSession.session

        let tabNumber = appModel.tabManager.tabs.count + 1
        appModel.tabManager.addTab(
            connection: connection,
            session: session,
            title: "\(connection.connectionName) \(tabNumber)"
        )
    }

    private func streamQuery(tabId: UUID, sql: String) async {
        guard let tab = appModel.tabManager.getTab(id: tabId) else { return }

        await MainActor.run {
            tab.errorMessage = nil
            tab.results = nil
            tab.startExecution()
        }

        do {
            let stream = tab.session.streamQuery(sql)
            for try await event in stream {
                await MainActor.run {
                    switch event {
                    case .columns(let columnInfo):
                        tab.results = QueryResultSet(columns: columnInfo)
                    case .row(let rowData):
                        tab.results?.rows.append(rowData)
                        tab.updateRowCount(tab.results?.rows.count ?? 0)
                    case .success(let commandTag):
                        tab.results?.commandTag = commandTag
                        tab.results?.totalRowCount = tab.results?.rows.count
                    }
                }
            }

            await MainActor.run {
                tab.finishExecution()
                tab.sql = sql
                appState.addToQueryHistory(sql, resultCount: tab.results?.rows.count, duration: tab.lastExecutionTime ?? 0)
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
            // Connection color indicator
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

struct ResizeHandle: View {
    @Binding var splitRatio: CGFloat
    let minRatio: CGFloat
    let maxRatio: CGFloat
    @State private var isDragging = false

    var body: some View {
        Rectangle()
            .fill(.separator)
            .frame(height: 1)
            .background(
                Rectangle()
                    .fill(.clear)
                    .frame(height: 8)
                    .contentShape(Rectangle())
                    #if os(macOS)
                    .cursor(.resizeUpDown)
                    #endif
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                let parentHeight: CGFloat = 600 // This should be the parent geometry
                                let newRatio = splitRatio + (value.translation.height / parentHeight)
                                splitRatio = min(max(newRatio, minRatio), maxRatio)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            )
    }
}