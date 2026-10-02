import SwiftUI
#if os(macOS)
import AppKit
#endif

/// The inspector's History page (round IC on round 39's HG0, HR0, HP0): runs by day, newest
/// first, in grouped boxes. Each row is the whole statement on one line with its time, then the
/// server's dot, database, result and duration. A click opens the row in place (the statement,
/// the server's message for a failed run, Open, Insert, Copy, ☆); double-click or Return opens a
/// tab without running it. A run on a server that isn't connected offers Connect and Open.
struct QueryHistoryPanelView: View {
    let connectionID: UUID?
    @Environment(AppState.self) private var appState
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(ProjectStore.self) private var projectStore
    @Environment(\.echoMotion) private var motion
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    @State private var search = ""
    @State private var failedOnly = false
    @State private var scopeConnectionID: UUID?
    @State private var selectedID: UUID?
    @State private var isConfirmingClear = false
    @FocusState private var isListFocused: Bool

    var body: some View {
        let groups = groupedRuns()
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            InspectorPageHeader(summary: summary) { menu }
            InspectorSearchField(text: $search, prompt: "Search history",
                                 token: scopeName, onRemoveToken: { scopeConnectionID = nil })
            if let optedOut = optedOutServerName {
                Label("Not keeping history for \(optedOut)", systemImage: "info.circle")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .padding(.horizontal, SpacingTokens.md)
                    .padding(.bottom, SpacingTokens.xxs2)
            }
            if groups.isEmpty {
                emptyState
            } else {
                list(groups)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(motion.standard, value: selectedID)
        .alert("Clear \(appState.queryHistory.count) runs from History?", isPresented: $isConfirmingClear) {
            Button("Clear History", role: .destructive) { appState.clearQueryHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
    }

    // MARK: - List

    private func list(_ groups: [HistoryDay]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SpacingTokens.none, pinnedViews: [.sectionHeaders]) {
                    ForEach(groups) { day in
                        Section {
                            InspectorGroupBox {
                                ForEach(Array(day.runs.enumerated()), id: \.element.id) { index, run in
                                    row(run, showsSeparator: index > 0)
                                        .id(run.id)
                                }
                            }
                        } header: {
                            InspectorGroupHeading(title: day.title, count: day.runs.count)
                                .background(ColorTokens.Workspace.card)
                        }
                    }
                }
                .padding(.bottom, SpacingTokens.xs)
            }
            .scrollIndicators(.automatic)
            .focusable()
            .focused($isListFocused)
            .focusEffectDisabled()
            .onKeyPress(.downArrow) { move(by: 1, in: groups, proxy: proxy) }
            .onKeyPress(.upArrow) { move(by: -1, in: groups, proxy: proxy) }
            .onKeyPress(.return) { activateSelection(in: groups, insert: NSEvent.modifierFlags.contains(.option)) }
            .onKeyPress(.delete) { deleteSelection(in: groups) }
            .onKeyPress(.escape) {
                guard selectedID != nil else { return .ignored }
                selectedID = nil
                return .handled
            }
        }
    }

    private func row(_ run: HistoryRun, showsSeparator: Bool) -> some View {
        let item = run.latest
        let server = serverInfo(for: item)
        let isSelected = selectedID == run.id
        return InspectorListRow(isSelected: isSelected, showsSeparator: showsSeparator,
                                quickOpen: server.isKnown
                                    ? (title: server.isConnected ? "Open in New Tab" : "Connect and Open", action: { open(item) })
                                    : nil) {
            outcomeGlyph(item)
        } title: {
            Text(InspectorListFormat.oneLine(item.query))
                .font(TypographyTokens.Table.sql.weight(.regular))
                .foregroundStyle(ColorTokens.Text.primary)
        } trailing: {
            HStack(spacing: SpacingTokens.xxs1) {
                if run.items.count > 1 {
                    Text("×\(run.items.count)")
                        .font(TypographyTokens.compact.weight(.semibold))
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .padding(.horizontal, SpacingTokens.xxs1)
                        .background(ColorTokens.Sidebar.hoverFill, in: Capsule())
                }
                Text(InspectorListFormat.time(item.timestamp))
            }
        } detail: {
            InspectorRowDetail(serverColor: server.color, isConnected: server.isConnected, text: detailText(item))
        } opened: {
            opened(run, server: server)
        }
        .onTapGesture(count: 2) { open(item) }
        .onTapGesture {
            isListFocused = true
            #if os(macOS)
            if NSEvent.modifierFlags.contains(.option) {
                selectedID = run.id
                insert(item)
                return
            }
            #endif
            selectedID = isSelected ? nil : run.id
        }
        .contextMenu { contextMenu(for: run, server: server) }
        .help(server.name.map { "\($0) · \(item.databaseName ?? "")" } ?? "")
    }

