import SwiftUI

struct TopBarNavigator: View {
    let width: CGFloat

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var navigationState: NavigationState
    @Environment(\.colorScheme) private var colorScheme
    @State private var activePopover: DropdownType?
    @State private var hoveredSegment: DropdownType?
    @State private var connectionFolderStack: [SavedFolder] = []
    @State private var refreshState: RefreshState = .idle

    enum RefreshState: Equatable {
        case idle
        case updatingSchemas
        case updatingTables
        case updatingColumns
        case done
    }

    private enum SegmentIcon: Equatable {
        case system(String)
        case asset(String)
    }

    private let barHeight: CGFloat = 32
    private let segmentCornerRadius: CGFloat = 10

    var body: some View {
        navigatorBody(for: width)
    }
}

private extension TopBarNavigator {
    func navigatorBody(for width: CGFloat) -> some View {
        HStack(spacing: 18) {
            breadcrumbSegments
            Spacer(minLength: 16)
            statusIndicator
        }
        .padding(.horizontal, 18)
        .frame(width: width, height: barHeight)
        .background(barBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: barShadowColor, radius: barShadowRadius, y: barShadowYOffset)
    }
}

// MARK: - Breadcrumb

private extension TopBarNavigator {
    var breadcrumbSegments: some View {
        HStack(spacing: 0) {
            projectSegment
            connectionSegment
            databaseSegment
        }
    }

    var projectSegment: some View {
        segment(
            type: .project,
            title: navigationState.selectedProject?.name ?? "Select Project",
            icon: .system(navigationState.selectedProject?.iconName ?? "folder.badge.gearshape"),
            accent: navigationState.selectedProject?.color ?? Color.accentColor,
            isEnabled: true,
            showsPathArrow: true,
            showArrowOnlyWhenActive: false
        ) {
            connectionFolderStack.removeAll()
            togglePopover(.project)
        }
        .popover(isPresented: binding(for: .project), attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            ProjectPopover(
                projects: appModel.projects,
                selectedProjectID: navigationState.selectedProject?.id,
                onSelect: { project in
                    navigationState.selectProject(project)
                    appModel.selectedProject = project
                    activePopover = nil
                },
                onManage: {
                    activePopover = nil
                    appModel.showManageProjectsSheet = true
                }
            )
        }
    }

    var connectionSegment: some View {
        let display = connectionBreadcrumbDisplay

        return segment(
            type: .connection,
            title: display.title,
            icon: display.icon,
            accent: display.tint,
            isEnabled: navigationState.selectedProject != nil,
            showsPathArrow: true,
            showArrowOnlyWhenActive: false
        ) {
            guard navigationState.selectedProject != nil else { return }
            connectionFolderStack = currentFolderPath()
            togglePopover(.connection)
        }
        .popover(isPresented: binding(for: .connection), attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            ConnectionPopover(
                folders: appModel.folders,
                connections: appModel.connections,
                projectID: navigationState.selectedProject?.id,
                stack: $connectionFolderStack,
                onSelectFolder: { folder in
                    navigationState.selectFolder(folder)
                },
                onSelectConnection: { connection in
                    navigationState.selectConnection(connection)
                    activePopover = nil

                    // Clear database selection if connection has no default database
                    if connection.database.isEmpty {
                        navigationState.selectedDatabase = nil
                    }

                    Task {
                        await appModel.connect(to: connection)

                        // Auto-select database if specified in connection
                        if !connection.database.isEmpty {
                            navigationState.selectDatabase(connection.database)
                        }
                    }
                },
                onManage: {
                    activePopover = nil
                    appModel.showManageConnectionsTab = true
                }
            )
        }
    }

    var databaseSegment: some View {
        segment(
            type: .database,
            title: navigationState.selectedDatabase ?? "Database",
            icon: .system(navigationState.selectedDatabase == nil ? "cylinder" : "cylinder.fill"),
            accent: navigationState.selectedConnection?.color ?? Color.secondary,
            isEnabled: navigationState.selectedConnection != nil,
            showsPathArrow: true,
            showArrowOnlyWhenActive: true
        ) {
            guard navigationState.selectedConnection != nil else { return }
            if let connection = navigationState.selectedConnection,
               let session = appModel.sessionManager.sessionForConnection(connection.id),
               session.databaseStructure?.databases.isEmpty ?? true {
                Task { await appModel.refreshDatabaseStructure(for: session.id, scope: .full) }
            }
            togglePopover(.database)
        }
        .popover(isPresented: binding(for: .database), attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            DatabasePopover(
                session: navigationState.selectedConnection.flatMap { appModel.sessionManager.sessionForConnection($0.id) },
                selectedDatabase: navigationState.selectedDatabase,
                onSelect: { database, session in
                    navigationState.selectDatabase(database)
                    activePopover = nil
                    if let session {
                        Task { await appModel.loadSchemaForDatabase(database, connectionSession: session) }
                    }
                }
            )
        }
        .disabled(navigationState.selectedConnection == nil)
    }

