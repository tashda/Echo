//
//  AppModel.swift
//  Echo
//
//  Created by Kenneth Berg on 15/09/2025.
//

import Foundation
import SwiftUI
import Combine

struct RecentConnectionRecord: Codable, Identifiable, Equatable {
    let connectionID: UUID
    var databaseName: String?
    var lastConnectedAt: Date

    var id: String {
        let databaseComponent = databaseName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return "\(connectionID.uuidString)|\(databaseComponent)"
    }
}

@MainActor
final class AppModel: ObservableObject {

    private static let recentConnectionsKey = "recentConnections"

    enum StructureRefreshScope {
        case selectedDatabase
        case full
    }

    // MARK: - Published State
    @Published var connections: [SavedConnection] = []
    @Published var selectedConnectionID: UUID?
    @Published var folders: [SavedFolder] = []
    @Published var identities: [SavedIdentity] = []
    @Published var selectedFolderID: UUID?
    @Published var selectedIdentityID: UUID?
    @Published var connectionStates: [UUID: ConnectionState] = [:]
    @Published var sessionManager = ConnectionSessionManager()
    @Published var tabManager = TabManager()
    @Published var pinnedObjectIDs: [String] = []
    @Published var useServerColorAsAccent: Bool = UserDefaults.standard.bool(forKey: "useServerColorAsAccent")
    @Published private(set) var recentConnections: [RecentConnectionRecord] = []
    @Published var pendingExplorerFocus: ExplorerFocus?
    @Published var searchSidebarCaches: [SearchSidebarContextKey: SearchSidebarCache] = [:]

    // Project management
    @Published var projects: [Project] = []
    @Published var selectedProject: Project?
    @Published var globalSettings: GlobalSettings = GlobalSettings()
    @Published var navigationState = NavigationState()
    @Published var isManageConnectionsPresented = false
    @Published var showNewProjectSheet = false
    @Published var showManageProjectsSheet = false
    @Published var lastError: DatabaseError?

    // MARK: - Dependencies
    private let store = ConnectionStore()
    private let folderStore = FolderStore()
    private let identityStore = IdentityStore()
    private let projectStore = ProjectStore()
    private let keychain = KeychainHelper()
    private let clipboardHistory: ClipboardHistoryStore
    private var cancellables: Set<AnyCancellable> = []
    private var sessionDatabaseCancellables: [UUID: AnyCancellable] = [:]

    private func makeDatabaseFactory(for type: DatabaseType) -> DatabaseFactory? {
        DatabaseFactoryProvider.makeFactory(for: type)
    }

    private func makeStructureFetcher(for connection: SavedConnection) -> DatabaseStructureFetcher? {
        guard let factory = makeDatabaseFactory(for: connection.databaseType) else { return nil }
        return DatabaseStructureFetcher(factory: factory, databaseType: connection.databaseType)
    }

    // MARK: - Computed helpers
    var selectedConnection: SavedConnection? {
        guard let id = selectedConnectionID else { return nil }
        return connections.first { $0.id == id }
    }

    // MARK: - Initialization
    init(clipboardHistory: ClipboardHistoryStore) {
        self.clipboardHistory = clipboardHistory
        sessionManager.$activeSessionID
            .sink { [weak self] id in
                guard let self else { return }
                if let id,
                   let session = self.sessionManager.activeSessions.first(where: { $0.id == id }) {
                    self.selectedConnectionID = session.connection.id
                    self.updateNavigation(for: session)
                } else {
                    self.updateNavigation(for: nil)
                }
            }
            .store(in: &cancellables)

        sessionManager.$activeSessions
            .sink { [weak self] sessions in
                guard let self else { return }
                let validIDs = sessions.map { $0.id }
                self.pruneSessionCancellables(validIDs: validIDs)

                for session in sessions where self.sessionDatabaseCancellables[session.id] == nil {
                    self.observeSession(session)
                }

                if let activeID = self.sessionManager.activeSessionID,
                   let activeSession = sessions.first(where: { $0.id == activeID }) {
                    self.updateNavigation(for: activeSession)
                } else if self.sessionManager.activeSessionID == nil {
                    self.updateNavigation(for: nil)
                }
            }
            .store(in: &cancellables)

        $selectedConnectionID
            .removeDuplicates()
            .sink { [weak self] id in
                self?.applySelectedConnection(id)
            }
            .store(in: &cancellables)

        $useServerColorAsAccent
            .sink { useServerColor in
                UserDefaults.standard.set(useServerColor, forKey: "useServerColorAsAccent")
            }
            .store(in: &cancellables)

        tabManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        loadRecentConnections()
    }

    // MARK: - Persistence
    func load() async {
        do {
            async let connectionsTask = store.load()
            async let foldersTask = folderStore.load()
            async let identitiesTask = identityStore.load()
            async let projectsTask = projectStore.load()
            async let globalSettingsTask = projectStore.loadGlobalSettings()

            let (loadedConnections, loadedFolders, loadedIdentities, loadedProjects, loadedGlobalSettings) = try await (
                connectionsTask,
                foldersTask,
                identitiesTask,
                projectsTask,
                globalSettingsTask
            )

            connections = loadedConnections
            folders = loadedFolders
            identities = loadedIdentities
            projects = loadedProjects
            globalSettings = loadedGlobalSettings

            await normalizeEditorPreferences()

            await ensureDefaultProjectExists()

            // Migrate existing data to default project if needed
            await migrateToProjects()

            if let project = selectedProject,
               navigationState.selectedProject?.id != project.id {
                navigationState.selectProject(project)
            }

            if selectedFolderID == nil {
                selectedFolderID = folders.first(where: { $0.kind == .connections })?.id
            }
            if selectedIdentityID == nil {
                selectedIdentityID = identities.first?.id
            }

            synchronizeRecentConnectionsWithConnections()
        } catch {
            print("Failed to load data: \(error)")
        }
    }

    func ensureDefaultProjectExists(assignNavigation: Bool = true) async {
        var didCreateDefault = false

        if projects.isEmpty {
            let defaultProject = Project.defaultProject
            projects = [defaultProject]
            do {
                try await projectStore.save(projects)
            } catch {
                print("Failed to save default project: \(error)")
            }
            didCreateDefault = true
        }

        if selectedProject == nil || didCreateDefault {
            selectedProject = projects.first(where: { $0.isDefault }) ?? projects.first
        }

        if assignNavigation {
            if navigationState.selectedProject == nil || didCreateDefault,
               let project = selectedProject {
                navigationState.selectProject(project)
            }
        }
    }

    private func normalizeEditorPreferences() async {
        var didMutateProjects = false
        var didMutateGlobalSettings = false

        let legacyPalette = globalSettings.palette(withID: globalSettings.defaultEditorTheme)

        if globalSettings.defaultPaletteID(for: .light).isEmpty
            || globalSettings.palette(withID: globalSettings.defaultPaletteID(for: .light)) == nil {
            if let legacyPalette, legacyPalette.tone == .light {
                globalSettings.defaultEditorPaletteIDLight = legacyPalette.id
            } else if let fallbackLight = SQLEditorTokenPalette.builtIn.first(where: { $0.tone == .light }) {
                globalSettings.defaultEditorPaletteIDLight = fallbackLight.id
            } else {
                globalSettings.defaultEditorPaletteIDLight = SQLEditorPalette.aurora.id
            }
            didMutateGlobalSettings = true
        }

        if globalSettings.defaultPaletteID(for: .dark).isEmpty
            || globalSettings.palette(withID: globalSettings.defaultPaletteID(for: .dark)) == nil {
            if let legacyPalette, legacyPalette.tone == .dark {
                globalSettings.defaultEditorPaletteIDDark = legacyPalette.id
            } else if let fallbackDark = SQLEditorTokenPalette.builtIn.first(where: { $0.tone == .dark }) {
                globalSettings.defaultEditorPaletteIDDark = fallbackDark.id
            } else {
                globalSettings.defaultEditorPaletteIDDark = SQLEditorPalette.midnight.id
            }
            didMutateGlobalSettings = true
        }

        if globalSettings.editorHighlightDelay < 0 {
            globalSettings.editorHighlightDelay = 0.25
            didMutateGlobalSettings = true
        }
        if globalSettings.editorIndentWrappedLines < 0 {
            globalSettings.editorIndentWrappedLines = 4
            didMutateGlobalSettings = true
        }
        if globalSettings.defaultEditorLineHeight < 1.0 {
            globalSettings.defaultEditorLineHeight = 1.0
            didMutateGlobalSettings = true
        }

        for index in projects.indices {
            var settings = projects[index].settings
            if settings.editorPaletteID == nil,
               let legacy = settings.editorTheme,
               globalSettings.palette(withID: legacy) != nil || settings.customEditorPalette?.id == legacy {
                settings.editorPaletteID = legacy
                projects[index].settings = settings
                didMutateProjects = true
            }

            if let delay = settings.highlightDelay, delay < 0 {
                settings.highlightDelay = nil
                didMutateProjects = true
            }
            if let indent = settings.indentWrappedLines, indent < 0 {
                settings.indentWrappedLines = nil
                didMutateProjects = true
            }
            if let lineHeight = settings.editorLineHeight, lineHeight < 1.0 {
                settings.editorLineHeight = nil
                didMutateProjects = true
            }
            projects[index].settings = settings
        }

        if didMutateProjects {
            do {
                try await projectStore.save(projects)
            } catch {
                print("Failed to persist normalized project settings: \(error)")
            }
        }

        if didMutateGlobalSettings {
            await persistGlobalSettings()
        }
    }

