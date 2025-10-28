import SwiftUI
import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

@MainActor
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
    @EnvironmentObject private var themeManager: ThemeManager

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
        ToolbarItem(id: "workspace.navigation.project", placement: .navigation) {
            projectMenu
        }

        // Split trailing actions into stable, individual toolbar items.
        // This avoids occasional reflow where the entire HStack migrates left
        // during sidebar collapse/expand animations.
        ToolbarItem(id: "workspace.primary.refresh", placement: .primaryAction) {
            RefreshToolbarButton()
                .labelStyle(.iconOnly)
        }

        ToolbarItem(id: "workspace.primary.newtab", placement: .primaryAction) {
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

        ToolbarItem(id: "workspace.primary.taboverview", placement: .primaryAction) {
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

        ToolbarItem(id: "workspace.primary.toggleinspector", placement: .primaryAction) {
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
            trailingActions
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

    private var trailingActions: some View {
        HStack(spacing: 12) {
            RefreshToolbarButton()
                .labelStyle(.iconOnly)

            Button {
                appModel.openQueryTab()
            } label: {
                Label("New Tab", systemImage: "plus")
            }
            .help("Open a new query tab")
            .disabled(!canOpenNewTab)
            .labelStyle(.iconOnly)
            .accessibilityLabel("New Tab")

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
        .padding(.horizontal, 2)
        .fixedSize()
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
        let diagramCacheRoot = FileManager.default.temporaryDirectory.appendingPathComponent("EchoPreviewDiagramCache", isDirectory: true)
        let diagramManager = DiagramCacheManager(configuration: DiagramCacheManager.Configuration(rootDirectory: diagramCacheRoot))
        let diagramKeyStore = DiagramEncryptionKeyStore()
        Task {
            await diagramManager.updateKeyProvider { projectID in
                try await MainActor.run {
                    try diagramKeyStore.symmetricKey(forProjectID: projectID)
                }
            }
        }
        let appModel = AppModel(
            clipboardHistory: ClipboardHistoryStore(),
            resultSpoolManager: spoolManager,
            diagramCacheManager: diagramManager,
            diagramKeyStore: diagramKeyStore
        )
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
            previewSession.structureLoadingState = StructureLoadingState.idle
            previewSession.structureLoadingMessage = nil
        case .refreshing:
            previewSession.structureLoadingState = StructureLoadingState.loading(progress: 0.45)
            previewSession.structureLoadingMessage = "Updating tables…"
        case .completed:
            previewSession.structureLoadingState = StructureLoadingState.ready
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
struct WorkspaceToolbarTabBar: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var dragState = ToolbarTabDragState()

    private let tabReorderAnimation = Animation.interactiveSpring(response: 0.72, dampingFraction: 0.86, blendDuration: 0.30)

    private let tabSpacing: CGFloat = 6
    private let chipHeight: CGFloat = WorkspaceChromeMetrics.toolbarTabBarHeight
    private let comfortableMinTabWidth: CGFloat = 112
    private let absoluteMinTabWidth: CGFloat = 68
    private let maxTabWidth: CGFloat = 320
    private let pinnedComfortableMinWidth: CGFloat = 60
    private let pinnedAbsoluteMinWidth: CGFloat = 48
    private let pinnedMaxWidth: CGFloat = 120
    private let overflowButtonWidth: CGFloat = 28
    private let overflowSpacing: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let layout = toolbarLayout(for: max(proxy.size.width, 1))

            HStack(spacing: overflowSpacing) {
                tabScroller(availableWidth: layout.scrollerWidth, tabs: layout.visibleTabs)
                    .frame(width: layout.scrollerWidth, height: chipHeight, alignment: .leading)

                if layout.shouldShowOverflow {
                    overflowControl
                        .frame(width: overflowButtonWidth, height: chipHeight)
                }
            }
            .frame(width: layout.fullWidth, height: chipHeight, alignment: .leading)
        }
        .frame(height: chipHeight)
    }

    private func tabScroller(availableWidth: CGFloat, tabs: [WorkspaceTab]) -> AnyView {
        guard !tabs.isEmpty else { return AnyView(EmptyView()) }

        let visibleRange = visibleIndexRange(for: tabs)
        let tabWidths = resolvedTabWidths(for: tabs, availableWidth: availableWidth)

        let scroller = ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: tabSpacing) {
                    ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                        let totalCount = appModel.tabManager.tabs.count
                        let actualIndex = appModel.tabManager.index(of: tab.id) ?? index
                        let hasLeft = actualIndex > 0
                        let hasRight = actualIndex < totalCount - 1
                        let width = tabWidths[tab.id] ?? comfortableMinTabWidth

                        ToolbarWorkspaceTabChip(
                            tab: tab,
                            isActive: appModel.tabManager.activeTabId == tab.id,
                            height: chipHeight,
                            onSelect: { appModel.tabManager.activeTabId = tab.id },
                            onClose: { appModel.tabManager.closeTab(id: tab.id) },
                            onAddBookmark: tab.query == nil ? nil : { bookmark(tab: tab) },
                            onPinToggle: { appModel.tabManager.togglePin(for: tab.id) },
                            onDuplicate: { appModel.duplicateTab(tab) },
                            onCloseOthers: { appModel.tabManager.closeOtherTabs(keeping: tab.id) },
                            onCloseLeft: { appModel.tabManager.closeTabsLeft(of: tab.id) },
                            onCloseRight: { appModel.tabManager.closeTabsRight(of: tab.id) },
                            canDuplicate: tab.kind == .query,
                            closeOthersDisabled: totalCount <= 1,
                            closeTabsLeftDisabled: !hasLeft,
                            closeTabsRightDisabled: !hasRight
                        )
                        .frame(width: width, height: chipHeight)
                        .offset(x: tabOffset(for: tab))
                        .zIndex(dragZIndex(for: tab))
                        .opacity(dragState.id == tab.id ? 0.96 : 1)
                        .highPriorityGesture(
                            dragGesture(
                                for: tab,
                                width: width,
                                actualIndex: actualIndex,
                                totalCount: totalCount,
                                visibleRange: visibleRange
                            )
                        )
                        .id(tab.id)
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 2)
            }
#if os(macOS)
            .modifier(ToolbarTabBarScrollStyle())
#endif
            .frame(height: chipHeight + 2)
            .contentShape(Rectangle())
            .onChange(of: appModel.tabManager.activeTabId) { _, newValue in
                guard let target = newValue else { return }
                withAnimation(.easeInOut(duration: 0.22)) {
                    proxy.scrollTo(target, anchor: .center)
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: tabs.map(\.id))
        .frame(height: chipHeight + 4)

        return AnyView(scroller)
    }

    private var orderedTabs: [WorkspaceTab] {
        let tabs = appModel.tabManager.tabs
        let pinned = tabs.filter { $0.isPinned }
        let regular = tabs.filter { !$0.isPinned }
        return pinned + regular
    }

    private struct ToolbarLayout {
        let fullWidth: CGFloat
        let scrollerWidth: CGFloat
        let visibleTabs: [WorkspaceTab]
        let shouldShowOverflow: Bool
    }

    private func toolbarLayout(for fullWidth: CGFloat) -> ToolbarLayout {
        let tabs = orderedTabs
        guard !tabs.isEmpty else {
            return ToolbarLayout(
                fullWidth: fullWidth,
                scrollerWidth: max(fullWidth, comfortableMinTabWidth),
                visibleTabs: [],
                shouldShowOverflow: false
            )
        }

        let totalCount = tabs.count

        func capacity(for width: CGFloat) -> Int {
            guard width > 0 else { return 1 }
            let spacing = tabSpacing
            let comfortableSlots = Int(floor((width + spacing) / (comfortableMinTabWidth + spacing)))
            let absoluteSlots = Int(floor((width + spacing) / (absoluteMinTabWidth + spacing)))
            let candidate = max(comfortableSlots, absoluteSlots)
            return max(1, candidate)
        }

        var reserved: CGFloat = 0
        var scrollerWidth = max(fullWidth - reserved, comfortableMinTabWidth)

        func adjustedCapacity(for width: CGFloat) -> Int {
            let base = capacity(for: width)
            guard totalCount > base - 1 else { return base }
            return max(base - 1, 1)
        }

        var slotLimit = adjustedCapacity(for: scrollerWidth)
        var visible = selectVisibleTabs(from: tabs, capacity: slotLimit)
        var showOverflow = totalCount > slotLimit
        if !showOverflow, scrollerWidth < fullWidth - 40 {
            showOverflow = totalCount >= slotLimit
        }

        if showOverflow {
            reserved = overflowButtonWidth + overflowSpacing
            scrollerWidth = max(fullWidth - reserved, comfortableMinTabWidth)
            slotLimit = adjustedCapacity(for: scrollerWidth)
            if slotLimit >= totalCount {
                slotLimit = max(totalCount - 1, 1)
            }
            visible = selectVisibleTabs(from: tabs, capacity: slotLimit)
            showOverflow = visible.count < totalCount
        }

        return ToolbarLayout(
            fullWidth: fullWidth,
            scrollerWidth: max(scrollerWidth, comfortableMinTabWidth),
            visibleTabs: visible,
            shouldShowOverflow: showOverflow
        )
    }

    private func selectVisibleTabs(from tabs: [WorkspaceTab], capacity: Int) -> [WorkspaceTab] {
        guard capacity < tabs.count else { return tabs }
        var selection = Array(tabs.prefix(capacity))
        if let activeID = appModel.tabManager.activeTabId,
           let activeIndex = tabs.firstIndex(where: { $0.id == activeID }),
           !selection.contains(where: { $0.id == activeID }) {
            selection.removeLast()
            selection.append(tabs[activeIndex])
        }
        return selection
    }

    private func resolvedTabWidths(for tabs: [WorkspaceTab], availableWidth: CGFloat) -> [UUID: CGFloat] {
        guard !tabs.isEmpty else { return [:] }

        let spacingTotal = tabSpacing * CGFloat(max(tabs.count - 1, 0))
        let widthPool = max(availableWidth - spacingTotal, 0)
        let base = widthPool / CGFloat(max(tabs.count, 1))

        var widths: [UUID: CGFloat] = [:]
        let pinnedTabs = tabs.filter { $0.isPinned }
        let regularTabs = tabs.filter { !$0.isPinned }

        var pinnedSum: CGFloat = 0
        for tab in pinnedTabs {
            var width = base
            if base >= pinnedComfortableMinWidth {
                width = max(pinnedComfortableMinWidth, width)
            } else {
                width = max(pinnedAbsoluteMinWidth, width)
            }
            width = min(pinnedMaxWidth, width)
            widths[tab.id] = width
            pinnedSum += width
        }

        let pinnedCount = CGFloat(pinnedTabs.count)
        let regularCount = CGFloat(regularTabs.count)
        var regularWidth = base
        if regularCount > 0 {
            let adjustment = (base * pinnedCount - pinnedSum) / regularCount
            regularWidth = base + adjustment
        }

        regularWidth = max(absoluteMinTabWidth, regularWidth)

        var consumedAdjustment: CGFloat = 0
        for tab in regularTabs {
            var width = regularWidth
            width = min(maxTabWidth, max(absoluteMinTabWidth, width))
            widths[tab.id] = width
            consumedAdjustment += width
        }

        let currentSum = pinnedSum + consumedAdjustment
        let diff = widthPool - currentSum

        if abs(diff) > 0.5 {
            if regularCount > 0 {
                let deltaPerTab = diff / regularCount
                for tab in regularTabs {
                    guard var width = widths[tab.id] else { continue }
                    width = min(maxTabWidth, max(absoluteMinTabWidth, width + deltaPerTab))
                    widths[tab.id] = width
                }
            } else if pinnedCount > 0 {
                let deltaPerTab = diff / pinnedCount
                for tab in pinnedTabs {
                    guard var width = widths[tab.id] else { continue }
                    width = min(pinnedMaxWidth, max(pinnedAbsoluteMinWidth, width + deltaPerTab))
                    widths[tab.id] = width
                }
            }
        }

        return widths
    }

    private func tabOffset(for tab: WorkspaceTab) -> CGFloat {
        guard dragState.isActive, let draggingId = dragState.id else { return 0 }
        if draggingId == tab.id {
            return dragState.translation
        }
        guard dragState.draggingWidth > 0,
              let tabIndex = appModel.tabManager.index(of: tab.id) else { return 0 }

        if dragState.currentIndex > dragState.originalIndex {
            if tabIndex > dragState.originalIndex && tabIndex <= dragState.currentIndex {
                return -dragState.draggingWidth
            }
        } else if dragState.currentIndex < dragState.originalIndex {
            if tabIndex >= dragState.currentIndex && tabIndex < dragState.originalIndex {
                return dragState.draggingWidth
            }
        }

        return 0
    }

    private func dragZIndex(for tab: WorkspaceTab) -> Double {
        dragState.id == tab.id ? 1 : 0
    }

    private func dragGesture(
        for tab: WorkspaceTab,
        width: CGFloat,
        actualIndex: Int,
        totalCount: Int,
        visibleRange: ClosedRange<Int>
    ) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .onChanged { value in
                guard width > 0 else { return }

                if !dragState.isActive {
                    let bounds = tabBounds(for: tab, totalCount: totalCount)
                    let limitedMin = min(max(bounds.min, visibleRange.lowerBound), visibleRange.upperBound)
                    let limitedMax = max(min(bounds.max, visibleRange.upperBound), visibleRange.lowerBound)
                    dragState.begin(
                        id: tab.id,
                        originalIndex: actualIndex,
                        minIndex: limitedMin,
                        maxIndex: limitedMax,
                        width: width
                    )
                }

                guard dragState.id == tab.id else { return }

                let rawTranslation = value.translation.width
                let clampedTranslation = clampTranslation(
                    rawTranslation,
                    state: dragState,
                    tabWidth: width
                )

                let moveThreshold = width * 0.5
                var proposedIndex = dragState.originalIndex
                var remainder = clampedTranslation

                while remainder > moveThreshold && proposedIndex < dragState.maxIndex {
                    remainder -= width
                    proposedIndex += 1
                }

                while remainder < -moveThreshold && proposedIndex > dragState.minIndex {
                    remainder += width
                    proposedIndex -= 1
                }

                if proposedIndex != dragState.currentIndex {
                    withAnimation(tabReorderAnimation) {
                        dragState.currentIndex = proposedIndex
                    }
                }

                dragState.translation = clampedTranslation
            }
            .onEnded { _ in
                guard dragState.isActive, dragState.id == tab.id else { return }
                let finalIndex = dragState.currentIndex
                let shouldMove = finalIndex != dragState.originalIndex

                if shouldMove {
                    withAnimation(tabReorderAnimation) {
                        appModel.tabManager.moveTab(id: tab.id, to: finalIndex)
                    }
                }

                withAnimation(tabReorderAnimation) {
                    dragState.reset()
                }
            }
    }

    private func clampTranslation(
        _ translation: CGFloat,
        state: ToolbarTabDragState,
        tabWidth: CGFloat
    ) -> CGFloat {
        let maxRight = CGFloat(state.maxIndex - state.originalIndex) * tabWidth
        let maxLeft = CGFloat(state.originalIndex - state.minIndex) * tabWidth
        return min(max(translation, -maxLeft), maxRight)
    }

    private func tabBounds(for tab: WorkspaceTab, totalCount: Int) -> (min: Int, max: Int) {
        let pinnedCount = appModel.tabManager.tabs.filter { $0.isPinned }.count
        if tab.isPinned {
            return (0, max(pinnedCount - 1, 0))
        } else {
            return (pinnedCount, max(totalCount - 1, pinnedCount))
        }
    }

    private func visibleIndexRange(for tabs: [WorkspaceTab]) -> ClosedRange<Int> {
        let indices = tabs.compactMap { appModel.tabManager.index(of: $0.id) }
        guard let minIndex = indices.min(), let maxIndex = indices.max() else { return 0...0 }
        return minIndex...maxIndex
    }

#if os(macOS)
    private struct ToolbarTabBarScrollStyle: ViewModifier {
        func body(content: Content) -> some View {
            if #available(macOS 13.0, *) {
                content
                    .scrollContentBackground(.hidden)
                    .background(ToolbarScrollViewBackgroundClearer())
            } else {
                content
                    .background(ToolbarScrollViewBackgroundClearer())
            }
        }
    }

    private struct ToolbarScrollViewBackgroundClearer: NSViewRepresentable {
        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.wantsLayer = false
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {
            DispatchQueue.main.async {
                guard let scrollView = nsView.enclosingScrollView else { return }
                scrollView.drawsBackground = false
                scrollView.backgroundColor = .clear
                scrollView.hasVerticalScroller = false
                scrollView.scrollerStyle = .overlay
                scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            }
        }
    }