    private func segment(
        type: DropdownType,
        title: String,
        icon: SegmentIcon,
        accent: Color,
        isEnabled: Bool,
        showsPathArrow: Bool,
        showArrowOnlyWhenActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let isActive = activePopover == type
        let isHovering = hoveredSegment == type
        let highlight = isActive || isHovering
        let shouldShowArrow = !showArrowOnlyWhenActive || highlight

        return Button {
            guard isEnabled else { return }
            action()
        } label: {
            HStack(spacing: 6) {
                iconView(for: icon)
                    .foregroundStyle(highlight ? accent : Color.secondary)

                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                if shouldShowArrow {
                    Image(systemName: showsPathArrow ? "chevron.right" : "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(highlight ? accent.opacity(0.9) : Color.secondary.opacity(0.7))
                        .rotationEffect(.degrees(showsPathArrow ? (highlight ? 90 : 0) : 0))
                        .frame(width: 10)
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, showsPathArrow ? 6 : 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: segmentCornerRadius, style: .continuous)
                    .fill(highlight ? activeSegmentFill : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .onHover { hovering in
            hoveredSegment = hovering ? type : (hoveredSegment == type ? nil : hoveredSegment)
        }
    }

    private func togglePopover(_ type: DropdownType) {
        if activePopover == type {
            activePopover = nil
        } else {
            activePopover = type
        }
    }

    private func binding(for type: DropdownType) -> Binding<Bool> {
        Binding(
            get: { activePopover == type },
            set: { newValue in
                if !newValue && activePopover == type {
                    activePopover = nil
                }
            }
        )
    }
}

private extension TopBarNavigator {
    @ViewBuilder
    private func iconView(for icon: SegmentIcon) -> some View {
        switch icon {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: 11, weight: .semibold))
        case .asset(let name):
            Image(name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
        }
    }
}

// MARK: - Refresh Animation

private extension TopBarNavigator {
    var refreshStateText: String {
        switch refreshState {
        case .idle, .done:
            return ""
        case .updatingSchemas:
            return "Updating schemas"
        case .updatingTables:
            return "Updating tables"
        case .updatingColumns:
            return "Updating columns"
        }
    }

    func animateRefresh(for database: String, session: ConnectionSession) async {
        withAnimation(.easeInOut(duration: 0.25)) {
            refreshState = .updatingSchemas
        }

        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s

        withAnimation(.easeInOut(duration: 0.25)) {
            refreshState = .updatingTables
        }

        // Actually perform the refresh
        await appModel.loadSchemaForDatabase(database, connectionSession: session)

        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s

        withAnimation(.easeInOut(duration: 0.25)) {
            refreshState = .updatingColumns
        }

        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s

        withAnimation(.easeInOut(duration: 0.25)) {
            refreshState = .done
        }

        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s

        withAnimation(.easeInOut(duration: 0.25)) {
            refreshState = .idle
        }
    }
}

// MARK: - Status Indicator

private extension TopBarNavigator {
    var statusIndicator: some View {
        let state = connectionStatus

        return HStack(spacing: 8) {
            if state.progressView {
                statusGraphic(for: state)

                Text(state.secondary.isEmpty ? state.primary : "\(state.primary) · \(state.secondary)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if let connection = navigationState.selectedConnection,
                      let session = appModel.sessionManager.sessionForConnection(connection.id),
                      let selectedDatabase = navigationState.selectedDatabase {
                if refreshState == .idle {
                    Button {
                        Task {
                            await animateRefresh(for: selectedDatabase, session: session)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh \(selectedDatabase) schema")
                    .transition(.scale.combined(with: .opacity))
                } else {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.mini)
                            .scaleEffect(0.7)
                            .frame(width: 10, height: 10)

                        Text(refreshStateText)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                    .fixedSize()
                    .transition(.opacity)
                }
            } else {
                Text("Idle")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    var connectionStatus: (primary: String, secondary: String, icon: String, tint: Color, progressView: Bool, progress: Double?) {
        guard let connection = navigationState.selectedConnection,
              let session = appModel.sessionManager.sessionForConnection(connection.id) else {
            return ("Idle", "", "circle", .secondary, false, nil)
        }

        switch session.structureLoadingState {
        case .loading(let progress):
            return ("Updating", "Fetching schemas", "", connection.color, true, progress)
        case .ready, .idle:
            return ("", "", "", connection.color, false, nil)
        case .failed(let message):
            return ("Failed", message ?? "Unable to load metadata", "exclamationmark.triangle.fill", .red, false, nil)
        }
    }

    func statusGraphic(for state: (primary: String, secondary: String, icon: String, tint: Color, progressView: Bool, progress: Double?)) -> some View {
        Group {
            if state.progressView {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
                        .frame(width: 14, height: 14)

                    if let progress = state.progress {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(state.tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: 14, height: 14)
                            .rotationEffect(.degrees(-90))
                    } else {
                        ProgressView()
                            .controlSize(.mini)
                            .scaleEffect(0.6)
                    }
                }
            } else {
                Image(systemName: state.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(state.tint)
            }
        }
    }
}

// MARK: - Helpers

private extension TopBarNavigator {
    private var barBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(barFillColor)
    }

    private var barFillColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.18, green: 0.19, blue: 0.21)
        } else {
            return Color.white.opacity(0.97)
        }
    }

    private var activeSegmentFill: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.16)
        } else {
            return Color(nsColor: .quaternaryLabelColor).opacity(0.22)
        }
    }

    private var barShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.12)
    }