    private func persistGlobalSettings() async {
        do {
            try await projectStore.saveGlobalSettings(globalSettings)
        } catch {
            print("Failed to persist global settings: \(error)")
        }
    }

    // MARK: - Editor Appearance

    func setDefaultEditorPalette(to paletteID: String, for tone: SQLEditorPalette.Tone) async {
        globalSettings.setDefaultPaletteID(paletteID, for: tone)
        await persistGlobalSettings()
    }

    func updateGlobalEditorDisplay(_ update: (inout GlobalSettings) -> Void) async {
        update(&globalSettings)
        await persistGlobalSettings()
    }

    func upsertCustomPalette(_ palette: SQLEditorTokenPalette) async {
        if let index = globalSettings.customEditorPalettes.firstIndex(where: { $0.id == palette.id }) {
            globalSettings.customEditorPalettes[index] = palette
        } else {
            globalSettings.customEditorPalettes.append(palette)
        }
        await persistGlobalSettings()
    }

    func deleteCustomPalette(withID id: String) async {
        let originalCount = globalSettings.customEditorPalettes.count
        globalSettings.customEditorPalettes.removeAll { $0.id == id }
        let removed = globalSettings.customEditorPalettes.count != originalCount
        if globalSettings.defaultEditorPaletteIDLight == id {
            globalSettings.defaultEditorPaletteIDLight = SQLEditorPalette.aurora.id
        }
        if globalSettings.defaultEditorPaletteIDDark == id {
            globalSettings.defaultEditorPaletteIDDark = SQLEditorPalette.midnight.id
        }

        var didMutateProjects = false
        for index in projects.indices {
            if projects[index].settings.editorPaletteID == id {
                projects[index].settings.editorPaletteID = nil
                didMutateProjects = true
            }
            if let custom = projects[index].settings.customEditorPalette, custom.id == id {
                projects[index].settings.customEditorPalette = nil
                didMutateProjects = true
            }
        }

        await persistGlobalSettings()

        if removed || didMutateProjects {
            do {
                try await projectStore.save(projects)
            } catch {
                print("Failed to persist project updates after palette removal: \(error)")
            }

            if let selected = selectedProject,
               let updated = projects.first(where: { $0.id == selected.id }) {
                selectedProject = updated
            }
        }
    }

    func upsertCustomTheme(_ theme: AppColorTheme) async {
        if let index = globalSettings.customThemes.firstIndex(where: { $0.id == theme.id }) {
            globalSettings.customThemes[index] = theme
        } else {
            globalSettings.customThemes.append(theme)
        }
        await persistGlobalSettings()
        await ensureActiveThemesApplied()
    }

    func deleteCustomTheme(withID id: AppColorTheme.ID) async {
        globalSettings.customThemes.removeAll { $0.id == id }
        if globalSettings.activeThemeIDLight == id {
            globalSettings.activeThemeIDLight = nil
        }
        if globalSettings.activeThemeIDDark == id {
            globalSettings.activeThemeIDDark = nil
        }
        await persistGlobalSettings()
        await ensureActiveThemesApplied()
    }

    func setActiveTheme(_ themeID: AppColorTheme.ID?, for tone: SQLEditorPalette.Tone) async {
        globalSettings.setActiveThemeID(themeID, for: tone)
        await persistGlobalSettings()
        applyChrome(for: tone)
    }

    private func ensureActiveThemesApplied() async {
        applyChrome(for: .light)
        applyChrome(for: .dark)
    }

    private func applyChrome(for tone: SQLEditorPalette.Tone) {
#if canImport(AppKit)
        _ = activeTheme(for: tone)
#endif
    }

    private func activeTheme(for tone: SQLEditorPalette.Tone) -> AppColorTheme {
        if let theme = globalSettings.theme(withID: globalSettings.activeThemeID(for: tone), tone: tone) {
            return theme
        }
        if let projectThemeID = selectedProject?.settings.editorTheme,
           let projectTheme = globalSettings.theme(withID: projectThemeID, tone: tone) {
            return projectTheme
        }
        return AppColorTheme.builtInThemes(for: tone).first
            ?? AppColorTheme.fromPalette(tone == .dark ? SQLEditorPalette.midnight : SQLEditorPalette.aurora)
    }

    func updateProjectAppearance(projectID: UUID, update: (inout ProjectSettings) -> Void) async {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        update(&projects[index].settings)
        projects[index].updatedAt = Date()
        let updatedProject = projects[index]

        do {
            try await projectStore.save(projects)
        } catch {
            print("Failed to persist project appearance: \(error)")
        }

        if selectedProject?.id == projectID {
            selectedProject = updatedProject
        }
    }

    func upsertConnection(_ connection: SavedConnection, password: String?) async {
        var updated = connection
        let existing = connections.first(where: { $0.id == updated.id })

        switch updated.credentialSource {
        case .manual:
            if let password, !password.isEmpty {
                if updated.keychainIdentifier == nil {
                    updated.keychainIdentifier = "echo.\(updated.id.uuidString)"
                }
                if let identifier = updated.keychainIdentifier {
                    do {
                        try keychain.setPassword(password, account: identifier)
                    } catch {
                        print("Keychain set failed: \(error)")
                    }
                }
            } else if updated.keychainIdentifier == nil, let existingIdentifier = existing?.keychainIdentifier {
                updated.keychainIdentifier = existingIdentifier
            }

            updated.identityID = nil

        case .identity:
            updated.keychainIdentifier = nil
            if let identifier = existing?.keychainIdentifier, existing?.credentialSource == .manual {
                try? keychain.deletePassword(account: identifier)
            }

            if let identityID = updated.identityID,
               let identity = identities.first(where: { $0.id == identityID }) {
                updated.username = identity.username
            } else {
                updated.identityID = nil
            }

        case .inherit:
            updated.identityID = nil
            updated.keychainIdentifier = nil
            if let identifier = existing?.keychainIdentifier, existing?.credentialSource == .manual {
                try? keychain.deletePassword(account: identifier)
            }
        }

        if let index = connections.firstIndex(where: { $0.id == updated.id }) {
            if updated.cachedStructure == nil {
                updated.cachedStructure = connections[index].cachedStructure
                updated.cachedStructureUpdatedAt = connections[index].cachedStructureUpdatedAt
            }
            connections[index] = updated
        } else {
            connections.append(updated)
        }

        await persistConnections()

        Task {
            await preloadStructure(for: updated, overridePassword: password)
        }
    }

    func deleteConnection(id: UUID) async {
        guard let connection = connections.first(where: { $0.id == id }) else { return }
        await deleteConnection(connection)
    }

    // MARK: - Query Tabs

    var canOpenQueryTab: Bool {
        sessionManager.activeSession != nil || !sessionManager.activeSessions.isEmpty
    }

