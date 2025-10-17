import SwiftUI
import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

private func toolbarIdleFill(for scheme: ColorScheme) -> Color {
#if os(macOS)
    if let active = NSApplication.shared.windows.first?.isKeyWindow, !active {
        return Color.secondary.opacity(scheme == .dark ? 0.55 : 0.45)
    }
    return Color.secondary.opacity(scheme == .dark ? 0.65 : 0.55)
#elseif canImport(UIKit)
    return Color(uiColor: .secondarySystemBackground)
#else
    return Color.primary.opacity(scheme == .dark ? 0.28 : 0.08)
#endif
}

struct WorkspaceToolbarItems: ToolbarContent {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var navigationState: NavigationState

    var body: some ToolbarContent {
#if os(macOS)
        macToolbar
#else
        iosToolbar
#endif
    }

#if os(macOS)
    @ToolbarContentBuilder
    private var macToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            projectMenu
        }

        ToolbarItem(placement: .principal) {
            ToolbarPrincipalSpacer()
        }

        ToolbarItemGroup(placement: .primaryAction) {
            refreshButton
            newTabButton
            tabOverviewButton
            inspectorButton
        }
    }
#else
    @ToolbarContentBuilder
    private var iosToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            projectMenu
        }

        let showConnectionControls = false
        if showConnectionControls {
            ToolbarItemGroup(placement: .navigation) {
                connectionsMenu
                databaseMenu
            }
        }

        ToolbarItem(placement: .primaryAction) {
            refreshButton
        }

        ToolbarItem(placement: .primaryAction) {
            newTabButton
        }

        ToolbarItem(placement: .primaryAction) {
            tabOverviewButton
        }

        ToolbarItem(placement: .primaryAction) {
            inspectorButton
        }
    }