#endif


    private struct ToolbarTabDragState {
        var id: UUID?
        var originalIndex: Int = 0
        var currentIndex: Int = 0
        var translation: CGFloat = 0
        var minIndex: Int = 0
        var maxIndex: Int = 0
        var draggingWidth: CGFloat = 0

        var isActive: Bool { id != nil }

        mutating func begin(
            id: UUID,
            originalIndex: Int,
            minIndex: Int,
            maxIndex: Int,
            width: CGFloat
        ) {
            self.id = id
            self.originalIndex = originalIndex
            self.currentIndex = originalIndex
            self.translation = 0
            let lower = Swift.min(minIndex, maxIndex)
            let upper = Swift.max(minIndex, maxIndex)
            self.minIndex = Swift.min(lower, originalIndex)
            self.maxIndex = Swift.max(upper, originalIndex)
            self.draggingWidth = max(width, 1)
        }

        mutating func reset() {
            self = ToolbarTabDragState()
        }
    }

    private var overflowControl: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                appState.showTabOverview.toggle()
            }
        } label: {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(overflowBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(overflowBorder, lineWidth: 0.75)
                )
                .overlay(
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(overflowForeground)
                )
        }
        .buttonStyle(.plain)
        .frame(width: 26, height: 26)
        .accessibilityLabel("Open Tab Overview")
        .help("Open Tab Overview")
    }

    private var overflowBackground: Color {
#if os(macOS)
        let base = NSColor.controlBackgroundColor
        if colorScheme == .dark {
            return Color(nsColor: base.blended(withFraction: 0.35, of: NSColor.windowBackgroundColor) ?? base)
        }
        return Color(nsColor: base)
#else
        return Color(.systemGray5)
#endif
    }

    private var overflowBorder: Color {
#if os(macOS)
        let color = NSColor.separatorColor.withAlphaComponent(colorScheme == .dark ? 0.45 : 0.28)
        return Color(nsColor: color)
#else
        return Color(.separator)
#endif
    }

    private var overflowForeground: Color {
#if os(macOS)
        return colorScheme == .dark ? Color(nsColor: .labelColor) : Color(nsColor: .secondaryLabelColor)
#else
        return Color(.label)
#endif
    }

    private var overflowShadow: Color {
        Color.black.opacity(colorScheme == .dark ? 0.45 : 0.08)
    }

    private func bookmark(tab: WorkspaceTab) {
        guard let queryState = tab.query else { return }
        let trimmed = queryState.sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let database = queryState.clipboardMetadata.databaseName ?? tab.connection.database
        Task {
            await appModel.addBookmark(
                for: tab.connection,
                databaseName: database,
                title: tab.title,
                query: trimmed,
                source: .tab
            )
        }
    }
}