    func openQueryTab(for session: ConnectionSession? = nil,
                      presetQuery: String = "",
                      bookmarkContext: WorkspaceTab.BookmarkTabContext? = nil) {
        guard let targetSession = session
                ?? sessionManager.activeSession
                ?? sessionManager.activeSessions.first else { return }

        sessionManager.setActiveSession(targetSession.id)
        let connection = targetSession.connection
        let title: String
        if let context = bookmarkContext {
            let existingTabs = tabManager.tabs.filter { $0.bookmarkContext?.bookmarkID == context.bookmarkID }
            let baseTitle = context.displayName
            if !existingTabs.contains(where: { $0.title == baseTitle }) {
                title = baseTitle
            } else {
                var suffix = 2
                var candidate = "\(baseTitle) #\(suffix)"
                while existingTabs.contains(where: { $0.title == candidate }) {
                    suffix += 1
                    candidate = "\(baseTitle) #\(suffix)"
                }
                title = candidate
            }
        } else {
            let existingCountForConnection = tabManager.tabs.filter {
                $0.connection.id == connection.id && $0.bookmarkContext == nil
            }.count

            let baseTitle: String
            if connection.connectionName.isEmpty {
                baseTitle = connection.database.isEmpty ? "Query" : connection.database
            } else {
                baseTitle = connection.connectionName
            }

            title = "\(baseTitle) \(existingCountForConnection + 1)"
        }

        let queryState = QueryEditorState(sql: presetQuery.isEmpty ? "SELECT current_timestamp;" : presetQuery)

        func normalized(_ value: String) -> String? {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        let serverName = normalized(connection.connectionName) ?? normalized(connection.host)
        let databaseName = normalized(targetSession.selectedDatabaseName ?? connection.database)

        queryState.updateClipboardContext(
            serverName: serverName,
            databaseName: databaseName,
            connectionColorHex: connection.metadataColorHex
        )

        let newTab = WorkspaceTab(
            connection: connection,
            session: targetSession.session,
            connectionSessionID: targetSession.id,
            title: title,
            content: .query(queryState),
            bookmarkContext: bookmarkContext
        )
        tabManager.addTab(newTab)
    }

    func closeActiveQueryTab() {
        guard let activeTab = tabManager.activeTab else { return }
        tabManager.closeTab(id: activeTab.id)
    }

    func duplicateTab(_ tab: WorkspaceTab) {
        guard let queryState = tab.query else { return }
        guard let session = sessionManager.activeSessions.first(where: { $0.id == tab.connectionSessionID }) else { return }

        sessionManager.setActiveSession(session.id)

        let duplicateState = QueryEditorState(sql: queryState.sql)
        duplicateState.splitRatio = queryState.splitRatio
        duplicateState.updateClipboardContext(
            serverName: queryState.clipboardMetadata.serverName,
            databaseName: queryState.clipboardMetadata.databaseName,
            connectionColorHex: queryState.clipboardMetadata.connectionColorHex
        )
        duplicateState.updateClipboardObjectName(queryState.clipboardMetadata.objectName)

        let duplicateTab = WorkspaceTab(
            connection: tab.connection,
            session: session.session,
            connectionSessionID: session.id,
            title: tab.title,
            content: .query(duplicateState),
            isPinned: tab.isPinned,
            bookmarkContext: tab.bookmarkContext
        )

        if let index = tabManager.index(of: tab.id) {
            tabManager.insertTab(duplicateTab, at: index + 1)
        } else {
            tabManager.addTab(duplicateTab)
        }
    }

    func openStructureTab(for session: ConnectionSession, object: SchemaObjectInfo, focus: TableStructureSection? = nil) {
        Task {
            do {
                let details = try await session.session.getTableStructureDetails(schema: object.schema, table: object.name)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    sessionManager.setActiveSession(session.id)
                    selectedConnectionID = session.connection.id

                    let baseTitle = "\(object.name) Structure"
                    let editor = TableStructureEditorViewModel(
                        schemaName: object.schema,
                        tableName: object.name,
                        details: details,
                        session: session.session
                    )
                    if let focus {
                        editor.focusSection(focus)
                    }
                    let newTab = WorkspaceTab(
                        connection: session.connection,
                        session: session.session,
                        connectionSessionID: session.id,
                        title: baseTitle,
                        content: .structure(editor)
                    )
                    tabManager.addTab(newTab)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.lastError = DatabaseError.from(error)
                }
            }
        }
    }

    func deleteConnection(_ connection: SavedConnection) async {
        if let identifier = connection.keychainIdentifier {
            try? keychain.deletePassword(account: identifier)
        }

        connections.removeAll { $0.id == connection.id }
        connectionStates.removeValue(forKey: connection.id)

        if let session = sessionManager.sessionForConnection(connection.id) {
            await session.session.close()
            sessionManager.removeSession(withID: session.id)
        }

        if selectedConnectionID == connection.id {
            selectedConnectionID = connections.first?.id
        }

        await removeBookmarks(forConnectionID: connection.id, projectID: connection.projectID)

        removeRecentConnections(for: connection.id)

        await persistConnections()
    }

    private func persistConnections() async {
        do {
            try await store.save(connections)
        } catch {
            print("Failed to persist connections: \(error)")
        }
    }

    private func persistFolders() async {
        do {
            try await folderStore.save(folders)
        } catch {
            print("Failed to persist folders: \(error)")
        }
    }

    private func persistIdentities() async {
        do {
            try await identityStore.save(identities)
        } catch {
            print("Failed to persist identities: \(error)")
        }
    }

    func upsertIdentity(_ identity: SavedIdentity, password: String?) async {
        var updated = identity

        if let password, !password.isEmpty {
            if updated.keychainIdentifier == nil {
                updated.keychainIdentifier = "echo.identity.\(updated.id.uuidString)"
            }
            if let identifier = updated.keychainIdentifier {
                do {
                    try keychain.setPassword(password, account: identifier)
                } catch {
                    print("Failed to save identity password: \(error)")
                }
            }
        }

        if let index = identities.firstIndex(where: { $0.id == updated.id }) {
            updated.createdAt = identities[index].createdAt
            updated.updatedAt = Date()
            identities[index] = updated
        } else {
            identities.append(updated)
        }

        if let folderID = updated.folderID,
           let folder = folders.first(where: { $0.id == folderID }),
           folder.kind != .identities {
            if let idx = identities.firstIndex(where: { $0.id == updated.id }) {
                identities[idx].folderID = nil
            }
        }

        await persistIdentities()
        await synchronizeConnections(forIdentityID: updated.id, using: updated)
    }

    func deleteIdentity(_ identity: SavedIdentity) async {
        if let identifier = identity.keychainIdentifier {
            try? keychain.deletePassword(account: identifier)
        }

        identities.removeAll { $0.id == identity.id }
        await persistIdentities()

        var connectionsChanged = false
        for index in connections.indices {
            if connections[index].credentialSource == .identity && connections[index].identityID == identity.id {
                connections[index].credentialSource = .manual
                connections[index].identityID = nil
                connections[index].username = ""
                connections[index].keychainIdentifier = nil
                connectionsChanged = true
            }
        }

        if connectionsChanged {
            await persistConnections()
        }

        var foldersChanged = false
        for index in folders.indices {
            if folders[index].credentialMode == .identity && folders[index].identityID == identity.id {
                folders[index].credentialMode = .none
                folders[index].identityID = nil
                foldersChanged = true
            }
        }

        if foldersChanged {
            await persistFolders()
        }

        if selectedIdentityID == identity.id {
            selectedIdentityID = identities.first?.id
        }
    }

    func upsertFolder(_ folder: SavedFolder, manualPassword: String? = nil) async {
        var updated = folder
        var trimmedManualPassword = manualPassword?.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedManualPassword?.isEmpty == true { trimmedManualPassword = nil }

        let existing = folders.first(where: { $0.id == updated.id })

        switch updated.credentialMode {
        case .manual:
            let trimmedUsername = updated.manualUsername?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard !trimmedUsername.isEmpty else {
                updated.manualUsername = nil
                updated.manualKeychainIdentifier = nil
                updated.credentialMode = .none
                trimmedManualPassword = nil
                break
            }

            updated.manualUsername = trimmedUsername

            let identifier = existing?.manualKeychainIdentifier ?? updated.manualKeychainIdentifier ?? "echo.folder.manual.\(updated.id.uuidString)"
            updated.manualKeychainIdentifier = identifier

            if let password = trimmedManualPassword {
                do {
                    try keychain.setPassword(password, account: identifier)
                } catch {
                    updated.manualUsername = nil
                    updated.manualKeychainIdentifier = nil
                    updated.credentialMode = .none
                }
            } else if existing?.credentialMode != .manual || existing?.manualKeychainIdentifier == nil {
                // No password available to persist
                try? keychain.deletePassword(account: identifier)
                updated.manualUsername = nil
                updated.manualKeychainIdentifier = nil
                updated.credentialMode = .none
            }

        default:
            updated.manualUsername = nil
            let identifier = existing?.manualKeychainIdentifier ?? updated.manualKeychainIdentifier
            if let identifier {
                try? keychain.deletePassword(account: identifier)
            }
            updated.manualKeychainIdentifier = nil
        }

        if updated.credentialMode == .identity && updated.identityID == nil {
            updated.credentialMode = .none
        }

        if updated.credentialMode == .inherit && updated.parentFolderID == nil {
            updated.credentialMode = .none
        }

        if updated.kind == .identities && updated.credentialMode == .inherit {
            updated.credentialMode = .none
        }

        if let parentID = updated.parentFolderID,
           let parent = folders.first(where: { $0.id == parentID }) {
            if parent.kind != updated.kind {
                updated.parentFolderID = nil
                if updated.credentialMode == .inherit {
                    updated.credentialMode = .none
                }
            }
        }

        if let index = folders.firstIndex(where: { $0.id == updated.id }) {
            updated.createdAt = folders[index].createdAt
            folders[index] = updated
        } else {
            folders.append(updated)
        }

        await persistFolders()
    }