#endif

    // MARK: - Project Menu

    private var projectMenu: some View {
        Menu {
            if appModel.projects.isEmpty {
                Text("No Projects Available").foregroundStyle(.secondary)
            } else {
                ForEach(appModel.projects) { project in
                    Button {
                        navigationState.selectProject(project)
                        appModel.selectedProject = project
                    } label: {
                        menuRow(
                            icon: projectIcon,
                            title: project.name,
                            isSelected: project.id == currentProject?.id
                        )
                    }
                }
            }

            Divider()

            Button("Manage Projects…") {
                appModel.showManageProjectsSheet = true
            }
        } label: {
            toolbarButtonLabel(
                icon: projectIcon,
                title: currentProject?.name ?? "Project"
            )
        }
    }

    // MARK: - Toolbar Buttons

    private var refreshButton: some View {
        RefreshToolbarButton()
            .labelStyle(.iconOnly)
    }

    private var newTabButton: some View {
        Button {
            appModel.openQueryTab()
        } label: {
            Label("New Tab", systemImage: "plus")
        }
        .help("Open a new query tab")
        .disabled(!canOpenNewTab)
        .labelStyle(.iconOnly)
        .accessibilityLabel("New Tab")
    }

    private var tabOverviewButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.showTabOverview.toggle()
            }
        } label: {
            Label(
                appState.showTabOverview ? "Hide Tab Overview" : "Tab Overview",
                systemImage: appState.showTabOverview ? "rectangle.grid.2x2.fill" : "rectangle.grid.2x2"
            )
        }
        .help(appState.showTabOverview ? "Hide Tab Overview" : "Show all tabs")
        .disabled(appModel.tabManager.tabs.isEmpty)
        .labelStyle(.iconOnly)
        .accessibilityLabel(appState.showTabOverview ? "Hide Tab Overview" : "Show Tab Overview")
    }

    private var inspectorButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.showInfoSidebar.toggle()
            }
        } label: {
            Label(
                appState.showInfoSidebar ? "Hide Inspector" : "Show Inspector",
                systemImage: appState.showInfoSidebar ? "sidebar.trailing" : "sidebar.right"
            )
        }
        .help(appState.showInfoSidebar ? "Hide Inspector" : "Show Inspector")
        .labelStyle(.iconOnly)
        .accessibilityLabel(appState.showInfoSidebar ? "Hide Inspector" : "Show Inspector")
    }

    // MARK: - Connections Menu

    private var connectionsMenu: some View {
#if os(macOS)
        EmptyView()
#else
        Menu {
            if appModel.connections.isEmpty {
                Text("No Connections Available").foregroundStyle(.secondary)
            } else {
                connectionMenuItems(parentID: nil)
            }

            Divider()

            Button("Manage Connections…") {
                #if os(macOS)
                ManageConnectionsWindowController.shared.present()
                #else
                appModel.isManageConnectionsPresented = true
                #endif
            }
        } label: {
            toolbarButtonLabel(
                icon: currentServerIcon,
                title: currentServerTitle
            )
        }
        .disabled(appModel.connections.isEmpty)
#endif
    }

    private func connectionMenuItems(parentID: UUID?) -> AnyView {
        let folders = appModel.folders
            .filter { $0.kind == .connections && $0.parentFolderID == parentID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let connections = appModel.connections
            .filter { $0.folderID == parentID }
            .sorted { displayName(for: $0).localizedCaseInsensitiveCompare(displayName(for: $1)) == .orderedAscending }

        return AnyView(
            Group {
                ForEach(folders, id: \.id) { folder in
                    Menu {
                        connectionMenuItems(parentID: folder.id)
                    } label: {
                        menuRow(icon: ToolbarIcon.system("folder"), title: folder.name)
                    }
                }

                ForEach(connections, id: \.id) { connection in
                    Button {
                        Task {
                            appModel.selectedConnectionID = connection.id
                            await appModel.connect(to: connection)
                        }
                    } label: {
                        menuRow(
                            icon: connectionIcon(for: connection),
                            title: displayName(for: connection),
                            isSelected: navigationState.selectedConnection?.id == connection.id
                        )
                    }
                }
            }
        )
    }

    // MARK: - Database Menu

    private var databaseMenu: some View {
#if os(macOS)
        EmptyView()
#else
        Menu {
            if let session = activeSession,
               let databases = availableDatabases(in: session),
               !databases.isEmpty {
                ForEach(databases, id: \.name) { database in
                    Button {
                        selectDatabase(database.name, in: session)
                    } label: {
                        menuRow(
                            icon: databaseMenuIcon,
                            title: database.name,
                            isSelected: session.selectedDatabaseName == database.name
                        )
                    }
                }
            } else {
                Text("No Databases Available").foregroundStyle(.secondary)
            }

            Divider()

            Button("Refresh Databases") {
                Task {
                    if let session = activeSession {
                        await appModel.refreshDatabaseStructure(for: session.id, scope: .full)
                    }
                }
            }
            .disabled(activeSession == nil)
        } label: {
            toolbarButtonLabel(
                icon: databaseToolbarIcon(isSelected: navigationState.selectedDatabase != nil),
                title: currentDatabaseTitle
            )
        }
        .disabled(activeSession == nil)
#endif
    }

    // MARK: - Helpers

    private var canOpenNewTab: Bool {
        guard let session = activeSession else { return false }
        return hasActiveDatabase(for: session)
    }

    private var activeSession: ConnectionSession? {
        if let connection = navigationState.selectedConnection,
           let session = appModel.sessionManager.sessionForConnection(connection.id) {
            return session
        }
        return appModel.sessionManager.activeSession ?? appModel.sessionManager.activeSessions.first
    }

    private func hasActiveDatabase(for session: ConnectionSession) -> Bool {
        func normalized(_ value: String?) -> String? {
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty else {
                return nil
            }
            return trimmed
        }

        if normalized(navigationState.selectedDatabase) != nil { return true }
        if normalized(session.selectedDatabaseName) != nil { return true }
        return normalized(session.connection.database) != nil
    }

    private func availableDatabases(in session: ConnectionSession) -> [DatabaseInfo]? {
        if let structure = session.databaseStructure {
            return structure.databases
        }
        if let cached = session.connection.cachedStructure {
            return cached.databases
        }
        return nil
    }

    private func selectDatabase(_ database: String, in session: ConnectionSession) {
        Task {
            await appModel.loadSchemaForDatabase(database, connectionSession: session)
            await MainActor.run {
                navigationState.selectDatabase(database)
            }
        }
    }

    private func displayName(for connection: SavedConnection) -> String {
        let trimmed = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        let hostTrimmed = connection.host.trimmingCharacters(in: .whitespacesAndNewlines)
        return hostTrimmed.isEmpty ? "Untitled Connection" : hostTrimmed
    }

    private var currentProject: Project? {
        if let selected = navigationState.selectedProject ?? appModel.selectedProject {
            return selected
        }
        if let defaultProject = appModel.projects.first(where: { $0.isDefault }) ?? appModel.projects.first {
            DispatchQueue.main.async {
                if self.navigationState.selectedProject == nil {
                    self.navigationState.selectProject(defaultProject)
                }
                if self.appModel.selectedProject == nil {
                    self.appModel.selectedProject = defaultProject
                }
            }
            return defaultProject
        }
        return nil
    }

    private var currentServerTitle: String {
        if let connection = navigationState.selectedConnection {
            let display = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
            return display.isEmpty ? connection.host : display
        }
        return "Server"
    }

    private var currentDatabaseTitle: String {
        navigationState.selectedDatabase ?? "Database"
    }

    private var projectIcon: ToolbarIcon { .system("folder.badge.person.crop") }

    private var currentServerIcon: ToolbarIcon {
        if let connection = navigationState.selectedConnection {
            return connectionIcon(for: connection)
        }
        return .system("externaldrive")
    }

    private func connectionIcon(for connection: SavedConnection) -> ToolbarIcon {
        let assetName = connection.databaseType.iconName
        if hasImage(named: assetName) {
            return .asset(assetName, isTemplate: false)
        }
        return .system("externaldrive")
    }

    private func databaseToolbarIcon(isSelected: Bool) -> ToolbarIcon {
        let assetName = isSelected ? "database.check.outlined" : "database.outlined"
        if hasImage(named: assetName) {
            return .asset(assetName, isTemplate: false)
        }
        let fallbackName = isSelected ? "checkmark.circle" : "cylinder.split.1x2"
        return .system(fallbackName)
    }

    private var databaseMenuIcon: ToolbarIcon {
        if hasImage(named: "database.outlined") {
            return .asset("database.outlined", isTemplate: false)
        }
        return .system("cylinder")
    }

    @ViewBuilder
    private func toolbarButtonLabel(icon: ToolbarIcon, title: String) -> some View {
        HStack(spacing: 8) {
            toolbarIconView(icon)
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func menuRow(icon: ToolbarIcon, title: String, isSelected: Bool = false) -> some View {
        HStack(spacing: 8) {
            toolbarIconView(icon)
            Text(title)
                .font(.system(size: 13, weight: .regular))
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
    }

    @ViewBuilder
    private func toolbarIconView(_ icon: ToolbarIcon) -> some View {
        icon.image
            .renderingMode(icon.isTemplate ? .template : .original)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 14, height: 14)
            .cornerRadius(icon.isTemplate ? 0 : 3)
    }

    private func hasImage(named name: String) -> Bool {
        #if canImport(AppKit)
        return NSImage(named: name) != nil
        #elseif canImport(UIKit)
        return UIImage(named: name) != nil
        #else
        return false
        #endif
    }
}

// MARK: - Refresh Button

struct RefreshToolbarButton: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var navigationState: NavigationState
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var refreshTask: Task<Void, Never>?

    var body: some View {
        if let session = appModel.sessionManager.activeSession ?? appModel.sessionManager.activeSessions.first {
            RefreshButtonContent(session: session,
                                 accent: themeManager.accentColor,
                                 onRefresh: { startRefresh(for: session) },
                                 onCancel: { cancelRefresh(for: session) })
        } else {
            RefreshButtonPlaceholder()
        }
    }

    private func startRefresh(for session: ConnectionSession) {
        refreshTask?.cancel()
        refreshTask = Task {
            await performRefresh(for: session)
            await MainActor.run {
                refreshTask = nil
            }
        }
    }

    @MainActor
    private func performRefresh(for session: ConnectionSession) async {
        guard !Task.isCancelled else {
            session.structureLoadingState = .idle
            session.structureLoadingMessage = nil
            return
        }

        let databaseOverride = navigationState.selectedDatabase?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let database = databaseOverride, !database.isEmpty {
            await appModel.refreshDatabaseStructure(
                for: session.id,
                scope: .selectedDatabase,
                databaseOverride: database
            )
        } else if let selected = session.selectedDatabaseName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !selected.isEmpty {
            await appModel.refreshDatabaseStructure(
                for: session.id,
                scope: .selectedDatabase,
                databaseOverride: selected
            )
        } else {
            await appModel.refreshDatabaseStructure(for: session.id, scope: .full)
        }
    }

    private func cancelRefresh(for session: ConnectionSession) {
        refreshTask?.cancel()
        refreshTask = nil
        session.structureLoadingState = .idle
        session.structureLoadingMessage = nil
    }
}

private struct RefreshButtonContent: View {
    @ObservedObject var session: ConnectionSession
    var accent: Color
    let onRefresh: () -> Void
    let onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var phase: Phase = .idle
    @State private var spinning = false
    @State private var isHovering = false
    @State private var completionTask: Task<Void, Never>?
    @State private var completionMessage: String = "Completed"
    @State private var hoverEnabled = true
    @State private var hoverEnableTask: Task<Void, Never>?
    @State private var hoverIntent = false

    private let circleSize: CGFloat = 32
    private let glowPadding: CGFloat = 12

    private enum Phase: Equatable {
        case idle
        case refreshing
        case completed
    }

    private var iconName: String {
        switch phase {
        case .completed: return "checkmark"
        default: return "arrow.clockwise"
        }
    }

    private var showCancel: Bool {
        phase == .refreshing && isHovering
    }

    private var spinnerSymbol: String {
        if showCancel {
            return "xmark"
        }
        return iconName
    }

    private var currentSymbol: String {
        shouldSpin ? "arrow.clockwise" : spinnerSymbol
    }

    private var shouldSpin: Bool {
        phase == .refreshing && !showCancel && spinning
    }

    private var iconColor: Color {
        if showCancel {
            return Color.primary.opacity(colorScheme == .dark ? 0.95 : 0.9)
        }
        switch phase {
        case .idle:
            return Color.secondary.opacity(colorScheme == .dark ? 0.85 : 0.65)
        case .refreshing:
            return Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.85)
        case .completed:
            return Color.white
        }
    }

    private var circleFill: Color {
        switch phase {
        case .idle:
            return idleFill
        case .refreshing:
            return Color.yellow.opacity(colorScheme == .dark ? 0.35 : 0.18)
        case .completed:
            return Color.green.opacity(colorScheme == .dark ? 0.45 : 0.22)
        }
    }

    private var idleFill: Color {
        toolbarIdleFill(for: colorScheme)
    }

    private var glowColor: Color {
        switch phase {
        case .refreshing:
            return Color.yellow
        case .completed:
            return Color.green
        case .idle:
            return .clear
        }
    }

    private var glowOpacity: Double {
        switch phase {
        case .refreshing: return isHovering ? 0.65 : 0.55
        case .completed: return 0.5
        case .idle: return 0
        }
    }

    private var helpText: String {
        switch phase {
        case .idle:
            return "Refresh"
        case .refreshing:
            return session.structureLoadingMessage ?? "Updating structure…"
        case .completed:
            return completionMessage
        }
    }

    var body: some View {
        Group {
            if phase == .idle {
                idleButton
            } else {
                animatedButton
            }
        }
        .animation(.easeInOut(duration: 0.24), value: phase)
    }

    private var idleButton: some View {
        Button {
            transition(to: .refreshing)
            onRefresh()
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.automatic)
        .help("Refresh")
    }

    private var animatedButton: some View {
        Button {
            if phase == .refreshing {
                cancelRefresh()
            } else {
                startHoverDelay()
                transition(to: .refreshing)
                onRefresh()
            }
        } label: {
            Label("Refresh", systemImage: "circle")
                .labelStyle(.iconOnly)
                .foregroundStyle(.clear)
                .overlay {
                    ZStack {
                        if glowOpacity > 0 {
                            GlowBorder(cornerRadius: circleSize / 2, color: glowColor)
                                .frame(width: circleSize + glowPadding, height: circleSize + glowPadding)
                                .opacity(glowOpacity)
                                .allowsHitTesting(false)
                        }

                        Circle()
                            .fill(circleFill)
                            .frame(width: circleSize, height: circleSize)

                        Image(systemName: currentSymbol)
                            .rotationEffect(shouldSpin ? .degrees(360) : .degrees(0))
                            .animation(
                                shouldSpin
                                    ? .linear(duration: 0.9).repeatForever(autoreverses: false)
                                    : .easeInOut(duration: 0.2),
                                value: shouldSpin
                            )
                            .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                                    removal: .opacity))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(iconColor)
                    }
                }
        }
        .buttonStyle(.automatic)
        .help(helpText)
        .accessibilityLabel(helpText)