    private var barShadowRadius: CGFloat {
        colorScheme == .dark ? 18 : 12
    }

    private var barShadowYOffset: CGFloat {
        colorScheme == .dark ? 8 : 6
    }

    private var connectionBreadcrumbDisplay: (icon: SegmentIcon, title: String, tint: Color) {
        if let folder = navigationState.selectedFolder {
            return (.system("folder.fill"), folder.name, folder.color)
        }

        if let connection = navigationState.selectedConnection {
            let title = connection.connectionName.isEmpty ? connection.host : connection.connectionName
            return (.asset(connection.databaseType.iconName), title, connection.color)
        }

        return (.system("server.rack"), "Server", Color.secondary.opacity(0.75))
    }

    private func currentFolderPath() -> [SavedFolder] {
        guard let folder = navigationState.selectedFolder else { return [] }
        var stack: [SavedFolder] = []
        var current: SavedFolder? = folder

        while let item = current {
            stack.insert(item, at: 0)
            current = item.parentFolderID.flatMap { id in appModel.folders.first(where: { $0.id == id }) }
        }

        return stack
    }
}

// MARK: - Popover Content

private struct ProjectPopover: View {
    let projects: [Project]
    let selectedProjectID: UUID?
    let onSelect: (Project) -> Void
    let onManage: () -> Void

    @State private var hoveredID: UUID?
    @State private var manageHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 4) {
                ForEach(projects) { project in
                    projectRow(for: project)
                }
            }

            Divider()

            Button(action: onManage) {
                HStack {
                    Text("Manage Projects…")
                        .font(.system(size: 11.5))
                        .foregroundStyle(manageHovered ? .white : .primary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(rowBackground(isSelected: false, isHovered: manageHovered))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .onHover { manageHovered = $0 }
        }
        .padding(12)
        .frame(minWidth: 240)
    }

    @ViewBuilder
    private func projectRow(for project: Project) -> some View {
        let isSelected = project.id == selectedProjectID
        let isHovered = hoveredID == project.id
        let isHighlighted = isSelected || isHovered

        Button(action: { onSelect(project) }) {
            HStack(spacing: 8) {
                switch project.iconRenderInfo {
                case let (image, true):
                    image
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isHighlighted ? .white : project.color)
                case let (image, false):
                    image
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                }
                Text(project.name)
                    .font(.system(size: 11.5))
                    .foregroundStyle(isHighlighted ? .white : .primary)
                    .lineLimit(1)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(rowBackground(isSelected: isSelected, isHovered: isHovered))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredID = hovering ? project.id : (hoveredID == project.id ? nil : hoveredID)
        }
    }

    private func rowBackground(isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected { return Color.accentColor }
        if isHovered { return Color.accentColor.opacity(0.85) }
        return Color.clear
    }
}

private struct ConnectionPopover: View {
    let folders: [SavedFolder]
    let connections: [SavedConnection]
    let projectID: UUID?
    @Binding var stack: [SavedFolder]
    let onSelectFolder: (SavedFolder) -> Void
    let onSelectConnection: (SavedConnection) -> Void
    let onManage: () -> Void

    @State private var hoveredFolderID: UUID?
    @State private var hoveredConnectionID: UUID?
    @State private var manageHovered = false

    private var currentFolder: SavedFolder? { stack.last }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let currentFolder {
                folderHeader(for: currentFolder)
            }