    func deleteFolder(_ folder: SavedFolder) async {
        let allFolderIDs = descendantFolderIDs(of: folder.id) + [folder.id]

        if folder.kind == .connections {
            var connectionsChanged = false
            for index in connections.indices {
                if let folderID = connections[index].folderID, allFolderIDs.contains(folderID) {
                    connections[index].folderID = nil
                    if connections[index].credentialSource == .inherit {
                        connections[index].credentialSource = .manual
                        connections[index].username = ""
                        connections[index].keychainIdentifier = nil
                    }
                    connectionsChanged = true
                }
            }

            if connectionsChanged {
                await persistConnections()
            }
        }

        if folder.kind == .identities {
            var identitiesChanged = false
            for index in identities.indices {
                if let assignedFolderID = identities[index].folderID, allFolderIDs.contains(assignedFolderID) {
                    identities[index].folderID = nil
                    identitiesChanged = true
                }
            }

            if identitiesChanged {
                await persistIdentities()
            }
        }

        for folderID in allFolderIDs {
            if let identifier = folders.first(where: { $0.id == folderID })?.manualKeychainIdentifier {
                try? keychain.deletePassword(account: identifier)
            }
        }

        folders.removeAll { allFolderIDs.contains($0.id) }
        await persistFolders()

        if let selectedFolderID, allFolderIDs.contains(selectedFolderID) {
            self.selectedFolderID = folders.first(where: { $0.kind == .connections })?.id
        }
    }

    func moveConnection(_ connectionID: UUID, toFolder targetFolderID: UUID?) {
        guard let index = connections.firstIndex(where: { $0.id == connectionID }) else { return }

        if connections[index].folderID == targetFolderID { return }

        connections[index].folderID = targetFolderID

        if targetFolderID == nil, connections[index].credentialSource == .inherit {
            connections[index].credentialSource = .manual
            connections[index].identityID = nil
        }

        Task { await persistConnections() }
    }

    func moveIdentity(_ identityID: UUID, toFolder targetFolderID: UUID?) {
        guard let index = identities.firstIndex(where: { $0.id == identityID }) else { return }

        if identities[index].folderID == targetFolderID { return }

        if let targetFolderID,
           let folder = folders.first(where: { $0.id == targetFolderID }),
           folder.kind != .identities {
            return
        }

        identities[index].folderID = targetFolderID

        Task { await persistIdentities() }
    }

    func moveFolder(_ folderID: UUID, toParent parentID: UUID?) {
        guard let folderIndex = folders.firstIndex(where: { $0.id == folderID }) else { return }

        if folderID == parentID { return }

        if let parentID, descendantFolderIDs(of: folderID).contains(parentID) { return }

        if let parentID,
           let parent = folders.first(where: { $0.id == parentID }),
           parent.kind != folders[folderIndex].kind {
            return
        }

        folders[folderIndex].parentFolderID = parentID

        if parentID == nil, folders[folderIndex].credentialMode == .inherit {
            folders[folderIndex].credentialMode = .none
        }

        Task { await persistFolders() }
    }

    func duplicateConnection(_ connection: SavedConnection, copyBookmarks: Bool) async {
        var copy = connection
        copy.id = UUID()
        copy.connectionName = uniqueDuplicateName(for: connection.connectionName)
        copy.serverVersion = nil
        copy.cachedStructure = nil
        copy.cachedStructureUpdatedAt = nil

        var password: String?
        if connection.credentialSource == .manual,
           let identifier = connection.keychainIdentifier,
           let storedPassword = try? keychain.getPassword(account: identifier) {
            password = storedPassword
            copy.keychainIdentifier = nil
        }

        let sourceBookmarks: [Bookmark]
        let targetProjectID: UUID?
        if copyBookmarks {
            sourceBookmarks = bookmarks(for: connection.id)
            targetProjectID = connection.projectID ?? connectionProjectID(connection.id)
        } else {
            sourceBookmarks = []
            targetProjectID = nil
        }

        await upsertConnection(copy, password: password)

        if copyBookmarks,
           let projectID = targetProjectID,
           !sourceBookmarks.isEmpty {
            await mutateBookmarks(for: projectID) { bookmarks in
                let duplicates: [Bookmark] = sourceBookmarks.map { bookmark in
                    Bookmark(
                        id: UUID(),
                        connectionID: copy.id,
                        databaseName: bookmark.databaseName,
                        title: bookmark.title,
                        query: bookmark.query,
                        createdAt: bookmark.createdAt,
                        updatedAt: bookmark.updatedAt,
                        source: bookmark.source
                    )
                }

                // Maintain chronological ordering by inserting in reverse
                for bookmark in duplicates.reversed() {
                    bookmarks.insert(bookmark, at: 0)
                }
            }
        }

        selectedConnectionID = copy.id
    }

    private func uniqueDuplicateName(for name: String) -> String {
        let base = name.isEmpty ? "Untitled" : name
        var attempt = "\(base) Copy"
        var counter = 2
        while connections.contains(where: { $0.connectionName == attempt }) {
            attempt = "\(base) Copy \(counter)"
            counter += 1
        }
        return attempt
    }

    private func identity(withID id: UUID?) -> SavedIdentity? {
        guard let id else { return nil }
        return identities.first { $0.id == id }
    }

    private func folder(withID id: UUID?) -> SavedFolder? {
        guard let id else { return nil }
        return folders.first { $0.id == id }
    }

    private enum FolderResolvedCredentials {
        case manual(username: String, password: String?)
        case identity(SavedIdentity)
    }

    private func resolvedIdentity(forFolderID folderID: UUID, visited: Set<UUID> = []) -> SavedIdentity? {
        guard !visited.contains(folderID), let folder = folder(withID: folderID) else {
            return nil
        }

        switch folder.credentialMode {
        case .none:
            return nil
        case .manual:
            return nil
        case .identity:
            return identity(withID: folder.identityID)
        case .inherit:
            guard let parentID = folder.parentFolderID else { return nil }
            var updatedVisited = visited
            updatedVisited.insert(folderID)
            return resolvedIdentity(forFolderID: parentID, visited: updatedVisited)
        }
    }

    private func resolvedFolderCredentials(forFolderID folderID: UUID, visited: Set<UUID> = []) -> FolderResolvedCredentials? {
        guard !visited.contains(folderID), let folder = folder(withID: folderID) else {
            return nil
        }

        switch folder.credentialMode {
        case .none:
            return nil
        case .manual:
            guard let username = folder.manualUsername?.trimmingCharacters(in: .whitespacesAndNewlines), !username.isEmpty else {
                return nil
            }
            let password = folder.manualKeychainIdentifier.flatMap { try? keychain.getPassword(account: $0) }
            return .manual(username: username, password: password)
        case .identity:
            guard let identity = identity(withID: folder.identityID) else { return nil }
            return .identity(identity)
        case .inherit:
            guard let parentID = folder.parentFolderID else { return nil }
            var updatedVisited = visited
            updatedVisited.insert(folderID)
            return resolvedFolderCredentials(forFolderID: parentID, visited: updatedVisited)
        }
    }