#if os(macOS)
        .onHover { hovering in
            hoverIntent = hovering
            if hoverEnabled {
                isHovering = hovering
            } else if !hovering {
                isHovering = false
            }
        }
#endif
        .onAppear {
            synchronizePhase(with: session.structureLoadingState)
        }
        .onChange(of: session.structureLoadingState) { _, newValue in
            synchronizePhase(with: newValue)
        }
        .onDisappear {
            completionTask?.cancel()
            hoverEnableTask?.cancel()
        }
    }

    private func transition(to newPhase: Phase) {
        withAnimation(.easeInOut(duration: 0.24)) {
            phase = newPhase
        }
        spinning = (newPhase == .refreshing)
        handleHoverStateChange(for: newPhase)
        if newPhase != .refreshing {
            hoverIntent = false
        }
    }

    private func synchronizePhase(with state: StructureLoadingState) {
        switch state {
        case .loading:
            beginRefreshing()
        case .ready:
            showCompletion()
        case .failed:
            showCompletion(with: "Failed")
        case .idle:
            resetToIdle()
        }
    }

    private func beginRefreshing() {
        completionTask?.cancel()
        if hoverEnableTask == nil {
            startHoverDelay()
        }
        transition(to: .refreshing)
    }

    private func showCompletion(with message: String? = nil) {
        completionTask?.cancel()
        completionMessage = message ?? "Completed"
        stopHoverDelay(resetIntent: true)
        transition(to: .completed)
        completionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            resetToIdle()
        }
    }

    private func resetToIdle() {
        guard phase != .idle else { return }
        completionTask?.cancel()
        stopHoverDelay(resetIntent: true)
        transition(to: .idle)
    }

    private func cancelRefresh() {
        guard phase == .refreshing else { return }
        completionTask?.cancel()
        onCancel()
        stopHoverDelay(resetIntent: true)
        transition(to: .idle)
    }

    private func handleHoverStateChange(for newPhase: Phase) {
        switch newPhase {
        case .refreshing:
            if hoverEnableTask == nil {
                startHoverDelay()
            }
        case .completed, .idle:
            stopHoverDelay(resetIntent: true)
        }
    }

    private func startHoverDelay() {
        hoverEnableTask?.cancel()
        hoverEnabled = false
        isHovering = false
        hoverEnableTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            if phase == .refreshing {
                hoverEnabled = true
                if hoverIntent {
                    isHovering = true
                }
            }
        }
    }

    private func stopHoverDelay(resetIntent: Bool) {
        hoverEnableTask?.cancel()
        hoverEnableTask = nil
        hoverEnabled = true
        if resetIntent {
            hoverIntent = false
        }
        isHovering = false
    }
}

