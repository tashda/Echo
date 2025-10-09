import SwiftUI

/// SwiftUI toolbar content for the workspace window. Replaces the legacy AppKit toolbar overlay.
struct WorkspaceToolbarItems: ToolbarContent {
    var body: some ToolbarContent {
        // Left-aligned controls
        ToolbarItem(placement: .navigation) {
            ProjectToolbarMenu()
        }

        ToolbarItemGroup(placement: .navigation) {
            ConnectionToolbarMenu()
            DatabaseToolbarMenu()
        }

        // Right-aligned actions
        ToolbarItemGroup(placement: .primaryAction) {
            RefreshToolbarButton()
            NewTabToolbarButton()
            TabOverviewToolbarButton()
        }

        ToolbarItem(placement: .primaryAction) {
            InspectorToggleToolbarButton()
        }
    }
}

// MARK: - Shared UI Helpers

private struct ToolbarIconDescriptor {
    let image: Image
    let isTemplate: Bool

    static func system(_ name: String) -> ToolbarIconDescriptor {
        ToolbarIconDescriptor(image: Image(systemName: name), isTemplate: true)
    }

    static func asset(_ name: String, template: Bool = true) -> ToolbarIconDescriptor {
        ToolbarIconDescriptor(image: Image(name), isTemplate: template)
    }
}

private struct ToolbarPillLabel: View {
    @Environment(\.colorScheme) private var colorScheme

    let icon: ToolbarIconDescriptor
    let title: String
    let accentColor: Color?
    let isDisabled: Bool

    var body: some View {
        HStack(spacing: 8) {
            icon.image
                .renderingMode(icon.isTemplate ? .template : .original)
                .foregroundStyle(iconForeground)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 16, height: 16, alignment: .center)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(textForeground)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(backgroundFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .opacity(isDisabled ? 0.5 : 1.0)
    }

    private var backgroundFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.96)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.08)
    }

    private var iconForeground: Color {
        if let accentColor {
            return accentColor
        }
        return colorScheme == .dark ? Color.white.opacity(0.85) : Color.black.opacity(0.7)
    }

    private var textForeground: Color {
        colorScheme == .dark ? Color.white.opacity(0.9) : Color.black.opacity(0.85)
    }
}

private struct MenuRowLabel: View {
    let title: String
    let icon: ToolbarIconDescriptor?
    let isSelected: Bool

    var body: some View {
        HStack {
            if let icon {
                icon.image
                    .renderingMode(icon.isTemplate ? .template : .original)
                    .frame(width: 14, height: 14, alignment: .center)
            }

            Text(title)
                .lineLimit(1)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
            }
        }
    }
}

// MARK: - Project Menu