    private func resolvedCredentials(for connection: SavedConnection, overridePassword: String? = nil) -> DatabaseAuthenticationConfiguration? {
        let username: String
        let password: String?

        switch connection.credentialSource {
        case .manual:
            username = connection.username
            password = overridePassword ?? connection.keychainIdentifier.flatMap { try? keychain.getPassword(account: $0) }
        case .identity:
            guard let identity = identity(withID: connection.identityID) else { return nil }
            username = identity.username
            password = overridePassword ?? identity.keychainIdentifier.flatMap { try? keychain.getPassword(account: $0) }
        case .inherit:
            guard let folderID = connection.folderID,
                  let credentials = resolvedFolderCredentials(forFolderID: folderID) else { return nil }

            switch credentials {
            case .identity(let identity):
                username = identity.username
                password = overridePassword ?? identity.keychainIdentifier.flatMap { try? keychain.getPassword(account: $0) }
            case .manual(let manualUsername, let storedPassword):
                username = manualUsername
                password = overridePassword ?? storedPassword
            }
        }

        let trimmedDomain = connection.domain.trimmingCharacters(in: .whitespacesAndNewlines)
        let domain = trimmedDomain.isEmpty ? nil : trimmedDomain

        return DatabaseAuthenticationConfiguration(
            method: connection.authenticationMethod,
            username: username,
            password: password,
            domain: domain
        )
    }

    func folderIdentity(for folderID: UUID) -> SavedIdentity? {
        resolvedIdentity(forFolderID: folderID)
    }

    private func synchronizeConnections(forIdentityID identityID: UUID, using identity: SavedIdentity) async {
        var connectionsChanged = false
        for index in connections.indices {
            if connections[index].credentialSource == .identity && connections[index].identityID == identityID {
                if connections[index].username != identity.username {
                    connections[index].username = identity.username
                    connectionsChanged = true
                }
            }
        }

        if connectionsChanged {
            await persistConnections()
        }
    }

    private func descendantFolderIDs(of folderID: UUID) -> [UUID] {
        guard let root = folders.first(where: { $0.id == folderID }) else { return [] }
        return descendantFolderIDs(of: folderID, kind: root.kind)
    }

    private func descendantFolderIDs(of folderID: UUID, kind: FolderKind) -> [UUID] {
        var ids: [UUID] = []
        for folder in folders where folder.parentFolderID == folderID && folder.kind == kind {
            ids.append(folder.id)
            ids.append(contentsOf: descendantFolderIDs(of: folder.id, kind: kind))
        }
        return ids
    }

    // MARK: - Session lifecycle
    func connect(to connection: SavedConnection) async {
        await connectToNewSession(to: connection)
    }

    func connectToRecentConnection(_ record: RecentConnectionRecord) async {
        guard var connection = connections.first(where: { $0.id == record.connectionID }) else { return }
        if let databaseName = record.databaseName {
            connection.database = databaseName
        }
        await connect(to: connection)
    }

    func connectToNewSession(
        to connection: SavedConnection,
        forceReconnect: Bool = false,
        reuseSessionID: UUID? = nil,
        previousSession: ConnectionSession? = nil
    ) async {
        connectionStates[connection.id] = .connecting

        var priorSession: ConnectionSession?
        if let existing = sessionManager.sessionForConnection(connection.id) {
            if forceReconnect {
                priorSession = existing
                await existing.session.close()
                sessionManager.removeSession(withID: existing.id)
            } else {
                sessionManager.setActiveSession(existing.id)
                selectedConnectionID = existing.connection.id
                connectionStates[connection.id] = .connected
                return
            }
        }

        do {
            let shouldOpenInitialTab = tabManager.tabs.isEmpty
            guard let credentials = resolvedCredentials(for: connection) else {
                throw DatabaseError.connectionFailed("Credentials not configured")
            }

            var resolvedConnection = connection
            resolvedConnection.username = credentials.username

            guard let factory = makeDatabaseFactory(for: resolvedConnection.databaseType) else {
                throw DatabaseError.connectionFailed("Unsupported database type: \(resolvedConnection.databaseType.displayName)")
            }

            let databaseSession = try await factory.connect(
                host: resolvedConnection.host,
                port: resolvedConnection.port,
                database: resolvedConnection.database.isEmpty ? nil : resolvedConnection.database,
                tls: resolvedConnection.useTLS,
                authentication: credentials
            )

            let session = ConnectionSession(
                id: reuseSessionID ?? UUID(),
                connection: resolvedConnection,
                session: databaseSession
            )

            session.selectedDatabaseName = resolvedConnection.database.isEmpty ? nil : resolvedConnection.database

            if let cached = resolvedConnection.cachedStructure {
                session.databaseStructure = cached
                session.structureLoadingState = .ready
            } else if let previousStructure = previousSession?.databaseStructure ?? priorSession?.databaseStructure {
                session.databaseStructure = previousStructure
                session.structureLoadingState = previousSession?.structureLoadingState ?? priorSession?.structureLoadingState ?? .idle
            } else {
                session.databaseStructure = DatabaseStructure(databases: [])
                session.structureLoadingState = .loading(progress: nil)
            }

            sessionManager.addSession(session)
            observeSession(session)
            sessionManager.setActiveSession(session.id)
            selectedConnectionID = resolvedConnection.id
            connectionStates[resolvedConnection.id] = .connected

            if shouldOpenInitialTab {
                openQueryTab(for: session)
            }

            let targetDatabase = session.selectedDatabaseName ?? (resolvedConnection.database.isEmpty ? nil : resolvedConnection.database)
            recordRecentConnection(for: resolvedConnection, databaseName: targetDatabase)

            Task {
                do {
                    let structure = try await loadDatabaseStructureForSession(session)
                    await MainActor.run {
                        session.databaseStructure = structure
                        session.structureLoadingState = .ready
                        cacheStructure(structure, for: session.connection.id)
                    }
                } catch {
                    await MainActor.run {
                        session.structureLoadingState = .failed(message: error.localizedDescription)
                    }
                    print("Failed to load database structure: \(error)")
                }
            }
        } catch {
            let dbError = DatabaseError.from(error)
            connectionStates[connection.id] = .error(dbError)
            print("Connection failed: \(error)")
        }
    }

    func reconnectSession(_ session: ConnectionSession, to databaseName: String) async {
        guard session.selectedDatabaseName != databaseName else { return }
        var baseConnection = session.connection
        baseConnection.database = databaseName
        await connectToNewSession(
            to: baseConnection,
            forceReconnect: true,
            reuseSessionID: session.id,
            previousSession: session
        )
        updateCachedConnection(id: baseConnection.id) { connection in
            connection.database = databaseName
        }
    }

    func disconnect() async {
        for session in sessionManager.activeSessions {
            await session.session.close()
            connectionStates[session.connection.id] = .disconnected
        }
        sessionManager.activeSessions.removeAll()
        if sessionManager.activeSessions.isEmpty {
            selectedConnectionID = nil
        }
    }

    func disconnectSession(withID sessionID: UUID) async {
        guard let session = sessionManager.activeSessions.first(where: { $0.id == sessionID }) else { return }
        await session.session.close()
        sessionManager.removeSession(withID: sessionID)
        connectionStates[session.connection.id] = .disconnected
        if sessionManager.activeSessions.isEmpty {
            selectedConnectionID = nil
        }
    }

    // MARK: - Queries
    func executeQuery(_ sql: String) async throws -> QueryResultSet {
        guard let session = sessionManager.activeSession else {
            throw DatabaseError.connectionFailed("No active connection")
        }
        return try await session.session.simpleQuery(sql)
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        guard let session = sessionManager.activeSession else {
            throw DatabaseError.connectionFailed("No active connection")
        }
        return try await session.session.executeUpdate(sql)
    }

    func listTables() async throws -> [String] {
        guard let session = sessionManager.activeSession else {
            throw DatabaseError.connectionFailed("No active connection")
        }
        let schema: String?
        switch session.connection.databaseType {
        case .postgresql:
            schema = "public"
        default:
            schema = nil
        }

        let objects = try await session.session.listTablesAndViews(schema: schema)
        return objects.map { $0.name }
    }