private struct RefreshButtonPlaceholder: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {}) {
            Label("Refresh", systemImage: "arrow.clockwise")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.automatic)
        .disabled(true)
        .help("Refresh (Unavailable)")
    }
}


private struct WorkspaceToolbarPreview: View {
    private let data: WorkspaceToolbarPreviewData

    init(mode: WorkspaceToolbarPreviewData.Mode) {
        self.data = WorkspaceToolbarPreviewData(mode: mode)
    }

    var body: some View {
        WorkspaceToolbarContainer()
        .environmentObject(data.appModel)
        .environmentObject(data.appState)
        .environmentObject(data.navigationState)
        .environmentObject(data.themeManager)
        .environment(\.colorScheme, .light)
    }
}

@MainActor
private struct WorkspaceToolbarPreviewData {
    enum Mode {
        case idle
        case refreshing
        case completed
    }

    let appModel: AppModel
    let appState: AppState
    let navigationState: NavigationState
    let themeManager: ThemeManager

    init(mode: Mode) {
        let previewCacheRoot = FileManager.default.temporaryDirectory.appendingPathComponent("EchoPreviewResultCache", isDirectory: true)
        let spoolManager = ResultSpoolManager(configuration: ResultSpoolConfiguration.defaultConfiguration(rootDirectory: previewCacheRoot))
        let appModel = AppModel(clipboardHistory: ClipboardHistoryStore(), resultSpoolManager: spoolManager)
        let appState = AppState()
        let navigationState = NavigationState()
        let themeManager = ThemeManager.shared
        themeManager.applyAppearanceMode(.light)

        let project = Project(name: "Preview Project", colorHex: "0A84FF", isDefault: true)
        appModel.projects = [project]
        appModel.selectedProject = project

        let connection = SavedConnection(
            connectionName: "Analytics",
            host: "db.preview.local",
            port: 5432,
            database: "analytics",
            username: "preview"
        )

        appModel.connections = [connection]
        appModel.selectedConnectionID = connection.id

        let previewSession = ConnectionSession(
            connection: connection,
            session: PreviewDatabaseSession(),
            defaultInitialBatchSize: appModel.globalSettings.resultsInitialRowLimit,
            defaultBackgroundStreamingThreshold: appModel.globalSettings.resultsBackgroundStreamingThreshold,
            spoolManager: spoolManager
        )
        previewSession.databaseStructure = DatabaseStructure(
            serverVersion: "16.2",
            databases: [
                DatabaseInfo(
                    name: "analytics",
                    schemas: [
                        SchemaInfo(
                            name: "public",
                            objects: [
                                SchemaObjectInfo(name: "customers", schema: "public", type: .table),
                                SchemaObjectInfo(name: "orders", schema: "public", type: .table)
                            ]
                        )
                    ]
                )
            ]
        )

        appModel.sessionManager.addSession(previewSession)
        navigationState.selectProject(project)
        navigationState.selectConnection(connection)
        navigationState.selectDatabase("analytics")
        appModel.navigationState = navigationState

        switch mode {
        case .idle:
            previewSession.structureLoadingState = .idle
            previewSession.structureLoadingMessage = nil
        case .refreshing:
            previewSession.structureLoadingState = .loading(progress: 0.45)
            previewSession.structureLoadingMessage = "Updating tables…"
        case .completed:
            previewSession.structureLoadingState = .ready
            previewSession.structureLoadingMessage = "Completed"
        }

        self.appModel = appModel
        self.appState = appState
        self.navigationState = navigationState
        self.themeManager = themeManager
    }
}

