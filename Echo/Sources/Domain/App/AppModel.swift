//
//  AppModel.swift
//  Echo
//
//  Created by Kenneth Berg on 15/09/2025.
//

import Foundation
import SwiftUI
import Combine
import SQLServerKit

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
    @Published var connectionStates: [UUID: ConnectionState] = [:]
    @Published var sessionManager = ConnectionSessionManager()
    @Published var pinnedObjectIDs: [String] = []
    @Published private(set) var recentConnections: [RecentConnectionRecord] = []
    @Published var searchSidebarCaches: [SearchSidebarContextKey: SearchSidebarCache] = [:]
    @Published var dataInspectorContent: DataInspectorContent?
    @Published private(set) var expandedConnectionFolderIDs: Set<UUID> = []

    // Navigation (LEGACY - transitioning to NavigationStore)
    var navigationState: NavigationState {
        get { navigationStore.navigationState }
        set { navigationStore.navigationState = newValue }
    }
    var pendingExplorerFocus: ExplorerFocus? {
        get { navigationStore.pendingExplorerFocus }
        set { navigationStore.pendingExplorerFocus = newValue }
    }
    var isWorkspaceWindowKey: Bool {
        get { navigationStore.isWorkspaceWindowKey }
        set { navigationStore.isWorkspaceWindowKey = newValue }
    }
    var isManageConnectionsPresented: Bool {
        get { navigationStore.isManageConnectionsPresented }
        set { navigationStore.isManageConnectionsPresented = newValue }
    }
    var showNewProjectSheet: Bool {
        get { navigationStore.showNewProjectSheet }
        set { navigationStore.showNewProjectSheet = newValue }
    }
    var showManageProjectsSheet: Bool {
        get { navigationStore.showManageProjectsSheet }
        set { navigationStore.showManageProjectsSheet = newValue }
    }

    // Tabs (LEGACY - transitioning to TabStore)
    var tabManager: TabManager {
        get { tabStore.tabManager }
        set { tabStore.tabManager = newValue }
    }

    // Connection management (LEGACY - transitioning to ConnectionStore)
    var connections: [SavedConnection] { 
        get { connectionStore.connections }
        set { 
            Task { @MainActor in
                try? await connectionStore.saveConnections() 
            }
        }
    }
    var folders: [SavedFolder] { 
        get { connectionStore.folders }
        set {
            Task { @MainActor in
                try? await connectionStore.saveFolders()
            }
        }
    }
    var identities: [SavedIdentity] { 
        get { connectionStore.identities }
        set {
            Task { @MainActor in
                try? await connectionStore.saveIdentities()
            }
        }
    }
    var selectedConnectionID: UUID? {
        get { connectionStore.selectedConnectionID }
        set { connectionStore.selectedConnectionID = newValue }
    }
    var selectedFolderID: UUID? {
        get { connectionStore.selectedFolderID }
        set { connectionStore.selectedFolderID = newValue }
    }
    var selectedIdentityID: UUID? {
        get { connectionStore.selectedIdentityID }
        set { connectionStore.selectedIdentityID = newValue }
    }

    // Project management (LEGACY - transitioning to ProjectStore)
    var projects: [Project] { 
        get { projectStore.projects }
        set {
            Task { @MainActor in
                try? await projectStore.saveProjects(newValue)
            }
        }
    }
    var selectedProject: Project? { 
        get { projectStore.selectedProject }
        set { projectStore.selectedProject = newValue }
    }
    var globalSettings: GlobalSettings { 
        get { projectStore.globalSettings }
        set { 
            Task { @MainActor in
                try? await projectStore.updateGlobalSettings(newValue)
            }
        }
    }

    @Published var lastError: DatabaseError?
    @Published var inspectorWidth: CGFloat = 360

    // MARK: - Dependencies
    let projectStore: ProjectStore
    let connectionStore: ConnectionStore
    let navigationStore: NavigationStore
    let tabStore: TabStore
    let resultSpoolCoordinator: ResultSpoolCoordinator
    let diagramCoordinator: DiagramCoordinator
    let identityRepository: IdentityRepository
    let schemaDiscoveryCoordinator: SchemaDiscoveryCoordinator
    let bookmarkRepository: BookmarkRepository
    let historyRepository: HistoryRepository
    private let clipboardHistory: ClipboardHistoryStore
    let resultSpoolManager: ResultSpoolManager
    let diagramCacheManager: DiagramCacheManager
    let diagramKeyStore: DiagramEncryptionKeyStore
    private let diagramPrefetchService = DiagramPrefetchService()
    private var diagramRefreshTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private var sessionDatabaseCancellables: [UUID: AnyCancellable] = [:]
    private let defaultInspectorWidth: CGFloat = 360
    private static let expandedConnectionFoldersKey = "expandedConnectionFoldersByProject"

    private func makeDatabaseFactory(for type: DatabaseType) -> DatabaseFactory? {
        DatabaseFactoryProvider.makeFactory(for: type)
    }

  private func makeStructureFetcher(for connectionSession: ConnectionSession) -> DatabaseStructureFetcher? {
      let session = connectionSession.session

      switch connectionSession.connection.databaseType {
      case .postgresql:
          // Create a PostgreSQL structure fetcher using the existing session
          return PostgresStructureFetcher(session: session)
      case .microsoftSQL:
          // Create a SQL Server structure fetcher using the existing session
          return MSSQLStructureFetcher(session: session)
      case .mysql:
          // MySQL structure fetching would need its own implementation
          return nil
      case .sqlite:
          // SQLite structure fetching would need its own implementation
          return nil
      }
  }

  private func loadExpandedConnectionFolders(for projectID: UUID?) {

        let storage = UserDefaults.standard.dictionary(forKey: Self.expandedConnectionFoldersKey) as? [String: [String]] ?? [:]
        let key = projectID?.uuidString ?? "global"
        let ids = storage[key]?.compactMap(UUID.init) ?? []
        expandedConnectionFolderIDs = Set(ids)
    }

    func updateExpandedConnectionFolders(_ ids: Set<UUID>) {
        guard expandedConnectionFolderIDs != ids else { return }
        expandedConnectionFolderIDs = ids
        persistExpandedConnectionFolders(ids: ids, projectID: selectedProject?.id)
    }

    private func persistExpandedConnectionFolders(ids: Set<UUID>, projectID: UUID?) {
        let key = projectID?.uuidString ?? "global"
        var storage = UserDefaults.standard.dictionary(forKey: Self.expandedConnectionFoldersKey) as? [String: [String]] ?? [:]
        storage[key] = ids.map { $0.uuidString }
        UserDefaults.standard.set(storage, forKey: Self.expandedConnectionFoldersKey)
    }

    private func applyResultSpoolConfiguration(for settings: GlobalSettings) async {
        await resultSpoolCoordinator.updateConfiguration(with: settings)
    }

    private func applyDiagramCacheConfiguration(for settings: GlobalSettings) async {
        await diagramCoordinator.updateConfiguration(with: settings)
    }
    
    private func restartDiagramRefreshTask() {
        diagramRefreshTask?.cancel()
        diagramRefreshTask = nil
        guard globalSettings.diagramPrefetchMode == .full else { return }
        let cadence = globalSettings.diagramRefreshCadence
        guard cadence != .never else { return }
        let intervalSeconds: TimeInterval
        switch cadence {
        case .never:
            return
        case .daily:
            intervalSeconds = 24 * 60 * 60
        case .weekly:
            intervalSeconds = 7 * 24 * 60 * 60
        }
        let intervalNanoseconds = UInt64(intervalSeconds) * 1_000_000_000
        diagramRefreshTask = Task.detached(priority: .utility) { [weak self] in
            await self?.runDiagramRefreshLoop(intervalNanoseconds: intervalNanoseconds)
        }
    }

    @MainActor
    private func runDiagramRefreshSweep() async {
        guard globalSettings.diagramPrefetchMode == .full else { return }
        await enqueueFullPrefetchSweep(isBackground: true)
    }

    @MainActor
    private func runDiagramRefreshLoop(intervalNanoseconds: UInt64) async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: intervalNanoseconds)
            } catch {
                break
            }
            if Task.isCancelled { break }
            await runDiagramRefreshSweep()
        }
    }

    @MainActor
    private func handleDiagramSettingsChange(_ settings: GlobalSettings) async {
        await diagramCoordinator.handleDiagramSettingsChange(settings)
    }

    @MainActor
    private func handlePrefetchRequest(_ request: DiagramPrefetchService.Request) async -> Bool {
        return await diagramCoordinator.handlePrefetchRequest(request)
    }

    @MainActor
    private func scheduleRelatedPrefetch(
        for session: ConnectionSession,
        baseKey: DiagramTableKey,
        relatedKeys: [DiagramTableKey]
    ) async {
        await diagramCoordinator.scheduleRelatedPrefetch(
            session: session,
            baseKey: baseKey,
            relatedKeys: relatedKeys,
            projectID: session.connection.projectID ?? selectedProject?.id ?? UUID()
        )
    }

    @MainActor
    private func enqueueFullPrefetchSweep(isBackground: Bool) async {
        guard globalSettings.diagramPrefetchMode == .full else { return }
        for session in sessionManager.activeSessions {
            await enqueueFullPrefetch(for: session, isBackground: isBackground)
        }
    }

    @MainActor
    private func enqueueFullPrefetch(for session: ConnectionSession, isBackground: Bool) async {
        guard globalSettings.diagramPrefetchMode == .full else { return }
        guard let projectID = session.connection.projectID ?? selectedProject?.id else { return }
        guard let structure = session.databaseStructure else { return }
        let targetDatabase = session.selectedDatabaseName ?? session.connection.database
        for database in structure.databases where database.name.caseInsensitiveCompare(targetDatabase) == .orderedSame {
            for schema in database.schemas {
                for object in schema.tables {
                    let cacheKey = DiagramCacheKey(
                        projectID: projectID,
                        connectionID: session.connection.id,
                        schema: object.schema,
                        table: object.name
                    )
                    let request = DiagramPrefetchService.Request(
                        cacheKey: cacheKey,
                        connectionSessionID: session.id,
                        object: object,
                        isBackgroundSweep: isBackground
                    )
                    await diagramCoordinator.prefetchService.enqueue(request, prioritize: !isBackground)
                }
            }
        }
    }

    @MainActor
    private func enqueuePrefetchForSessionIfNeeded(_ session: ConnectionSession) async {
        guard globalSettings.diagramPrefetchMode == .full else { return }
        await enqueueFullPrefetch(for: session, isBackground: false)
    }

    // MARK: - Computed helpers
    var selectedConnection: SavedConnection? {
        guard let id = selectedConnectionID else { return nil }
        return connections.first { $0.id == id }
    }

    // MARK: - Initialization
    init(
        projectStore: ProjectStore,
        connectionStore: ConnectionStore,
        navigationStore: NavigationStore,
        tabStore: TabStore,
        clipboardHistory: ClipboardHistoryStore,
        resultSpoolCoordinator: ResultSpoolCoordinator,
        diagramCoordinator: DiagramCoordinator,
        identityRepository: IdentityRepository,
        schemaDiscoveryCoordinator: SchemaDiscoveryCoordinator,
        bookmarkRepository: BookmarkRepository,
        historyRepository: HistoryRepository,
        resultSpoolManager: ResultSpoolManager,
        diagramCacheManager: DiagramCacheManager,
        diagramKeyStore: DiagramEncryptionKeyStore
    ) {
        self.projectStore = projectStore
        self.connectionStore = connectionStore
        self.navigationStore = navigationStore
        self.tabStore = tabStore
        self.clipboardHistory = clipboardHistory
        self.resultSpoolCoordinator = resultSpoolCoordinator
        self.diagramCoordinator = diagramCoordinator
        self.identityRepository = identityRepository
        self.schemaDiscoveryCoordinator = schemaDiscoveryCoordinator
        self.bookmarkRepository = bookmarkRepository
        self.historyRepository = historyRepository
        self.resultSpoolManager = resultSpoolManager
        self.diagramCacheManager = diagramCacheManager
        self.diagramKeyStore = diagramKeyStore
        
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
                    Task { await self.enqueuePrefetchForSessionIfNeeded(session) }
                }

                if let activeID = self.sessionManager.activeSessionID,
                   let activeSession = sessions.first(where: { $0.id == activeID }) {
                    self.updateNavigation(for: activeSession)
                } else if self.sessionManager.activeSessionID == nil {
                    self.updateNavigation(for: nil)
                }
            }
            .store(in: &cancellables)

        // Bridge @Observable state changes to AppModel's subscribers
        // This is temporary until the UI uses stores directly.
        _ = withObservationTracking {
            connectionStore.selectedConnectionID
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.objectWillChange.send()
                self.applySelectedConnection(self.selectedConnectionID)
                self.retrackConnectionChanges()
            }
        }

        tabManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        _ = withObservationTracking {
            navigationStore.navigationState
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.objectWillChange.send()
                self?.retrackNavigationChanges()
            }
        }

        loadRecentConnections()

        // Bridge @Observable state changes to AppModel's subscribers
        // This is temporary until the UI uses ProjectStore directly.
        _ = withObservationTracking {
            projectStore.selectedProject
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.objectWillChange.send()
                self.loadExpandedConnectionFolders(for: self.selectedProject?.id)
                self.retrackProjectChanges()
            }
        }

        _ = withObservationTracking {
            projectStore.globalSettings
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.objectWillChange.send()
                await self.applyResultSpoolConfiguration(for: self.globalSettings)
                await self.applyDiagramCacheConfiguration(for: self.globalSettings)
                await self.handleDiagramSettingsChange(self.globalSettings)
                self.retrackProjectChanges()
            }
        }
    }

    private func retrackNavigationChanges() {
        _ = withObservationTracking {
            navigationStore.navigationState
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.objectWillChange.send()
                self?.retrackNavigationChanges()
            }
        }
    }

    private func retrackConnectionChanges() {
        _ = withObservationTracking {
            connectionStore.selectedConnectionID
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.objectWillChange.send()
                self.applySelectedConnection(self.selectedConnectionID)
                self.retrackConnectionChanges()
            }
        }
    }

    private func retrackProjectChanges() {
        _ = withObservationTracking {
            projectStore.selectedProject
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.objectWillChange.send()
                self?.loadExpandedConnectionFolders(for: self?.selectedProject?.id)
                self?.retrackProjectChanges()
            }
        }
        
        _ = withObservationTracking {
            projectStore.globalSettings
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.objectWillChange.send()
                await self.applyResultSpoolConfiguration(for: self.globalSettings)
                await self.applyDiagramCacheConfiguration(for: self.globalSettings)
                await self.handleDiagramSettingsChange(self.globalSettings)
                self.retrackProjectChanges()
            }
        }
    }

    // MARK: - Persistence
    func load() async {
        do {
            inspectorWidth = CGFloat(globalSettings.inspectorWidth ?? Double(defaultInspectorWidth))

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

            await ensureActiveThemesApplied()
            synchronizeRecentConnectionsWithConnections()
            loadExpandedConnectionFolders(for: selectedProject?.id)
        } catch {
            print("Failed to load data: \(error)")
        }
    }

    @MainActor
    func updateInspectorWidth(_ width: CGFloat, min: CGFloat, max: CGFloat) {
        let clamped = Swift.max(min, Swift.min(max, width))
        guard abs(inspectorWidth - clamped) > 0.5 else {
            inspectorWidth = clamped
            return
        }
        inspectorWidth = clamped
        Task {
            await updateGlobalEditorDisplay { settings in
                settings.inspectorWidth = Double(clamped)
            }
        }
    }

    func ensureDefaultProjectExists(assignNavigation: Bool = true) async {
        var didCreateDefault = false

        if projectStore.projects.isEmpty {
            _ = try? await projectStore.createProject(name: "Default Project")
            didCreateDefault = true
        }

        if projectStore.selectedProject == nil || didCreateDefault {
            projectStore.selectProject(projectStore.projects.first(where: { $0.isDefault }) ?? projectStore.projects.first)
        }

        if assignNavigation {
            if navigationState.selectedProject == nil || didCreateDefault,
               let project = projectStore.selectedProject {
                navigationState.selectProject(project)
            }
        }
    }

    private func normalizeEditorPreferences() async {
        var didMutateProjects = false
        var didMutateGlobalSettings = false

        if UserDefaults.standard.object(forKey: "useServerColorAsAccent") != nil {
            let storedAccent = UserDefaults.standard.bool(forKey: "useServerColorAsAccent")
            if globalSettings.useServerColorAsAccent != storedAccent {
                globalSettings.useServerColorAsAccent = storedAccent
                didMutateGlobalSettings = true
            }
            UserDefaults.standard.removeObject(forKey: "useServerColorAsAccent")
        }

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
                try await projectStore.saveProjects(projects)
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
        let formattingEnabled = globalSettings.resultsEnableTypeFormatting
        let formattingMode = globalSettings.resultsFormattingMode
        for tab in tabManager.tabs {
            tab.query?.updateResultsFormattingSettings(enabled: formattingEnabled, mode: formattingMode)
        }
        await persistGlobalSettings()
    }

    func updateResultsStreaming(
        initialRowLimit: Int? = nil,
        previewBatchSize: Int? = nil,
        backgroundStreamingThreshold: Int? = nil,
        backgroundFetchSize: Int? = nil,
        backgroundFetchRampMultiplier: Int? = nil,
        backgroundFetchRampMax: Int? = nil,
        useCursorStreaming: Bool? = nil,
        cursorLimitThreshold: Int? = nil,
        streamingMode: ResultStreamingExecutionMode? = nil
    ) async {
        let clampedInitial = initialRowLimit.map { max(100, $0) }
        let clampedPreview = previewBatchSize.map { max(100, $0) }
        let clampedBackground = backgroundStreamingThreshold.map { max(100, $0) }
        let clampedFetch = backgroundFetchSize.map { max(128, min($0, 16_384)) }
        let clampedRampMultiplier = backgroundFetchRampMultiplier.map { max(1, min($0, 64)) }
        let clampedRampMax = backgroundFetchRampMax.map { max(256, min($0, 1_048_576)) }
        let clampedCursorThreshold = cursorLimitThreshold.map { max(0, min($0, 1_000_000)) }
        let shouldUpdate = [clampedInitial, clampedPreview, clampedBackground, clampedFetch, clampedRampMultiplier, clampedRampMax, clampedCursorThreshold].contains { $0 != nil } || useCursorStreaming != nil || streamingMode != nil
        guard shouldUpdate else { return }

        await updateGlobalEditorDisplay { settings in
            if let value = clampedInitial {
                settings.resultsInitialRowLimit = value
            }
            if let value = clampedPreview {
                settings.resultsPreviewBatchSize = value
            }
            if let value = clampedBackground {
                settings.resultsBackgroundStreamingThreshold = value
            }
            if let value = clampedFetch {
                settings.resultsStreamingFetchSize = value
            }
            if let value = clampedRampMultiplier {
                settings.resultsStreamingFetchRampMultiplier = value
            }
            if let value = clampedRampMax {
                settings.resultsStreamingFetchRampMax = value
            }
            if let cursor = useCursorStreaming {
                settings.resultsUseCursorStreaming = cursor
            }
            if let value = clampedCursorThreshold {
                settings.resultsCursorStreamingLimitThreshold = value
            }
            if let mode = streamingMode {
                settings.resultsStreamingMode = mode
            }
        }

        if let value = clampedInitial {
            for session in sessionManager.activeSessions {
                session.updateDefaultInitialBatchSize(value)
            }
        }
        if let value = clampedBackground {
            for session in sessionManager.activeSessions {
                session.updateDefaultBackgroundStreamingThreshold(value)
            }
        }
        if let value = clampedFetch {
            UserDefaults.standard.set(value, forKey: ResultStreamingFetchSizeDefaultsKey)
            for session in sessionManager.activeSessions {
                session.updateDefaultBackgroundFetchSize(value)
            }
        }
        if let value = clampedRampMultiplier {
            UserDefaults.standard.set(value, forKey: ResultStreamingFetchRampMultiplierDefaultsKey)
        }
        if let value = clampedRampMax {
            UserDefaults.standard.set(value, forKey: ResultStreamingFetchRampMaxDefaultsKey)
        }
        if let cursor = useCursorStreaming {
            UserDefaults.standard.set(cursor, forKey: ResultStreamingUseCursorDefaultsKey)
        }
        if let value = clampedCursorThreshold {
            UserDefaults.standard.set(value, forKey: ResultStreamingCursorLimitThresholdDefaultsKey)
        }
        if let mode = streamingMode {
            UserDefaults.standard.set(mode.rawValue, forKey: ResultStreamingModeDefaultsKey)
        }
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
                try await projectStore.saveProjects(projects)
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
        // Themes are now simplified, we don't need manual chrome application here
    }

    private func ensureActiveThemesApplied() async {
        ThemeManager.shared.applyAppearanceMode(globalSettings.appearanceMode)
    }

    private func activeTheme(for tone: SQLEditorPalette.Tone) -> AppColorTheme {
        if let theme = globalSettings.theme(withID: globalSettings.activeThemeID(for: tone), tone: tone) {
            return theme
        }
        return AppColorTheme.builtInThemes(for: tone).first
            ?? AppColorTheme.fromPalette(tone == .dark ? SQLEditorPalette.midnight : SQLEditorPalette.aurora)
    }

    func upsertConnection(_ connection: SavedConnection, password: String?) async {
        var updated = connection
        let existing = connections.first(where: { $0.id == updated.id })

        switch updated.credentialSource {
        case .manual:
            if let password, !password.isEmpty {
                try? identityRepository.setPassword(password, for: &updated)
            } else if updated.keychainIdentifier == nil, let existingIdentifier = existing?.keychainIdentifier {
                updated.keychainIdentifier = existingIdentifier
            }
            updated.identityID = nil
        case .identity:
            updated.keychainIdentifier = nil
            if existing?.credentialSource == .manual {
                identityRepository.deletePassword(for: updated)
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
            if existing?.credentialSource == .manual {
                identityRepository.deletePassword(for: updated)
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
                      bookmarkContext: WorkspaceTab.BookmarkTabContext? = nil,
                      autoExecute: Bool = false) {
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

        let initialBatch = max(100, globalSettings.resultsInitialRowLimit)
        let previewLimit = max(globalSettings.resultsBackgroundStreamingThreshold, initialBatch)
        let queryState = QueryEditorState(
            sql: presetQuery.isEmpty ? "SELECT current_timestamp;" : presetQuery,
            initialVisibleRowBatch: initialBatch,
            previewRowLimit: previewLimit,
            spoolManager: resultSpoolManager,
            backgroundFetchSize: globalSettings.resultsStreamingFetchSize
        )
        queryState.updateResultsFormattingSettings(
            enabled: globalSettings.resultsEnableTypeFormatting,
            mode: globalSettings.resultsFormattingMode
        )
        queryState.shouldAutoExecuteOnAppear = autoExecute

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

    @MainActor
    func openDataPreviewTab(
        for session: ConnectionSession,
        object: SchemaObjectInfo,
        sqlBuilder: @Sendable @escaping (_ limit: Int, _ offset: Int) -> String,
        initialBatchSize: Int? = nil
    ) {
        sessionManager.setActiveSession(session.id)
        selectedConnectionID = session.connection.id

        let configuredBatchSize = max(100, initialBatchSize ?? globalSettings.resultsPreviewBatchSize)
        let initialSQL = sqlBuilder(configuredBatchSize, 0)

        func normalized(_ value: String) -> String? {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        let previewLimit = max(globalSettings.resultsBackgroundStreamingThreshold, configuredBatchSize)
        let queryState = QueryEditorState(
            sql: initialSQL,
            initialVisibleRowBatch: configuredBatchSize,
            previewRowLimit: previewLimit,
            spoolManager: resultSpoolManager,
            backgroundFetchSize: globalSettings.resultsStreamingFetchSize
        )
        queryState.updateResultsFormattingSettings(
            enabled: globalSettings.resultsEnableTypeFormatting,
            mode: globalSettings.resultsFormattingMode
        )
        queryState.isResultsOnly = true
        queryState.shouldAutoExecuteOnAppear = true
        let databaseSession = session.session
        queryState.configureDataPreview(batchSize: configuredBatchSize) { offset, limit in
            let sql = sqlBuilder(limit, offset)
            return try await databaseSession.simpleQuery(sql)
        }

        let serverName = normalized(session.connection.connectionName) ?? normalized(session.connection.host)
        let databaseName = normalized(session.selectedDatabaseName ?? session.connection.database)

        queryState.updateClipboardContext(
            serverName: serverName,
            databaseName: databaseName,
            connectionColorHex: session.connection.metadataColorHex
        )
        queryState.updateClipboardObjectName(object.fullName)

        let title = "\(object.name) Data"

        let newTab = WorkspaceTab(
            connection: session.connection,
            session: session.session,
            connectionSessionID: session.id,
            title: title,
            content: .query(queryState)
        )

        tabManager.addTab(newTab)
        tabManager.activeTabId = newTab.id
    }

    @MainActor
    func openDiagramTab(
        for session: ConnectionSession,
        object: SchemaObjectInfo
    ) {
        sessionManager.setActiveSession(session.id)
        selectedConnectionID = session.connection.id

        let baseIdentifier = "\(object.schema).\(object.name)"
        let projectID = session.connection.projectID ?? selectedProject?.id
        let cacheKey = projectID.map {
            DiagramCacheKey(
                projectID: $0,
                connectionID: session.connection.id,
                schema: object.schema,
                table: object.name
            )
        }

        Task {
            let placeholderViewModel = await MainActor.run { () -> SchemaDiagramViewModel in
                let viewModel = SchemaDiagramViewModel(
                    nodes: [],
                    edges: [],
                    baseNodeID: baseIdentifier,
                    title: "\(object.schema).\(object.name)",
                    isLoading: true,
                    statusMessage: "Loading \(baseIdentifier)…",
                    errorMessage: nil,
                    context: SchemaDiagramContext(
                        projectID: projectID,
                        connectionID: session.connection.id,
                        connectionSessionID: session.id,
                        object: object,
                        cacheKey: cacheKey
                    )
                )

                let newTab = WorkspaceTab(
                    connection: session.connection,
                    session: session.session,
                    connectionSessionID: session.id,
                    title: "\(object.name) Diagram",
                    content: .diagram(viewModel)
                )
                tabManager.addTab(newTab)
                tabManager.activeTabId = newTab.id

                let placeholderColumn = SchemaDiagramColumn(
                    name: "Loading…",
                    dataType: "",
                    isPrimaryKey: false,
                    isForeignKey: false
                )
                let placeholderNode = SchemaDiagramNodeModel(
                    schema: object.schema,
                    name: object.name,
                    columns: [placeholderColumn],
                    position: .zero
                )
                viewModel.nodes = [placeholderNode]

                return viewModel
            }

            if let cacheKey,
               let cachedPayload = try? await diagramCacheManager.payload(for: cacheKey) {
                let cachedModel = diagramCoordinator.hydrateCachedDiagram(from: cachedPayload)
                await MainActor.run {
                    placeholderViewModel.nodes = cachedModel.nodes
                    placeholderViewModel.edges = cachedModel.edges
                    placeholderViewModel.layoutIdentifier = cachedModel.layoutIdentifier
                    placeholderViewModel.cachedStructure = cachedModel.cachedStructure
                    placeholderViewModel.cachedChecksum = cachedModel.cachedChecksum
                    placeholderViewModel.loadSource = cachedModel.loadSource
                    placeholderViewModel.isLoading = false
                    placeholderViewModel.statusMessage = nil
                    placeholderViewModel.errorMessage = nil
                }

                if !globalSettings.diagramVerifyBeforeRefresh {
                    return
                }
            }

            do {
                let diagramModel = try await diagramCoordinator.buildSchemaDiagram(
                    for: object,
                    session: session,
                    projectID: projectID ?? UUID(),
                    cacheKey: cacheKey,
                    progress: { msg in
                        Task { @MainActor in placeholderViewModel.statusMessage = msg }
                    }
                )
                await MainActor.run {
                    placeholderViewModel.nodes = diagramModel.nodes
                    placeholderViewModel.edges = diagramModel.edges
                    placeholderViewModel.isLoading = false
                    placeholderViewModel.statusMessage = nil
                    placeholderViewModel.errorMessage = nil
                    placeholderViewModel.layoutIdentifier = diagramModel.layoutIdentifier
                    placeholderViewModel.cachedStructure = diagramModel.cachedStructure
                    placeholderViewModel.cachedChecksum = diagramModel.cachedChecksum
                    placeholderViewModel.loadSource = diagramModel.loadSource
                }
            } catch {
                let databaseError = DatabaseError.from(error)
                await MainActor.run {
                    placeholderViewModel.isLoading = false
                    placeholderViewModel.statusMessage = nil
                    placeholderViewModel.errorMessage = databaseError.localizedDescription
                    self.lastError = databaseError
                }
            }
        }
    }

    // MARK: - Job Management Tab

    @MainActor
    func openJobManagementTab(for session: ConnectionSession? = nil, selectJobID: String? = nil) {
        guard let targetSession = session ?? sessionManager.activeSession ?? sessionManager.activeSessions.first else { return }
        sessionManager.setActiveSession(targetSession.id)
        selectedConnectionID = targetSession.connection.id

        let titleBase = "Jobs"
        let existingCount = tabManager.tabs.filter { $0.connection.id == targetSession.connection.id && $0.kind == .jobManagement }.count
        let title = existingCount == 0 ? titleBase : "\(titleBase) #\(existingCount + 1)"

        let viewModel = JobManagementViewModel(session: targetSession.session, connection: targetSession.connection, initialSelectedJobID: selectJobID)
        let newTab = WorkspaceTab(
            connection: targetSession.connection,
            session: targetSession.session,
            connectionSessionID: targetSession.id,
            title: title,
            content: .jobManagement(viewModel)
        )
        tabManager.addTab(newTab)
        tabManager.activeTabId = newTab.id
    }

    func closeActiveQueryTab() {
        guard let activeTab = tabManager.activeTab else { return }
        tabManager.closeTab(id: activeTab.id)
    }

    func refreshDiagram(_ viewModel: SchemaDiagramViewModel) async {
        guard let context = viewModel.context else { return }
        guard let session = sessionManager.activeSessions.first(where: { $0.id == context.connectionSessionID }) else { return }
        let projectID = session.connection.projectID ?? selectedProject?.id
        let cacheKey = context.cacheKey ?? projectID.map {
            DiagramCacheKey(
                projectID: $0,
                connectionID: session.connection.id,
                schema: context.object.schema,
                table: context.object.name
            )
        }

        await MainActor.run {
            viewModel.isLoading = true
            viewModel.statusMessage = "Refreshing diagram…"
            viewModel.errorMessage = nil
        }

        do {
            let projectID = session.connection.projectID ?? selectedProject?.id ?? UUID()
            let diagramModel = try await diagramCoordinator.buildSchemaDiagram(
                for: context.object,
                session: session,
                projectID: projectID,
                cacheKey: cacheKey,
                progress: { status in
                    Task { @MainActor in
                        viewModel.statusMessage = status
                    }
                }
            )
            await MainActor.run {
                viewModel.nodes = diagramModel.nodes
                viewModel.edges = diagramModel.edges
                viewModel.layoutIdentifier = diagramModel.layoutIdentifier
                viewModel.cachedStructure = diagramModel.cachedStructure
                viewModel.cachedChecksum = diagramModel.cachedChecksum
                viewModel.loadSource = diagramModel.loadSource
                viewModel.isLoading = false
                viewModel.statusMessage = nil
                viewModel.errorMessage = nil
            }
        } catch {
            let databaseError = DatabaseError.from(error)
            await MainActor.run {
                viewModel.isLoading = false
                viewModel.statusMessage = nil
                viewModel.errorMessage = databaseError.localizedDescription
                self.lastError = databaseError
            }
        }
    }

    @MainActor
    func persistDiagramLayout(_ viewModel: SchemaDiagramViewModel) async {
        guard let context = viewModel.context,
              let cacheKey = context.cacheKey else { return }
        guard let structure = viewModel.cachedStructure,
              let checksum = viewModel.cachedChecksum else { return }
        let payload = DiagramCachePayload(
            key: cacheKey,
            checksum: checksum,
            structure: structure,
            layout: viewModel.layoutSnapshot(),
            loadingSummary: nil
        )
        try? await diagramCacheManager.stashPayload(payload)
        viewModel.loadSource = .cache(Date())
    }

    func duplicateTab(_ tab: WorkspaceTab) {
        guard let queryState = tab.query else { return }
        guard let session = sessionManager.activeSessions.first(where: { $0.id == tab.connectionSessionID }) else { return }

        sessionManager.setActiveSession(session.id)

        let initialBatch = max(100, globalSettings.resultsInitialRowLimit)
        let previewLimit = max(globalSettings.resultsBackgroundStreamingThreshold, initialBatch)
        let duplicateState = QueryEditorState(
            sql: queryState.sql,
            initialVisibleRowBatch: initialBatch,
            previewRowLimit: previewLimit,
            spoolManager: resultSpoolManager,
            backgroundFetchSize: globalSettings.resultsStreamingFetchSize
        )
        duplicateState.updateResultsFormattingSettings(
            enabled: globalSettings.resultsEnableTypeFormatting,
            mode: globalSettings.resultsFormattingMode
        )
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
        identityRepository.deletePassword(for: connection)
        connections.removeAll { $0.id == connection.id }
        connectionStates.removeValue(forKey: connection.id)

        if let session = sessionManager.sessionForConnection(connection.id) {
            await session.cancelStructureLoadTask()
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
            try await connectionStore.saveConnections()
        } catch {
            print("Failed to persist connections: \(error)")
        }
    }

    private func persistFolders() async {
        do {
            try await connectionStore.saveFolders()
        } catch {
            print("Failed to persist folders: \(error)")
        }
    }

    private func persistIdentities() async {
        do {
            try await connectionStore.saveIdentities()
        } catch {
            print("Failed to persist identities: \(error)")
        }
    }

    func upsertIdentity(_ identity: SavedIdentity, password: String?) async {
        var updated = identity

        if let password, !password.isEmpty {
            try? identityRepository.setPassword(password, for: &updated)
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
        identityRepository.deletePassword(for: identity)

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

            if let password = trimmedManualPassword {
                try? identityRepository.setPassword(password, for: &updated)
            } else if existing?.credentialMode != .manual || existing?.manualKeychainIdentifier == nil {
                // No password available to persist
                identityRepository.deletePassword(for: updated)
                updated.manualUsername = nil
                updated.manualKeychainIdentifier = nil
                updated.credentialMode = .none
            }

        default:
            updated.manualUsername = nil
            identityRepository.deletePassword(for: updated)
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
            if let folderToDelete = self.folder(withID: folderID) {
                identityRepository.deletePassword(for: folderToDelete)
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
        if connection.credentialSource == .manual {
            password = identityRepository.password(for: connection)
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

    private func resolvedCredentials(for connection: SavedConnection, overridePassword: String? = nil) -> DatabaseAuthenticationConfiguration? {
        identityRepository.resolveAuthenticationConfiguration(for: connection, overridePassword: overridePassword)
    }

    func folderIdentity(for folderID: UUID) -> SavedIdentity? {
        guard let connectionStore = (self.connectionStore as Any) as? ConnectionStore else { return nil }
        // For now, let's keep it simple and reach into the repository or store
        // Actually, let's just bridge it to a new repository method for consistency
        return identityRepository.resolveInheritedIdentity(folderID: folderID)
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
                await existing.cancelStructureLoadTask()
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
                session: databaseSession,
                defaultInitialBatchSize: globalSettings.resultsInitialRowLimit,
                defaultBackgroundStreamingThreshold: globalSettings.resultsBackgroundStreamingThreshold,
                defaultBackgroundFetchSize: globalSettings.resultsStreamingFetchSize,
                spoolManager: resultSpoolManager
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

            startStructureLoadTask(for: session)
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
            await session.cancelStructureLoadTask()
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
        await session.cancelStructureLoadTask()
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
    @MainActor
    private func startStructureLoadTask(for session: ConnectionSession) {
        schemaDiscoveryCoordinator.startStructureLoadTask(for: session)
    }

    func loadDatabaseStructureForSession(_ connectionSession: ConnectionSession) async throws -> DatabaseStructure {
        try await schemaDiscoveryCoordinator.loadDatabaseStructureForSession(connectionSession)
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
        await schemaDiscoveryCoordinator.refreshStructure(for: session, scope: scope)
    }

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

        if let diagramCaches = exportData.diagramCaches {
            for payload in diagramCaches {
                guard let newConnectionID = connectionIDMap[payload.key.connectionID] else { continue }
                let newKey = DiagramCacheKey(
                    projectID: importedProject.id,
                    connectionID: newConnectionID,
                    schema: payload.key.schema,
                    table: payload.key.table,
                    layoutID: payload.key.layoutID
                )
                let updatedPayload = DiagramCachePayload(
                    key: newKey,
                    checksum: payload.checksum,
                    generatedAt: payload.generatedAt,
                    structure: payload.structure,
                    layout: payload.layout,
                    loadingSummary: payload.loadingSummary
                )
                try? await diagramCacheManager.stashPayload(updatedPayload)
            }
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
        try await projectStore.saveProjects(projects)
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
        projectStore.selectProject(importedProject)
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
        guard let project = projects.first(where: { $0.id == connectionProjectID(connectionID) }) ?? selectedProject else { return [] }
        return bookmarkRepository.bookmarks(for: connectionID, in: project)
    }

    func bookmarks(in projectID: UUID?) -> [Bookmark] {
        let targetID = projectID ?? selectedProject?.id
        guard let id = targetID, let project = projects.first(where: { $0.id == id }) ?? (selectedProject?.id == id ? selectedProject : nil) else { return [] }
        return project.bookmarks.sorted { $0.updatedAt > $1.updatedAt }
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
        guard var project = projects.first(where: { $0.id == (connection.projectID ?? selectedProject?.id) }) else { return }

        let bookmark = Bookmark(
            connectionID: connection.id,
            databaseName: normalizedDatabaseName(databaseName),
            title: normalizedTitle(title),
            query: normalizedQuery,
            source: source
        )

        bookmarkRepository.addBookmark(bookmark, &project)
        await projectStore.saveProject(project)
    }

    func removeBookmark(_ bookmark: Bookmark) async {
        guard var project = projects.first(where: { $0.id == (connectionProjectID(bookmark.connectionID) ?? selectedProject?.id) }) else { return }
        bookmarkRepository.removeBookmark(bookmark.id, from: &project)
        await projectStore.saveProject(project)
    }

    func renameBookmark(_ bookmark: Bookmark, to title: String?) async {
        guard var project = projects.first(where: { $0.id == (connectionProjectID(bookmark.connectionID) ?? selectedProject?.id) }) else { return }
        bookmarkRepository.updateBookmark(bookmark.id, in: &project) { b in
            b.title = normalizedTitle(title)
            b.updatedAt = Date()
        }
        await projectStore.saveProject(project)
    }

    func updateBookmarkQuery(_ bookmarkID: UUID, newQuery: String) async {
        guard let projectID = projectIDContainingBookmark(bookmarkID),
              var project = projects.first(where: { $0.id == projectID }) else { return }
        bookmarkRepository.updateBookmark(bookmarkID, in: &project) { b in
            b.query = newQuery
            b.updatedAt = Date()
        }
        await projectStore.saveProject(project)
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

    private func projectContainingConnection(_ connectionID: UUID) -> Project? {
        let id = connectionProjectID(connectionID) ?? selectedProject?.id
        return projects.first(where: { $0.id == id })
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
        if let project = projects.first(where: { $0.bookmarks.contains(where: { $0.id == bookmarkID }) }) {
            return project.id
        }
        return selectedProject?.bookmarks.contains(where: { $0.id == bookmarkID }) == true ? selectedProject?.id : nil
    }

    private func connectionProjectID(_ connectionID: UUID) -> UUID? {
        connections.first(where: { $0.id == connectionID })?.projectID
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
        recentConnections = historyRepository.loadRecentConnections()
    }

    private func saveRecentConnections() {
        historyRepository.saveRecentConnections(recentConnections)
    }

    private func recordRecentConnection(for connection: SavedConnection, databaseName: String?) {
        var normalizedDatabase = databaseName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedDatabase?.isEmpty == true { normalizedDatabase = nil }

        let record = RecentConnectionRecord(
            id: connection.id,
            connectionName: connection.connectionName,
            host: connection.host,
            databaseName: normalizedDatabase,
            databaseType: connection.databaseType,
            colorHex: connection.metadataColorHex,
            lastUsedAt: Date()
        )

        recentConnections.removeAll { $0.id == record.id }
        recentConnections.insert(record, at: 0)
        recentConnections = Array(recentConnections.prefix(20))
        saveRecentConnections()
    }

    private func removeRecentConnections(for connectionID: UUID) {
        recentConnections.removeAll { $0.id == connectionID }
        saveRecentConnections()
    }

    private func synchronizeRecentConnectionsWithConnections() {
        let existingIDs = Set(connections.map { $0.id })
        recentConnections.removeAll { !existingIDs.contains($0.id) }
        saveRecentConnections()
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