            VStack(alignment: .leading, spacing: 10) {
                if !currentFolders.isEmpty {
                    sectionHeader("Folders")
                    VStack(spacing: 4) {
                        ForEach(currentFolders) { folder in
                            Button {
                                stack.append(folder)
                                onSelectFolder(folder)
                            } label: {
                                let isHighlighted = hoveredFolderID == folder.id
                                HStack(spacing: 8) {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundStyle(isHighlighted ? .white : folder.color)
                                    Text(folder.name)
                                        .font(.system(size: 11))
                                        .foregroundStyle(isHighlighted ? .white : .primary)
                                        .lineLimit(1)
                                    Spacer()
                                    Circle()
                                        .fill(isHighlighted ? .white : folder.color)
                                        .frame(width: 6, height: 6)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(isHighlighted ? .white : .secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(popoverRowBackground(isHovered: hoveredFolderID == folder.id))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                hoveredFolderID = hovering ? folder.id : (hoveredFolderID == folder.id ? nil : hoveredFolderID)
                            }
                        }
                    }
                }

                if !currentConnections.isEmpty {
                    sectionHeader("Connections")
                    VStack(spacing: 4) {
                        ForEach(currentConnections) { connection in
                            Button { onSelectConnection(connection) } label: {
                                let isHighlighted = hoveredConnectionID == connection.id
                                HStack(spacing: 8) {
                                    Image(connection.databaseType.iconName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 11.5, height: 11.5)
                                        .foregroundStyle(isHighlighted ? .white : connection.color)
                                    Text(connection.connectionName.isEmpty ? connection.host : connection.connectionName)
                                        .font(.system(size: 11))
                                        .foregroundStyle(isHighlighted ? .white : .primary)
                                        .lineLimit(1)
                                    Spacer()
                                    Circle()
                                        .fill(isHighlighted ? .white : connection.color)
                                        .frame(width: 6, height: 6)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(popoverRowBackground(isHovered: hoveredConnectionID == connection.id))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                hoveredConnectionID = hovering ? connection.id : (hoveredConnectionID == connection.id ? nil : hoveredConnectionID)
                            }
                        }
                    }
                }
            }

            Divider()

            Button(action: onManage) {
                HStack {
                    Text("Manage Connections…")
                        .font(.system(size: 11.5))
                        .foregroundStyle(manageHovered ? .white : .primary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(popoverRowBackground(isHovered: manageHovered))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .onHover { manageHovered = $0 }
        }
        .padding(12)
        .frame(minWidth: 260)
    }

    private func folderHeader(for folder: SavedFolder) -> some View {
        HStack(spacing: 8) {
            Button {
                _ = stack.popLast()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                Text("Back")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(folder.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 4)
    }

    private func popoverRowBackground(isHovered: Bool) -> Color {
        isHovered ? Color.accentColor.opacity(0.85) : Color.clear
    }

    private var currentFolders: [SavedFolder] {
        let parentID = currentFolder?.id
        return folders.filter { folder in
            guard folder.kind == .connections else { return false }
            guard folder.parentFolderID == parentID else { return false }
            if let projectID { return folder.projectID == projectID }
            return projectID == nil
        }
    }

    private var currentConnections: [SavedConnection] {
        let folderID = currentFolder?.id
        return connections.filter { connection in
            guard connection.folderID == folderID else { return false }
            if let projectID { return connection.projectID == projectID }
            return projectID == nil
        }
    }
}

private struct DatabasePopover: View {
    let session: ConnectionSession?
    let selectedDatabase: String?
    let onSelect: (String, ConnectionSession?) -> Void

    @State private var hoveredDatabase: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let session, case .loading = session.structureLoadingState {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading databases…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
            } else if let databases = session?.databaseStructure?.databases, !databases.isEmpty {
                VStack(spacing: 4) {
                    ForEach(databases, id: \.name) { database in
                        Button { onSelect(database.name, session) } label: {
                            let isHighlighted = database.name == selectedDatabase || hoveredDatabase == database.name
                            HStack {
                                Text(database.name)
                                    .font(.system(size: 11))
                                    .foregroundStyle(isHighlighted ? .white : .primary)
                                    .lineLimit(1)
                                Spacer()
                                if database.name == selectedDatabase {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(popoverRowBackground(isSelected: database.name == selectedDatabase, isHovered: hoveredDatabase == database.name))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            hoveredDatabase = hovering ? database.name : (hoveredDatabase == database.name ? nil : hoveredDatabase)
                        }
                    }
                }
            } else {
                Text("No databases available")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            }
        }
        .padding(12)
        .frame(minWidth: 240)
    }

    private func popoverRowBackground(isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected { return Color.accentColor }
        if isHovered { return Color.accentColor.opacity(0.85) }
        return Color.clear
    }
}

private enum DropdownType: Hashable {
    case project
    case connection
    case database
}