    @ViewBuilder
    private func opened(_ run: HistoryRun, server: ServerInfo) -> some View {
        let item = run.latest
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            InspectorSQLText(sql: item.query)
            if item.outcome == "Failed", let message = item.errorMessage, !message.isEmpty {
                InspectorOpenedNote(text: message, isError: true)
            }
            if run.items.count > 1 {
                InspectorOpenedNote(text: "Ran \(run.items.count) times: " + run.items.map { InspectorListFormat.time($0.timestamp) }.joined(separator: ", "))
            }
            InspectorOpenedNote(text: [server.name, item.databaseName].compactMap { $0 }.joined(separator: " · ")
                                + (server.isConnected ? "" : " · not connected"))
            InspectorRowActions {
                Button(server.isConnected ? "Open" : "Connect and Open") { open(item) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!server.isKnown)
                Button("Insert") { insert(item) }
                    .disabled(!environmentState.canInsertIntoActiveEditor)
                    .help("Insert at the cursor (⌥↩)")
                Button("Copy") { copy(item) }
                Button {
                    addToBookmarks(item)
                } label: {
                    Image(systemName: "star")
                }
                .help("Add to Bookmarks…")
                .accessibilityLabel("Add to Bookmarks")
                .disabled(!server.isKnown)
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for run: HistoryRun, server: ServerInfo) -> some View {
        let item = run.latest
        Button(server.isConnected ? "Open in New Tab" : "Connect and Open", systemImage: "arrow.up.right.square") { open(item) }
            .disabled(!server.isKnown)
        Button("Insert at Cursor", systemImage: "text.insert") { insert(item) }
            .disabled(!environmentState.canInsertIntoActiveEditor)
        Divider()
        Button("Copy SQL", systemImage: "doc.on.doc") { copy(item) }
        Button("Add to Bookmarks…", systemImage: "star") { addToBookmarks(item) }
            .disabled(!server.isKnown)
        if let id = item.connectionID, let name = server.name {
            Divider()
            Button("Show Only \(name)", systemImage: "line.3.horizontal.decrease") { scopeConnectionID = id }
        }
        Divider()
        Button("Delete from History", systemImage: "trash", role: .destructive) {
            appState.removeFromQueryHistory(Set(run.items.map(\.id)))
            if selectedID == run.id { selectedID = nil }
        }
    }

    private var menu: some View {
        Menu {
            Picker("Show", selection: $failedOnly) {
                Text("All Runs").tag(false)
                Text("Failed Only").tag(true)
            }
            .pickerStyle(.inline)
            if let front = frontConnection {
                Toggle("Only \(front.name)", isOn: Binding(
                    get: { scopeConnectionID == front.id },
                    set: { scopeConnectionID = $0 ? front.id : nil }
                ))
            }
            Divider()
            Button("History Settings…") { openHistorySettings() }
            Divider()
            Button("Clear History…", role: .destructive) { isConfirmingClear = true }
                .disabled(appState.queryHistory.isEmpty)
        } label: {
            Label("Show, Clear History, Settings", systemImage: "ellipsis.circle")
        }
        .help("Show, Clear History, Settings")
    }

    // MARK: - Pieces

    @ViewBuilder
    private func outcomeGlyph(_ item: QueryHistoryItem) -> some View {
        switch item.outcome {
        case "Failed":
            Image(systemName: "xmark.circle.fill").foregroundStyle(ColorTokens.Status.error).help("Failed")
        case "Cancelled":
            Image(systemName: "minus.circle.fill").foregroundStyle(ColorTokens.Text.tertiary).help("Cancelled")
        default:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(ColorTokens.Status.success).help("Succeeded")
        }
    }

    private func detailText(_ item: QueryHistoryItem) -> Text {
        var parts: [Text] = []
        if let database = item.databaseName, !database.isEmpty { parts.append(Text(database)) }
        switch item.outcome {
        case "Failed": parts.append(Text("Failed").foregroundStyle(ColorTokens.Status.error))
        case "Cancelled": parts.append(Text("Cancelled"))
        default:
            if let count = item.resultCount {
                parts.append(Text("\(count.formatted()) \(count == 1 ? "row" : "rows")"))
            } else {
                parts.append(Text("Done"))
            }
        }
        if let duration = item.duration { parts.append(Text(InspectorListFormat.duration(duration))) }
        return parts.dropFirst().reduce(parts.first ?? Text("")) { $0 + Text(" · ") + $1 }
    }

    private var emptyState: some View {
        Group {
            if !search.isEmpty || failedOnly || scopeConnectionID != nil {
                InspectorEmptyState(systemImage: "magnifyingglass",
                                    title: search.isEmpty ? "No Matching Runs" : "No Results for “\(search)”",
                                    message: scopeConnectionID != nil ? "Only \(scopeName ?? "one server") is searched." : "Try another word, server or database.") {
                    if scopeConnectionID != nil {
                        Button("Search All Servers") { scopeConnectionID = nil }
                    } else if failedOnly {
                        Button("Show All Runs") { failedOnly = false }
                    }
                }
            } else {
                InspectorEmptyState(systemImage: "clock", title: "No History", message: "Queries you run show here.") {
                    Button("History Settings…") { openHistorySettings() }
                }
            }
        }
    }

    private var summary: String {
        let count = appState.queryHistory.filter { isInProject($0) }.count
        return count == 0 ? "No runs" : "\(count.formatted()) \(count == 1 ? "run" : "runs")"
    }

    // MARK: - Data

    private struct ServerInfo {
        let name: String?
        let color: Color
        let isConnected: Bool
        let isKnown: Bool
    }

    private func serverInfo(for item: QueryHistoryItem) -> ServerInfo {
        let saved = item.connectionID.flatMap { id in connectionStore.connections.first { $0.id == id } }
        let session = item.connectionID.flatMap { id in environmentState.sessionGroup.activeSessions.first { $0.connection.id == id } }
        let connection = saved ?? session?.connection
        let name = connection.map { $0.connectionName.isEmpty ? $0.host : $0.connectionName } ?? item.connectionName
        return ServerInfo(name: name, color: connection?.color ?? ColorTokens.Text.tertiary,
                          isConnected: session != nil, isKnown: connection != nil)
    }

    private var frontConnection: (id: UUID, name: String)? {
        guard let connection = environmentState.tabStore.activeTab?.connection else { return nil }
        return (connection.id, connection.connectionName.isEmpty ? connection.host : connection.connectionName)
    }

    private var scopeName: String? {
        guard let scopeConnectionID else { return nil }
        let connection = connectionStore.connections.first { $0.id == scopeConnectionID }
        return connection.map { $0.connectionName.isEmpty ? $0.host : $0.connectionName } ?? "One server"
    }

    private var optedOutServerName: String? {
        guard let connection = environmentState.tabStore.activeTab?.connection,
              let saved = connectionStore.connections.first(where: { $0.id == connection.id }),
              !saved.keepsQueryHistory else { return nil }
        return saved.connectionName.isEmpty ? saved.host : saved.connectionName
    }

    private func isInProject(_ item: QueryHistoryItem) -> Bool {
        let projectID = projectStore.selectedProject?.id
        guard let id = item.connectionID else { return false }
        if let saved = connectionStore.connections.first(where: { $0.id == id }) { return saved.projectID == projectID }
        return environmentState.sessionGroup.sessions.contains { $0.connection.id == id && $0.connection.projectID == projectID }
    }

    /// One pass over the history: the project's runs that match, repeats folded, grouped by day.
    private func groupedRuns() -> [HistoryDay] {
        let projectID = projectStore.selectedProject?.id
        let projectIDs = Set(connectionStore.connections.filter { $0.projectID == projectID }.map(\.id)
                             + environmentState.sessionGroup.sessions.filter { $0.connection.projectID == projectID }.map { $0.connection.id })
        let names = Dictionary(connectionStore.connections.map { ($0.id, $0.connectionName.isEmpty ? $0.host : $0.connectionName) },
                               uniquingKeysWith: { first, _ in first })
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let calendar = Calendar.current
        var days: [HistoryDay] = []
        for item in appState.queryHistory {
            guard let id = item.connectionID, projectIDs.contains(id) else { continue }
            if let connectionID, connectionID != id { continue }
            if let scopeConnectionID, scopeConnectionID != id { continue }
            if failedOnly, item.outcome != "Failed" { continue }
            if !term.isEmpty {
                let fields = [item.query, item.databaseName ?? "", names[id] ?? item.connectionName ?? "", item.errorMessage ?? ""]
                guard fields.contains(where: { $0.localizedCaseInsensitiveContains(term) }) else { continue }
            }
            let day = calendar.startOfDay(for: item.timestamp)
            if days.last?.day != day {
                days.append(HistoryDay(day: day, title: InspectorListFormat.dayTitle(day), runs: []))
            }
            // A repeat: the same statement on the same server and database, with nothing between.
            if let last = days[days.count - 1].runs.last?.latest, last.query == item.query,
               last.connectionID == item.connectionID, last.databaseName == item.databaseName, last.outcome == item.outcome {
                days[days.count - 1].runs[days[days.count - 1].runs.count - 1].items.append(item)
            } else {
                days[days.count - 1].runs.append(HistoryRun(items: [item]))
            }
        }
        return days
    }

    // MARK: - Actions

    private func open(_ item: QueryHistoryItem) {
        environmentState.openSavedQuery(sql: item.query, connectionID: item.connectionID, database: item.databaseName)
    }

    private func insert(_ item: QueryHistoryItem) {
        guard environmentState.canInsertIntoActiveEditor else { return }
        environmentState.insertIntoActiveEditor(item.query)
    }

    private func copy(_ item: QueryHistoryItem) {
        copyToGeneralPasteboard(item.query)
    }

    private func addToBookmarks(_ item: QueryHistoryItem) {
        environmentState.requestBookmark(sql: item.query, connectionID: item.connectionID, database: item.databaseName, suggestedName: nil)
    }

    private func openHistorySettings() {
        #if os(macOS)
        openWindow(id: SettingsWindowScene.sceneID)
        NotificationCenter.default.post(name: .openSettingsSection, object: "applicationCache")
        #endif
    }

    private func flatRuns(_ groups: [HistoryDay]) -> [HistoryRun] { groups.flatMap(\.runs) }

    private func move(by step: Int, in groups: [HistoryDay], proxy: ScrollViewProxy) -> KeyPress.Result {
        let runs = flatRuns(groups)
        guard !runs.isEmpty else { return .ignored }
        let current = runs.firstIndex { $0.id == selectedID }
        let next = current.map { min(max($0 + step, 0), runs.count - 1) } ?? (step > 0 ? 0 : runs.count - 1)
        selectedID = runs[next].id
        proxy.scrollTo(runs[next].id)
        return .handled
    }

    private func activateSelection(in groups: [HistoryDay], insert asInsert: Bool) -> KeyPress.Result {
        guard let run = flatRuns(groups).first(where: { $0.id == selectedID }) else { return .ignored }
        if asInsert { insert(run.latest) } else { open(run.latest) }
        return .handled
    }

    private func deleteSelection(in groups: [HistoryDay]) -> KeyPress.Result {
        guard let run = flatRuns(groups).first(where: { $0.id == selectedID }) else { return .ignored }
        appState.removeFromQueryHistory(Set(run.items.map(\.id)))
        selectedID = nil
        return .handled
    }
}

/// A day of History: its runs, newest first.
struct HistoryDay: Identifiable {
    let day: Date
    let title: String
    var runs: [HistoryRun]
    var id: Date { day }
}

/// One row of History: a run, or the same statement run several times in a row (newest first).
struct HistoryRun: Identifiable {
    var items: [QueryHistoryItem]
    var latest: QueryHistoryItem { items[0] }
    var id: UUID { items[0].id }
}