struct ToolbarWorkspaceTabChip: View {
    @ObservedObject var tab: WorkspaceTab
    let isActive: Bool
    let height: CGFloat
    let onSelect: () -> Void
    let onClose: () -> Void
    let onAddBookmark: (() -> Void)?
    let onPinToggle: () -> Void
    let onDuplicate: () -> Void
    let onCloseOthers: () -> Void
    let onCloseLeft: () -> Void
    let onCloseRight: () -> Void
    let canDuplicate: Bool
    let closeOthersDisabled: Bool
    let closeTabsLeftDisabled: Bool
    let closeTabsRightDisabled: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    private var capsule: Capsule { Capsule(style: .continuous) }

    var body: some View {
        HStack(spacing: 8) {
            Text(displayTitle)
                .font(.system(size: 12, weight: .regular))
                .lineLimit(1)
                .foregroundStyle(titleColor)

            Spacer(minLength: 4)

            if showCloseButton {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(closeIconColor)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(closeButtonOpacity)
                .accessibilityLabel("Close Tab")
            }
        }
        .padding(.horizontal, horizontalPadding)
        .frame(height: height)
        .background(glassBackground)
        .overlay(glassBorder)
        .overlay(glassHighlight)
        .contentShape(capsule)
        .shadow(color: tabShadowColor, radius: glassShadowRadius, y: glassShadowYOffset)
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button(tab.isPinned ? "Unpin Tab" : "Pin Tab", action: onPinToggle)

            Button("Duplicate Tab", action: onDuplicate)
                .disabled(!canDuplicate)

            Divider()

            Button("Close Tab", action: onClose)

            Button("Close Other Tabs", action: onCloseOthers)
                .disabled(closeOthersDisabled)

            Button("Close Tabs to the Left", action: onCloseLeft)
                .disabled(closeTabsLeftDisabled)

            Button("Close Tabs to the Right", action: onCloseRight)
                .disabled(closeTabsRightDisabled)

            if let onAddBookmark {
                Divider()
                Button("Add to Bookmarks", action: onAddBookmark)
            }
        }
#if os(macOS)
        .onHover { hovering in
            isHovering = hovering
        }
        .onMiddleClick(perform: onClose)
#endif
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var showCloseButton: Bool {
        !tab.isPinned
    }