private struct ProjectToolbarMenu: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var navigationState: NavigationState

    var body: some View {
        Menu {
            if appModel.projects.isEmpty {
                Text("No Projects").foregroundStyle(.secondary)
            } else {
                ForEach(appModel.projects) { project in
                    Button {
                        select(project)
                    } label: {
                        MenuRowLabel(
                            title: project.name,
                            icon: projectIcon(for: project),
                            isSelected: navigationState.selectedProject?.id == project.id
                        )
                    }
                }
            }

            Divider()

            Button("Manage Projects…") {
                appModel.showManageProjectsSheet = true
            }
        } label: {
            ToolbarPillLabel(
                icon: currentProjectIcon,
                title: navigationState.selectedProject?.name ?? "Project",
                accentColor: navigationState.selectedProject?.color,
                isDisabled: appModel.projects.isEmpty
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(appModel.projects.isEmpty)
    }

    private var currentProjectIcon: ToolbarIconDescriptor {
        if let project = navigationState.selectedProject {
            let renderInfo = project.iconRenderInfo
            return ToolbarIconDescriptor(image: renderInfo.image, isTemplate: renderInfo.isSystemSymbol)
        }
        return .system("folder.badge.person.crop")
    }

    private func projectIcon(for project: Project) -> ToolbarIconDescriptor {
        let info = project.iconRenderInfo
        return ToolbarIconDescriptor(image: info.image, isTemplate: info.isSystemSymbol)
    }

    private func select(_ project: Project) {
        navigationState.selectProject(project)
        appModel.selectedProject = project
    }
}

// MARK: - Connection Menu

private struct ConnectionToolbarMenu: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var navigationState: NavigationState

    var body: some View {
        Menu {
            connectionMenuContent(parentFolderID: nil)

            if canShowManageButton {
                Divider()
                Button("Manage Connections…") {
                    appModel.isManageConnectionsPresented = true
                }
            }
        } label: {
            ToolbarPillLabel(
                icon: currentIcon,
                title: connectionTitle,
                accentColor: currentAccent,
                isDisabled: !hasConnections
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(!hasConnections)
    }

    private var selectedProjectID: UUID? {
        navigationState.selectedProject?.id ?? appModel.selectedProject?.id
    }

    private var hasConnections: Bool {
        !filteredConnections(parentFolderID: nil).isEmpty || !filteredFolders(parentFolderID: nil).isEmpty
    }

    private var canShowManageButton: Bool {
        true
    }

    private var currentIcon: ToolbarIconDescriptor {
        if let folder = navigationState.selectedFolder {
            return .system("folder.fill")
        }

        if let connection = navigationState.selectedConnection {
            return .asset(connection.databaseType.iconName)
        }

        return .system("server.rack")
    }

    private var currentAccent: Color? {
        if let folder = navigationState.selectedFolder {
            return folder.color
        }
        if let connection = navigationState.selectedConnection {
            return connection.color
        }
        return nil
    }

    private var connectionTitle: String {
        if let folder = navigationState.selectedFolder {
            return folder.name
        }

        if let connection = navigationState.selectedConnection {
            let trimmed = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? connection.host : trimmed
        }

        return "Connection"
    }

    @ViewBuilder
    private func connectionMenuContent(parentFolderID: UUID?) -> some View {
        let folders = filteredFolders(parentFolderID: parentFolderID)
        let connections = filteredConnections(parentFolderID: parentFolderID)

        if folders.isEmpty, connections.isEmpty, parentFolderID == nil {
            Text("No Connections")
                .foregroundStyle(.secondary)
        } else {
            ForEach(folders) { folder in
                Menu {
                    Button {
                        select(folder)
                    } label: {
                        MenuRowLabel(
                            title: "Open “\(folder.name)”",
                            icon: .system("folder"),
                            isSelected: navigationState.selectedFolder?.id == folder.id
                        )
                    }

                    let childConnections = filteredConnections(parentFolderID: folder.id)
                    if !childConnections.isEmpty {
                        Divider()
                        ForEach(childConnections) { connection in
                            connectionButton(for: connection)
                        }
                    }

                    let childFolders = filteredFolders(parentFolderID: folder.id)
                    if !childFolders.isEmpty {
                        Divider()
                        connectionMenuContent(parentFolderID: folder.id)
                    }
                } label: {
                    MenuRowLabel(
                        title: folder.name,
                        icon: .system("folder"),
                        isSelected: navigationState.selectedFolder?.id == folder.id
                    )
                }
            }

            ForEach(connections) { connection in
                connectionButton(for: connection)
            }
        }
    }

    private func connectionButton(for connection: SavedConnection) -> some View {
        Button {
            select(connection)
        } label: {
            MenuRowLabel(
                title: connectionDisplayName(connection),
                icon: .asset(connection.databaseType.iconName),
                isSelected: navigationState.selectedConnection?.id == connection.id
            )
        }
    }

    private func select(_ folder: SavedFolder) {
        navigationState.selectFolder(folder)
        appModel.selectedFolderID = folder.id
    }

    private func select(_ connection: SavedConnection) {
        navigationState.selectConnection(connection)
        appModel.selectedConnectionID = connection.id
        appModel.selectedFolderID = connection.folderID

        Task {
            await appModel.connect(to: connection)
        }
    }

    private func connectionDisplayName(_ connection: SavedConnection) -> String {
        let trimmed = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return connection.host
        }
        return trimmed
    }

    private func filteredFolders(parentFolderID: UUID?) -> [SavedFolder] {
        appModel.folders.filter { folder in
            guard folder.kind == .connections else { return false }
            guard folder.parentFolderID == parentFolderID else { return false }
            if let projectID = selectedProjectID {
                return folder.projectID == nil || folder.projectID == projectID
            }
            return true
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func filteredConnections(parentFolderID: UUID?) -> [SavedConnection] {
        appModel.connections.filter { connection in
            if connection.folderID != parentFolderID { return false }
            if let projectID = selectedProjectID {
                return connection.projectID == nil || connection.projectID == projectID
            }
            return true
        }
        .sorted { connectionDisplayName($0) < connectionDisplayName($1) }
    }
}

// MARK: - Database Menu

private struct DatabaseToolbarMenu: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var navigationState: NavigationState

    var body: some View {
        Menu {
            if let session = activeSession {
                databaseMenuContent(session: session)
            } else {
                Text("No Databases")
                    .foregroundStyle(.secondary)
            }
        } label: {
            ToolbarPillLabel(
                icon: currentIcon,
                title: currentTitle,
                accentColor: currentAccent,
                isDisabled: activeSession == nil
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(activeSession == nil)
    }

    private var activeSession: ConnectionSession? {
        guard let connection = navigationState.selectedConnection else { return nil }
        return appModel.sessionManager.sessionForConnection(connection.id)
    }

    private var currentIcon: ToolbarIconDescriptor {
        if navigationState.selectedDatabase != nil {
            return .asset("database.check.outlined")
        }
        return .system("cylinder")
    }

    private var currentAccent: Color? {
        if let connection = navigationState.selectedConnection {
            return connection.color
        }
        return nil
    }

    private var currentTitle: String {
        if let database = navigationState.selectedDatabase {
            return database
        }
        return "Database"
    }

    @ViewBuilder
    private func databaseMenuContent(session: ConnectionSession) -> some View {
        switch session.structureLoadingState {
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading databases…")
            }
        case .failed(let message):
            Text(message ?? "Unable to load databases")
                .foregroundStyle(.secondary)
        default:
            let databases = session.databaseStructure?.databases ?? []
            if databases.isEmpty {
                Button("Refresh Databases") {
                    Task {
                        await appModel.refreshDatabaseStructure(for: session.id, scope: .full)
                    }
                }
            } else {
                ForEach(databases, id: \.name) { database in
                    Button {
                        select(database.name, session: session)
                    } label: {
                        MenuRowLabel(
                            title: database.name,
                            icon: .system("cylinder"),
                            isSelected: navigationState.selectedDatabase == database.name
                        )
                    }
                }
            }
        }
    }

    private func select(_ database: String, session: ConnectionSession) {
        navigationState.selectDatabase(database)

        Task {
            await appModel.loadSchemaForDatabase(database, connectionSession: session)
        }
    }
}

// MARK: - Refresh Button

private struct RefreshToolbarButton: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var navigationState: NavigationState

    @State private var refreshState: RefreshState = .idle
    @State private var isRotating = false

    var body: some View {
        Group {
            switch refreshState {
            case .idle:
                Button(action: startRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                }
                .help("Refresh server and database metadata")
                .buttonStyle(.borderless)
                .disabled(!canRefresh)

            case .updatingSchemas, .updatingTables, .updatingColumns:
                statusLabel(text: refreshState.label)

            case .done:
                statusLabel(text: "Updated")
                    .onAppear {
                        Task {
                            try? await Task.sleep(nanoseconds: 600_000_000)
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                                refreshState = .idle
                                isRotating = false
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: refreshState)
    }

    private func statusLabel(text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.clockwise")
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .animation(
                    isRotating
                        ? .linear(duration: 0.9).repeatForever(autoreverses: false)
                        : .default,
                    value: isRotating
                )
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.08))
        )
    }

    private var canRefresh: Bool {
        guard let connection = navigationState.selectedConnection else { return false }
        return appModel.sessionManager.sessionForConnection(connection.id) != nil
    }

    private func startRefresh() {
        guard canRefresh,
              let connection = navigationState.selectedConnection,
              let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            refreshState = .updatingSchemas
            isRotating = true
        }

        Task {
            let database = navigationState.selectedDatabase
            await appModel.refreshDatabaseStructure(
                for: session.id,
                scope: database == nil ? .full : .selectedDatabase,
                databaseOverride: database
            )

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    refreshState = .updatingTables
                }
            }

            try? await Task.sleep(nanoseconds: 300_000_000)

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    refreshState = .updatingColumns
                }
            }

            if let database {
                await appModel.loadSchemaForDatabase(database, connectionSession: session)
            }

            try? await Task.sleep(nanoseconds: 250_000_000)

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    refreshState = .done
                }
            }
        }
    }

    private enum RefreshState {
        case idle
        case updatingSchemas
        case updatingTables
        case updatingColumns
        case done

        var label: String {
            switch self {
            case .idle: return ""
            case .updatingSchemas: return "Updating schemas"
            case .updatingTables: return "Updating tables"
            case .updatingColumns: return "Updating columns"
            case .done: return "Updated"
            }
        }
    }
}

// MARK: - New Tab

private struct NewTabToolbarButton: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Button {
            appModel.openQueryTab()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
        }
        .buttonStyle(.borderless)
        .disabled(!appModel.canOpenQueryTab)
        .help("Open a new query tab")
    }
}

// MARK: - Tab Overview

private struct TabOverviewToolbarButton: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.showTabOverview.toggle()
            }
        } label: {
            Image(systemName: "rectangle.grid.2x2")
                .font(.system(size: 14, weight: .semibold))
        }
        .buttonStyle(.borderless)
        .disabled(appModel.tabManager.tabs.isEmpty)
        .help("Toggle tab overview")
    }
}

// MARK: - Inspector Toggle

private struct InspectorToggleToolbarButton: View {
    @Environment(\.toggleInspector) private var toggleInspector
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Button {
            toggleInspector()
            appState.showInfoSidebar.toggle()
        } label: {
            Image(systemName: "sidebar.right")
                .font(.system(size: 14, weight: .semibold))
        }
        .buttonStyle(.borderless)
        .help(appState.showInfoSidebar ? "Hide Inspector" : "Show Inspector")
    }
}