private struct WorkspaceToolbarContainer: View {
    var body: some View {
        NavigationStack {
            Color.clear
                .frame(height: 80)
        }
        .toolbar {
            WorkspaceToolbarItems()
        }
    }
}

private final class PreviewDatabaseSession: DatabaseSession, @unchecked Sendable {
    func close() async {}

    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        QueryResultSet(columns: [])
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        try await simpleQuery(sql)
    }

    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] {
        []
    }

    func listDatabases() async throws -> [String] {
        ["analytics"]
    }

    func listSchemas() async throws -> [String] {
        ["public"]
    }

    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet {
        try await simpleQuery(sql)
    }

    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] {
        []
    }

    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType) async throws -> String {
        "-- preview definition"
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        0
    }

    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {
        TableStructureDetails()
    }
}


private struct GlowBorder: View {
    var cornerRadius: CGFloat
    var color: Color

    @State private var gradientRotation: Angle = .degrees(0)

    private var animatedGradient: AngularGradient {
        let colors = [
            color,
            color.opacity(0.75),
            color.opacity(0.45),
            color.opacity(0.75),
            color
        ]
        return AngularGradient(gradient: Gradient(colors: colors), center: .center, angle: gradientRotation)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(animatedGradient, lineWidth: 4)
                .blur(radius: 7)
                .opacity(0.4)
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(animatedGradient, lineWidth: 10)
                .blur(radius: 16)
                .opacity(0.24)
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(animatedGradient, lineWidth: 18)
                .blur(radius: 26)
                .opacity(0.18)
        }
        .animation(.linear(duration: 3.0).repeatForever(autoreverses: false), value: gradientRotation)
        .onAppear {
            gradientRotation = .degrees(360)
        }
    }
}