    private var displayTitle: String {
        let trimmed = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if tab.isPinned {
            if let first = trimmed.first {
                return String(first).uppercased()
            }
            return "•"
        }
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    private var glassBackground: some View {
        capsule.fill(glassGradient)
    }

    private var glassBorder: some View {
        capsule.stroke(glassBorderColor, lineWidth: 1)
    }

    private var glassHighlight: some View {
        capsule
            .stroke(
                Color.white.opacity(
                    colorScheme == .dark
                    ? (isActive ? 0.40 : 0.22)
                    : (isActive ? 0.55 : 0.28)
                ),
                lineWidth: 0.7
            )
            .blendMode(.screen)
            .opacity(0.85)
            .offset(y: -0.5)
    }

    private var glassGradient: LinearGradient {
        if isActive {
            if colorScheme == .dark {
                return LinearGradient(
                    colors: [
                        Color.white.opacity(0.36),
                        Color.white.opacity(0.24),
                        Color.white.opacity(0.16)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                return LinearGradient(
                    colors: [
                        Color.white.opacity(0.97),
                        Color.white.opacity(0.90),
                        Color.white.opacity(0.82)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }

        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.18),
                    Color.white.opacity(0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [
                Color.white.opacity(0.72),
                Color.white.opacity(0.56)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var glassBorderColor: Color {
        if colorScheme == .dark {
            return isActive ? Color.white.opacity(0.45) : Color.white.opacity(0.26)
        }
        return isActive ? Color.black.opacity(0.12) : Color.black.opacity(0.08)
    }

    private var titleColor: Color {
        if isActive {
            return colorScheme == .dark ? Color.white.opacity(0.95) : Color.black.opacity(0.85)
        }
        if tab.isPinned {
            return colorScheme == .dark ? Color.white.opacity(0.82) : Color.black.opacity(0.65)
        }
        return colorScheme == .dark ? Color.white.opacity(0.78) : Color.black.opacity(0.55)
    }

    private var closeIconColor: Color {
        if isActive {
            return colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.6)
        }
        return colorScheme == .dark ? Color.white.opacity(0.72) : Color.black.opacity(0.45)
    }

    private var closeButtonOpacity: Double {
#if os(macOS)
        (isActive || isHovering) ? 1 : 0
#else
        1
#endif
    }

    private var horizontalPadding: CGFloat {
        tab.isPinned ? 12 : 16
    }

    private var tabShadowColor: Color {
        if isActive {
            return Color.black.opacity(colorScheme == .dark ? 0.55 : 0.15)
        }
        return Color.black.opacity(colorScheme == .dark ? 0.45 : 0.06)
    }

    private var glassShadowRadius: CGFloat { isActive ? 5 : 2 }
    private var glassShadowYOffset: CGFloat { isActive ? 2.5 : 1 }
}
#endif

private extension StructureLoadingState {
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