    // MARK: - Database Metadata
func loadDatabaseStructureForSession(_ connectionSession: ConnectionSession) async throws -> DatabaseStructure {
        connectionSession.structureLoadingState = .loading(progress: 0)
        connectionSession.structureLoadingMessage = "Preparing update…"

        if connectionSession.databaseStructure == nil {
            connectionSession.databaseStructure = DatabaseStructure(serverVersion: nil, databases: [])
        }

        if connectionSession.selectedDatabaseName == nil,
           !connectionSession.connection.database.isEmpty {
            connectionSession.selectedDatabaseName = connectionSession.connection.database
        }

        guard let credentials = resolvedCredentials(for: connectionSession.connection) else {
            connectionSession.structureLoadingState = .failed(message: "Missing credentials")
            throw DatabaseError.connectionFailed("Missing credentials")
        }

        let selectedDatabase: String?
        if let selected = connectionSession.selectedDatabaseName, !selected.isEmpty {
            selectedDatabase = selected
        } else if !connectionSession.connection.database.isEmpty {
            selectedDatabase = connectionSession.connection.database
        } else {
            selectedDatabase = nil
        }

        var interimServerVersion = connectionSession.databaseStructure?.serverVersion
            ?? connectionSession.connection.cachedStructure?.serverVersion
            ?? connectionSession.connection.serverVersion

        guard let fetcher = makeStructureFetcher(for: connectionSession.connection) else {
            connectionSession.structureLoadingState = .failed(message: "Unsupported database type")
            throw DatabaseError.connectionFailed("Unsupported database type: \(connectionSession.connection.databaseType.displayName)")
        }

        do {
            let structure = try await fetcher.fetchStructure(
                for: connectionSession.connection,
                credentials: .init(authentication: credentials),
                selectedDatabase: selectedDatabase,
                reuseSession: connectionSession.session,
                progressHandler: { progress in
                    await MainActor.run {
                        connectionSession.structureLoadingState = .loading(progress: progress.fraction)
                        if let message = progress.message {
                            connectionSession.structureLoadingMessage = message
                        }
                    }
                },
                databaseHandler: { database, _, _ in
                    await MainActor.run {
                        var databases = connectionSession.databaseStructure?.databases ?? []
                        if let index = databases.firstIndex(where: { $0.name == database.name }) {
                            databases[index] = database
                        } else {
                            databases.append(database)
                            databases.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                        }
                        connectionSession.databaseStructure = DatabaseStructure(
                            serverVersion: interimServerVersion,
                            databases: databases
                        )
                    }
                }
            )

            if let serverVersion = structure.serverVersion {
                interimServerVersion = serverVersion
            }

            connectionSession.databaseStructure = DatabaseStructure(
                serverVersion: interimServerVersion,
                databases: structure.databases
            )
            connectionSession.structureLoadingState = .ready
            connectionSession.structureLoadingMessage = nil

            if connectionSession.selectedDatabaseName == nil,
               !connectionSession.connection.database.isEmpty,
               let firstDatabase = structure.databases.first?.name {
                connectionSession.selectedDatabaseName = firstDatabase
            }

            return structure
        } catch {
            connectionSession.structureLoadingMessage = error.localizedDescription
            connectionSession.structureLoadingState = .failed(message: error.localizedDescription)
            throw error
        }
    }
    func testConnection(_ connection: SavedConnection, passwordOverride: String? = nil) async -> ConnectionTestResult {
        connectionStates[connection.id] = .testing
        let startTime = Date()

        do {
            guard let credentials = resolvedCredentials(for: connection, overridePassword: passwordOverride) else {
                let responseTime = Date().timeIntervalSince(startTime)
                let result = ConnectionTestResult(
                    isSuccessful: false,
                    message: "Missing credentials",
                    responseTime: responseTime,
                    serverVersion: nil
                )
                connectionStates[connection.id] = .error(.connectionFailed("Missing credentials"))
                return result
            }

            guard let factory = makeDatabaseFactory(for: connection.databaseType) else {
                let responseTime = Date().timeIntervalSince(startTime)
                let result = ConnectionTestResult(
                    isSuccessful: false,
                    message: "Unsupported database type",
                    responseTime: responseTime,
                    serverVersion: nil
                )
                connectionStates[connection.id] = .error(.connectionFailed("Unsupported database type: \(connection.databaseType.displayName)"))
                return result
            }

            let session = try await factory.connect(
                host: connection.host,
                port: connection.port,
                database: connection.database.isEmpty ? nil : connection.database,
                tls: connection.useTLS,
                authentication: credentials
            )

            defer { Task { await session.close() } }

            _ = try await session.simpleQuery("SELECT 1")
            connectionStates[connection.id] = .connected

            let responseTime = Date().timeIntervalSince(startTime)
            return ConnectionTestResult(
                isSuccessful: true,
                message: "Connection successful",
                responseTime: responseTime,
                serverVersion: nil
            )
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            let dbError = DatabaseError.from(error)
            connectionStates[connection.id] = .error(dbError)
            return ConnectionTestResult(
                isSuccessful: false,
                message: dbError.errorDescription ?? "Connection failed",
                responseTime: responseTime,
                serverVersion: nil
            )
        }
    }

    func loadSchemaForDatabase(_ databaseName: String, connectionSession: ConnectionSession) async {
        await reconnectSession(connectionSession, to: databaseName)
    }

    func refreshDatabaseStructure(for sessionID: UUID, scope: StructureRefreshScope = .selectedDatabase, databaseOverride: String? = nil) async {
        guard let session = sessionManager.activeSessions.first(where: { $0.id == sessionID }) else { return }

        switch scope {
        case .full:
            do {
                let structure = try await loadDatabaseStructureForSession(session)
                session.databaseStructure = structure
                cacheStructure(structure, for: session.connection.id)
            } catch {
                session.structureLoadingState = .failed(message: error.localizedDescription)
            }

        case .selectedDatabase:
            let targetDatabase = databaseOverride ?? (session.selectedDatabaseName?.isEmpty == false
                ? session.selectedDatabaseName
                : (session.connection.database.isEmpty ? nil : session.connection.database))

            guard let targetDatabase else {
                await refreshDatabaseStructure(for: sessionID, scope: .full)
                return
            }

            guard let credentials = resolvedCredentials(for: session.connection) else {
                session.structureLoadingState = .failed(message: "Missing credentials")
                return
            }

            session.structureLoadingState = .loading(progress: 0)
            session.structureLoadingMessage = "Updating \(targetDatabase)…"

            guard let fetcher = makeStructureFetcher(for: session.connection) else {
                session.structureLoadingState = .failed(message: "Unsupported database type")
                return
            }

            do {
            let structure = try await fetcher.fetchStructure(
                for: session.connection,
                credentials: .init(authentication: credentials),
                    selectedDatabase: targetDatabase,
                    reuseSession: session.session,
                    databaseFilter: [targetDatabase],
                    progressHandler: { progress in
                        await MainActor.run {
                            session.structureLoadingState = .loading(progress: progress.fraction)
                            if let message = progress.message {
                                session.structureLoadingMessage = message
                            }
                        }
                    },
                    databaseHandler: nil
                )

                let updatedDatabase = structure.databases.first { $0.name == targetDatabase }

                var mergedDatabases = session.databaseStructure?.databases ?? []
                if let updatedDatabase {
                    if let index = mergedDatabases.firstIndex(where: { $0.name == updatedDatabase.name }) {
                        mergedDatabases[index] = updatedDatabase
                    } else {
                        mergedDatabases.append(updatedDatabase)
                        mergedDatabases.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    }
                }

                let updatedStructure = DatabaseStructure(
                    serverVersion: structure.serverVersion ?? session.databaseStructure?.serverVersion ?? session.connection.serverVersion,
                    databases: mergedDatabases
                )

                session.databaseStructure = updatedStructure
                session.structureLoadingState = .ready
                session.structureLoadingMessage = nil

                cacheStructure(updatedStructure, for: session.connection.id)

            } catch {
                session.structureLoadingMessage = error.localizedDescription
                session.structureLoadingState = .failed(message: error.localizedDescription)
            }
        }
    }

    // MARK: - Pin helpers
    func pinObject(withID id: String) {
        guard !pinnedObjectIDs.contains(id) else { return }
        pinnedObjectIDs.append(id)
    }

    func unpinObject(withID id: String) {
        pinnedObjectIDs.removeAll { $0 == id }
    }

    func isObjectPinned(withID id: String) -> Bool {
        pinnedObjectIDs.contains(id)
    }

    // MARK: - Private helpers
    private func updateCachedConnection(id: UUID, update: (inout SavedConnection) -> Void) {
        guard let index = connections.firstIndex(where: { $0.id == id }) else { return }
        update(&connections[index])
        Task { await persistConnections() }
    }

    private func cacheStructure(_ structure: DatabaseStructure, for connectionID: UUID) {
        updateCachedConnection(id: connectionID) { connection in
            connection.cachedStructure = structure
            connection.cachedStructureUpdatedAt = Date()
            if let serverVersion = structure.serverVersion {
                connection.serverVersion = serverVersion
            }
        }
    }