#if DEBUG
struct WorkspaceToolbarItems_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            WorkspaceToolbarPreview(mode: .idle)
                .previewDisplayName("Idle")

            WorkspaceToolbarPreview(mode: .refreshing)
                .previewDisplayName("Refreshing")

            WorkspaceToolbarPreview(mode: .completed)
                .previewDisplayName("Completed")
        }
        .frame(width: 520)
        .padding(12)
        .background(previewBackground)
        .preferredColorScheme(.light)
    }

    private static var previewBackground: Color {
#if canImport(AppKit)
        Color(nsColor: NSColor.windowBackgroundColor)
#elseif canImport(UIKit)
        Color(uiColor: .systemBackground)
#else
        Color.gray.opacity(0.05)
#endif
    }
}
#endif

private struct ToolbarIcon {
    private enum Source {
        case system(name: String)
        case asset(name: String)
    }

    private let source: Source
    let isTemplate: Bool

    var image: Image {
        switch source {
        case .system(let name):
            return Image(systemName: name)
        case .asset(let name):
            return Image(name)
        }
    }

    static func system(_ name: String, isTemplate: Bool = true) -> ToolbarIcon {
        ToolbarIcon(source: .system(name: name), isTemplate: isTemplate)
    }

    static func asset(_ name: String, isTemplate: Bool) -> ToolbarIcon {
        ToolbarIcon(source: .asset(name: name), isTemplate: isTemplate)
    }
}

#if canImport(AppKit)
private extension ToolbarIcon {
    func makeNSImage(size: CGFloat = 16) -> NSImage? {
        let base: NSImage?
        switch source {
        case .system(let name):
            base = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        case .asset(let name):
            base = NSImage(named: name)
        }
        guard let base else { return nil }
        let image = base.copy() as? NSImage ?? base
        image.size = NSSize(width: size, height: size)
        image.isTemplate = isTemplate
        return image
    }
}
#endif

#if os(macOS)
private struct ToolbarGap: NSViewRepresentable {
    let width: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 10))
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: width),
            view.heightAnchor.constraint(equalToConstant: 10)
        ])
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
#else
private struct ToolbarGap: View {
    let width: CGFloat
    var body: some View { Spacer().frame(width: width) }
}
#endif

private struct ToolbarPrincipalSpacer: View {
    var body: some View {
        HStack { Spacer(minLength: 0) }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private extension StructureLoadingState {
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