    private func preloadStructure(for connection: SavedConnection, overridePassword: String?) async {
        guard let credentials = resolvedCredentials(for: connection, overridePassword: overridePassword) else {
            return
        }

        guard let fetcher = makeStructureFetcher(for: connection) else { return }

        do {
        let structure = try await fetcher.fetchStructure(
            for: connection,
            credentials: .init(authentication: credentials),
                selectedDatabase: connection.database.isEmpty ? nil : connection.database
            )
            cacheStructure(structure, for: connection.id)
        } catch {
            print("Failed to preload structure for connection \(connection.connectionName): \(error)")
        }
    }

    // MARK: - Project Management

    private func migrateToProjects() async {
        guard let defaultProject = projects.first(where: { $0.isDefault }) else { return }

        var needsSave = false

        // Migrate connections
        for i in connections.indices {
            if connections[i].projectID == nil {
                connections[i].projectID = defaultProject.id
                needsSave = true
            }
        }
        if needsSave {
            await persistConnections()
            needsSave = false
        }

        // Migrate identities
        for i in identities.indices {
            if identities[i].projectID == nil {
                identities[i].projectID = defaultProject.id
                needsSave = true
            }
        }
        if needsSave {
            await persistIdentities()
            needsSave = false
        }

        // Migrate folders
        for i in folders.indices {
            if folders[i].projectID == nil {
                folders[i].projectID = defaultProject.id
                needsSave = true
            }
        }
        if needsSave {
            await persistFolders()
        }
    }

    func createProject(_ project: Project) async {
        projects.append(project)
        do {
            try await projectStore.save(projects)
        } catch {
            print("Failed to save new project: \(error)")
        }
    }

    func updateProject(_ project: Project) async {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index] = project
        do {
            try await projectStore.save(projects)
        } catch {
            print("Failed to update project: \(error)")
        }
    }

    func deleteProject(_ project: Project) async {
        // Don't delete the default project
        guard !project.isDefault else { return }

        // Delete all associated data
        connections.removeAll { $0.projectID == project.id }
        identities.removeAll { $0.projectID == project.id }
        folders.removeAll { $0.projectID == project.id }

        await persistConnections()
        await persistIdentities()
        await persistFolders()

        projects.removeAll { $0.id == project.id }
        do {
            try await projectStore.save(projects)
        } catch {
            print("Failed to delete project: \(error)")
        }

        // Select default project if we deleted the selected one
        if selectedProject?.id == project.id {
            selectedProject = projects.first(where: { $0.isDefault }) ?? projects.first
            if let newProject = selectedProject {
                navigationState.selectProject(newProject)
            }
        }
    }

    func exportProject(
        _ project: Project,
        includeGlobalSettings: Bool,
        includeClipboardHistory: Bool,
        password: String
    ) async throws -> Data {
        let projectConnections = connections.filter { $0.projectID == project.id }
        let projectIdentities = identities.filter { $0.projectID == project.id }
        let projectFolders = folders.filter { $0.projectID == project.id }
        let clipboardEntries = includeClipboardHistory ? clipboardHistory.entries : nil

        return try await projectStore.exportProject(
            project,
            connections: projectConnections,
            identities: projectIdentities,
            folders: projectFolders,
            globalSettings: includeGlobalSettings ? globalSettings : nil,
            clipboardHistory: clipboardEntries,
            password: password
        )
    }

    func importProject(from data: Data, password: String) async throws {
        let exportData = try await projectStore.importProject(from: data, password: password)

        // Create a new project with a unique ID
        var importedProject = exportData.project
        importedProject.id = UUID()
        importedProject.isDefault = false
        importedProject.name = uniqueProjectName(for: importedProject.name)

        // Update all foreign keys to point to the new project
        var importedConnections = exportData.connections
        var connectionIDMap: [UUID: UUID] = [:]
        for i in importedConnections.indices {
            let originalID = importedConnections[i].id
            let newID = UUID()
            importedConnections[i].id = newID
            importedConnections[i].projectID = importedProject.id
            connectionIDMap[originalID] = newID
        }

        var importedIdentities = exportData.identities
        for i in importedIdentities.indices {
            importedIdentities[i].id = UUID()
            importedIdentities[i].projectID = importedProject.id
        }

        var importedFolders = exportData.folders
        for i in importedFolders.indices {
            importedFolders[i].id = UUID()
            importedFolders[i].projectID = importedProject.id
        }

        let sourceBookmarks = exportData.bookmarks.isEmpty ? exportData.project.bookmarks : exportData.bookmarks
        let remappedBookmarks: [Bookmark] = sourceBookmarks.compactMap { bookmark in
            guard let newConnectionID = connectionIDMap[bookmark.connectionID] else { return nil }
            var updated = bookmark
            updated.id = UUID()
            updated.connectionID = newConnectionID
            return updated
        }

        importedProject.bookmarks = remappedBookmarks

        // Add to collections
        projects.append(importedProject)
        connections.append(contentsOf: importedConnections)
        identities.append(contentsOf: importedIdentities)
        folders.append(contentsOf: importedFolders)

        // Save everything
        try await projectStore.save(projects)
        await persistConnections()
        await persistIdentities()
        await persistFolders()

        if let importedHistory = exportData.clipboardHistory {
            mergeImportedClipboardEntries(importedHistory)
        }

        // Optionally import global settings
        if let importedGlobalSettings = exportData.globalSettings {
            globalSettings = importedGlobalSettings
            try await projectStore.saveGlobalSettings(globalSettings)
        }

        // Select the newly imported project
        selectedProject = importedProject
        navigationState.selectProject(importedProject)
    }

    private func uniqueProjectName(for name: String) -> String {
        let base = name.isEmpty ? "Untitled" : name
        var attempt = base
        var counter = 2
        while projects.contains(where: { $0.name == attempt }) {
            attempt = "\(base) \(counter)"
            counter += 1
        }
        return attempt
    }

}

// MARK: - Bookmarks

extension AppModel {
    func bookmarks(for connectionID: UUID) -> [Bookmark] {
        guard let projectID = connectionProjectID(connectionID) else { return [] }
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }) else {
            let selected = selectedProject?.bookmarks ?? []
            return sortedBookmarks(selected.filter { $0.connectionID == connectionID })
        }
        let bookmarks = projects[projectIndex].bookmarks
            .filter { $0.connectionID == connectionID }
        return sortedBookmarks(bookmarks)
    }

    func bookmarks(in projectID: UUID?) -> [Bookmark] {
        let targetID = projectID ?? selectedProject?.id
        guard let id = targetID else { return [] }
        if let index = projects.firstIndex(where: { $0.id == id }) {
            return sortedBookmarks(projects[index].bookmarks)
        }
        if selectedProject?.id == id {
            return sortedBookmarks(selectedProject?.bookmarks ?? [])
        }
        return []
    }

    func addBookmark(
        for connection: SavedConnection,
        databaseName: String?,
        title: String?,
        query: String,
        source: Bookmark.Source
    ) async {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return }
        guard let projectID = connection.projectID ?? selectedProject?.id else { return }

        let bookmark = Bookmark(
            connectionID: connection.id,
            databaseName: normalizedDatabaseName(databaseName),
            title: normalizedTitle(title),
            query: normalizedQuery,
            source: source
        )

        await mutateBookmarks(for: projectID) { bookmarks in
            // Prevent duplicate entries with the same query for the same database/server pair
            if let existingIndex = bookmarks.firstIndex(where: {
                $0.connectionID == bookmark.connectionID &&
                $0.databaseName?.caseInsensitiveCompare(bookmark.databaseName ?? "") == .orderedSame &&
                $0.query == bookmark.query
            }) {
                bookmarks.remove(at: existingIndex)
            }
            bookmarks.insert(bookmark, at: 0)
        }
    }

    func removeBookmark(_ bookmark: Bookmark) async {
        guard let projectID = connectionProjectID(bookmark.connectionID) ?? selectedProject?.id else { return }
        await mutateBookmarks(for: projectID) { bookmarks in
            bookmarks.removeAll { $0.id == bookmark.id }
        }
    }

    func renameBookmark(_ bookmark: Bookmark, to title: String?) async {
        guard let projectID = connectionProjectID(bookmark.connectionID) ?? selectedProject?.id else { return }
        await mutateBookmarks(for: projectID) { bookmarks in
            guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
            var updated = bookmarks[index]
            updated.title = normalizedTitle(title)
            updated.updatedAt = Date()
            bookmarks[index] = updated
        }
    }

    func updateBookmarkQuery(_ bookmarkID: UUID, newQuery: String) async {
        guard let projectID = projectIDContainingBookmark(bookmarkID) else { return }
        await mutateBookmarks(for: projectID) { bookmarks in
            guard let index = bookmarks.firstIndex(where: { $0.id == bookmarkID }) else { return }
            var updated = bookmarks[index]
            updated.query = newQuery
            updated.updatedAt = Date()
            bookmarks[index] = updated
        }
    }

    func removeBookmarks(forConnectionID connectionID: UUID, projectID: UUID? = nil) async {
        let targetProjectID = projectID ?? connectionProjectID(connectionID)
        guard let projectID = targetProjectID else { return }
        await mutateBookmarks(for: projectID) { bookmarks in
            bookmarks.removeAll { $0.connectionID == connectionID }
        }
    }

    func copyBookmark(_ bookmark: Bookmark) {
        PlatformClipboard.copy(bookmark.query)
    }

    func openBookmark(_ bookmark: Bookmark) async {
        guard let connection = connections.first(where: { $0.id == bookmark.connectionID }) else { return }

        var session = sessionManager.sessionForConnection(connection.id)
        if session == nil {
            await connect(to: connection)
            session = sessionManager.sessionForConnection(connection.id)
        }

        guard let activeSession = session else { return }

        if let database = normalizedDatabaseName(bookmark.databaseName),
           let current = activeSession.selectedDatabaseName,
           current.caseInsensitiveCompare(database) != .orderedSame {
            await reconnectSession(activeSession, to: database)
        } else if let database = normalizedDatabaseName(bookmark.databaseName), activeSession.selectedDatabaseName == nil {
            await reconnectSession(activeSession, to: database)
        }

        guard let refreshedSession = sessionManager.sessionForConnection(connection.id) else { return }

        sessionManager.setActiveSession(refreshedSession.id)
        if let database = normalizedDatabaseName(bookmark.databaseName) {
            navigationState.selectConnection(connection)
            navigationState.selectDatabase(database)
        } else {
            navigationState.selectConnection(connection)
        }

        let context = WorkspaceTab.BookmarkTabContext(bookmark: bookmark)
        openQueryTab(for: refreshedSession,
                     presetQuery: bookmark.query,
                     bookmarkContext: context)
    }

    private func mutateBookmarks(for projectID: UUID, update: (inout [Bookmark]) -> Void) async {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        update(&projects[index].bookmarks)
        projects[index].updatedAt = Date()

        if selectedProject?.id == projectID {
            selectedProject = projects[index]
        }

        do {
            try await projectStore.save(projects)
        } catch {
            print("Failed to persist bookmarks: \(error)")
        }
    }

    private func connectionProjectID(_ connectionID: UUID) -> UUID? {
        connections.first(where: { $0.id == connectionID })?.projectID
    }

    private func normalizedDatabaseName(_ name: String?) -> String? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func normalizedTitle(_ title: String?) -> String? {
        guard let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func projectIDContainingBookmark(_ bookmarkID: UUID) -> UUID? {
        if let project = projects.first(where: { project in
            project.bookmarks.contains(where: { $0.id == bookmarkID })
        }) {
            return project.id
        }

        if let project = selectedProject,
           project.bookmarks.contains(where: { $0.id == bookmarkID }) {
            return project.id
        }

        return nil
    }

    private func sortedBookmarks(_ bookmarks: [Bookmark]) -> [Bookmark] {
        bookmarks.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id.uuidString > rhs.id.uuidString
            }
            return lhs.createdAt > rhs.createdAt
        }
    }
}

// MARK: - Navigation Synchronization Helpers

private extension AppModel {
    func mergeImportedClipboardEntries(_ entries: [ClipboardHistoryStore.Entry]) {
        clipboardHistory.importEntries(entries)
    }

    func applySelectedConnection(_ id: UUID?) {
        guard let id,
              let connection = connections.first(where: { $0.id == id }) else {
            navigationState.selectedConnection = nil
            navigationState.selectedDatabase = nil
            return
        }

        if let projectID = connection.projectID,
           navigationState.selectedProject?.id != projectID,
           let project = projects.first(where: { $0.id == projectID }) {
            navigationState.selectProject(project)
        } else if navigationState.selectedProject == nil,
                  let defaultProject = selectedProject ?? projects.first {
            navigationState.selectProject(defaultProject)
        }

        if navigationState.selectedConnection?.id != connection.id {
            navigationState.selectConnection(connection)
        }

        if let session = sessionManager.sessionForConnection(connection.id),
           let database = session.selectedDatabaseName,
           !database.isEmpty {
            if navigationState.selectedDatabase != database {
                navigationState.selectDatabase(database)
            }
        } else {
            navigationState.selectedDatabase = nil
        }
    }

    // MARK: - Recent Connections

    private func loadRecentConnections() {
        guard let data = UserDefaults.standard.data(forKey: Self.recentConnectionsKey) else {
            recentConnections = []
            return
        }

        do {
            recentConnections = try JSONDecoder().decode([RecentConnectionRecord].self, from: data)
            pruneRecentConnections()
        } catch {
            recentConnections = []
            print("Failed to load recent connections: \(error)")
        }
    }

    private func saveRecentConnections() {
        guard let data = try? JSONEncoder().encode(recentConnections) else { return }
        UserDefaults.standard.set(data, forKey: Self.recentConnectionsKey)
    }

    private func recordRecentConnection(for connection: SavedConnection, databaseName: String?) {
        var normalizedDatabase = databaseName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedDatabase?.isEmpty == true {
            normalizedDatabase = nil
        }

        let record = RecentConnectionRecord(
            connectionID: connection.id,
            databaseName: normalizedDatabase,
            lastConnectedAt: Date()
        )

        recentConnections.removeAll { $0.id == record.id }
        recentConnections.insert(record, at: 0)
        pruneRecentConnections()
        saveRecentConnections()
    }

    private func pruneRecentConnections() {
        recentConnections.sort { $0.lastConnectedAt > $1.lastConnectedAt }
        if recentConnections.count > 5 {
            recentConnections = Array(recentConnections.prefix(5))
        }
    }

    private func removeRecentConnections(for connectionID: UUID) {
        let filtered = recentConnections.filter { $0.connectionID != connectionID }
        if filtered != recentConnections {
            recentConnections = filtered
            pruneRecentConnections()
            saveRecentConnections()
        }
    }

    private func synchronizeRecentConnectionsWithConnections() {
        pruneRecentConnections()
        let existingIDs = Set(connections.map { $0.id })
        let filtered = recentConnections.filter { existingIDs.contains($0.connectionID) }
        if filtered != recentConnections {
            recentConnections = filtered
            pruneRecentConnections()
            saveRecentConnections()
        }
    }

    func updateNavigation(for session: ConnectionSession?) {
        guard let session else {
            navigationState.selectedConnection = nil
            navigationState.selectedDatabase = nil
            return
        }

        let connection = session.connection

        if let projectID = connection.projectID,
           navigationState.selectedProject?.id != projectID,
           let project = projects.first(where: { $0.id == projectID }) {
            navigationState.selectProject(project)
        } else if navigationState.selectedProject == nil,
                  let defaultProject = selectedProject ?? projects.first {
            navigationState.selectProject(defaultProject)
        }

        if navigationState.selectedConnection?.id != connection.id {
            navigationState.selectConnection(connection)
        }

        if let database = session.selectedDatabaseName,
           !database.isEmpty {
            if navigationState.selectedDatabase != database {
                navigationState.selectDatabase(database)
            }
        } else {
            navigationState.selectedDatabase = nil
        }
    }

    func observeSession(_ session: ConnectionSession) {
        sessionDatabaseCancellables[session.id]?.cancel()
        sessionDatabaseCancellables[session.id] = session.$selectedDatabaseName
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] database in
                guard let self else { return }
                guard self.sessionManager.activeSessionID == session.id else { return }

                if let database, !database.isEmpty {
                    if self.navigationState.selectedDatabase != database {
                        self.navigationState.selectDatabase(database)
                    }
                } else {
                    self.navigationState.selectedDatabase = nil
                }
            }
    }

    func pruneSessionCancellables(validIDs: [UUID]) {
        for (id, cancellable) in sessionDatabaseCancellables where !validIDs.contains(id) {
            cancellable.cancel()
            sessionDatabaseCancellables.removeValue(forKey: id)
        }
    }
}
