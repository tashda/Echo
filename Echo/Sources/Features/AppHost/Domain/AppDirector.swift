//
//  AppDirector.swift
//  Echo
//
//  Created by Assistant on 23/09/2025.
//

import Foundation
import SwiftUI
import Observation
#if os(macOS)
import AppKit
#endif

/// Central director that manages the app's main dependencies and initialization
@Observable @MainActor
final class AppDirector {

    // MARK: - Singleton
    static let shared = AppDirector()

    // MARK: - Dependencies
    @ObservationIgnored let projectStore: ProjectStore
    @ObservationIgnored let connectionStore: ConnectionStore
    @ObservationIgnored let navigationStore: NavigationStore
    @ObservationIgnored let tabStore: TabStore
    @ObservationIgnored let resultSpoolConfigCoordinator: ResultSpoolConfig
    @ObservationIgnored let diagramBuilder: DiagramBuilder
    @ObservationIgnored let identityRepository: IdentityRepository
    @ObservationIgnored let schemaDiscoveryEngine: MetadataDiscoveryEngine
    @ObservationIgnored let bookmarkRepository: BookmarkRepository
    @ObservationIgnored let historyRepository: HistoryRepository
    @ObservationIgnored let environmentState: EnvironmentState
    @ObservationIgnored let appState: AppState
    @ObservationIgnored let clipboardHistory: ClipboardHistoryStore
    @ObservationIgnored let appearanceStore: AppearanceStore
    @ObservationIgnored let notificationEngine: NotificationEngine
    @ObservationIgnored let resultSpoolManager: ResultSpooler
    @ObservationIgnored let diagramCacheStore: DiagramCacheStore
    @ObservationIgnored let diagramKeyStore: DiagramEncryptionKeyStore
    @ObservationIgnored let activityEngine: ActivityEngine
    @ObservationIgnored let authState: AuthState
    @ObservationIgnored let syncEngine: SyncEngine?
    @ObservationIgnored let e2eKeyStore = E2EKeyStore()
    @ObservationIgnored let e2eEnrollmentManager: E2EEnrollmentManager
    @ObservationIgnored private var syncScheduler: SyncScheduler?
    @ObservationIgnored private var syncRealtimeListener: SyncRealtimeListener?
#if os(macOS)
    @ObservationIgnored private nonisolated(unsafe) var windowFocusObservers: [NSObjectProtocol] = []
#endif

    // MARK: - Initialization State
    private(set) var isInitialized = false

    // MARK: - Private Init (Singleton)
    private init() {
        self.appState = AppState()
        let clipboardHistory = ClipboardHistoryStore()
        self.clipboardHistory = clipboardHistory
        let spoolRoot = ResultSpooler.defaultRootDirectory()
        let spoolConfig = ResultSpoolConfiguration.defaultConfiguration(rootDirectory: spoolRoot)
        self.resultSpoolManager = ResultSpooler(configuration: spoolConfig)
        let cacheRoot = DiagramCacheStore.defaultRootDirectory()
        let diagramConfig = DiagramCacheStore.Configuration(rootDirectory: cacheRoot)
        let keyStore = DiagramEncryptionKeyStore()
        let cacheManager = DiagramCacheStore(configuration: diagramConfig)
        self.diagramCacheStore = cacheManager
        self.diagramKeyStore = keyStore

        // Initialize modular stores
        let projectRepository = ProjectRepository(diskStore: ProjectDiskStore())
        self.projectStore = ProjectStore(repository: projectRepository)

        let connectionRepository = ConnectionRepository(
            connectionStore: ConnectionDiskStore(),
            folderStore: FolderDiskStore(),
            identityStore: IdentityDiskStore()
        )
        self.connectionStore = ConnectionStore(repository: connectionRepository)
        self.identityRepository = IdentityRepository(connectionStore: connectionStore)
        self.schemaDiscoveryEngine = MetadataDiscoveryEngine(identityRepository: identityRepository, connectionStore: connectionStore)
        self.bookmarkRepository = BookmarkRepository()
        self.historyRepository = HistoryRepository()

        self.navigationStore = NavigationStore()
        self.tabStore = TabStore()
        self.appearanceStore = AppearanceStore.shared

        // Initialize new domain coordinators
        self.resultSpoolConfigCoordinator = ResultSpoolConfig(spoolManager: resultSpoolManager)
        self.diagramBuilder = DiagramBuilder(cacheManager: cacheManager, keyStore: keyStore)

        self.activityEngine = ActivityEngine()
        self.authState = AuthState(backend: SupabaseAuthBackend() ?? StubAuthBackend())

        // Initialize E2E enrollment manager
        self.e2eEnrollmentManager = E2EEnrollmentManager(keyStore: e2eKeyStore)

        // Initialize sync engine (nil if Supabase is not configured)
        let engine = SyncEngine()
        self.syncEngine = engine
        if let engine {
            engine.connectionStore = connectionStore
            engine.projectStore = projectStore
            engine.e2eKeyStore = e2eKeyStore
            self.syncScheduler = SyncScheduler(syncEngine: engine)

            // Wire store change notifications to sync engine
            connectionStore.onDataChanged = { [weak engine] id, collection, projectID, isDelete in
                if isDelete {
                    engine?.markDeleted(id: id, collection: collection, projectID: projectID)
                } else {
                    engine?.markDirty(id: id, collection: collection, projectID: projectID)
                }
                AppDirector.shared.notifySyncDataChanged()
            }

            // Wire settings changes to sync engine
            projectStore.onSettingsChanged = { [weak engine] projectID in
                let settingsDocID = SyncAdapter().settingsDocumentID(for: projectID)
                engine?.markDirty(id: settingsDocID, collection: .settings, projectID: projectID)
                AppDirector.shared.notifySyncDataChanged()
            }
        }

        self.environmentState = EnvironmentState(
            projectStore: projectStore,
            connectionStore: connectionStore,
            navigationStore: navigationStore,
            tabStore: tabStore,
            clipboardHistory: clipboardHistory,
            resultSpoolConfigCoordinator: resultSpoolConfigCoordinator,
            diagramBuilder: diagramBuilder,
            identityRepository: identityRepository,
            schemaDiscoveryEngine: schemaDiscoveryEngine,
            bookmarkRepository: bookmarkRepository,
            historyRepository: historyRepository,
            resultSpoolManager: resultSpoolManager,
            diagramCacheStore: cacheManager,
            diagramKeyStore: keyStore
        )

        let projectStoreRef = self.projectStore
        self.notificationEngine = NotificationEngine(
            toastPresenter: environmentState.toastPresenter,
            preferencesProvider: { [projectStoreRef] in
                projectStoreRef.globalSettings.notificationPreferences
            }
        )
        environmentState.notificationEngine = notificationEngine

        schemaDiscoveryEngine.onPersistConnections = { @MainActor [weak self] in
            await self?.environmentState.persistConnections()
        }
        schemaDiscoveryEngine.onEnqueuePrefetch = { @MainActor [weak self] session in
            await self?.environmentState.enqueuePrefetchForSessionIfNeeded(session)
        }

        // Setup cross-domain providers for DiagramBuilder after EnvironmentState is initialized
        diagramBuilder.globalSettingsProvider = { @MainActor [weak self] in
            self?.projectStore.globalSettings ?? GlobalSettings()
        }
        diagramBuilder.sessionProvider = { @MainActor [weak self] sessionID in
            guard let self = self else { return nil }
            return self.environmentState.sessionGroup.activeSessions.first { $0.id == sessionID }
        }

        Task {
            await cacheManager.updateKeyProvider { projectID in
                try await MainActor.run {
                    try keyStore.symmetricKey(forProjectID: projectID)
                }
            }
        }

        self.tabStore.delegate = self
        setupBindings()
#if os(macOS)
        observeWindowFocusChanges()
#endif
    }

    // MARK: - Public Methods
    func initialize() async {
        guard !isInitialized else { return }

        // Load foundational stores
        do {
            try await projectStore.load()
            try await connectionStore.load()
        } catch {
            print("Failed to load modular stores: \(error)")
        }

        await environmentState.load()
        await authState.restoreSession()

        // Start sync if signed in
        if authState.isSignedIn {
            await startSync()
        }
        observeAuthState()

        isInitialized = true
        ensureInitialWorkspaceState()
    }

    // MARK: - Theme Binding
    private func setupBindings() {
        observeSelectedProject()
        observeGlobalSettings()
        observeAppearanceChanges()
        observeActiveSessionsForConnections()
    }

    private func observeSelectedProject() {
        _ = withObservationTracking {
            projectStore.selectedProject
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.applyEditorAppearance(project: self.projectStore.selectedProject, global: self.projectStore.globalSettings)
                self.observeSelectedProject()
            }
        }
    }

    private func observeGlobalSettings() {
        _ = withObservationTracking {
            projectStore.globalSettings
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.applyEditorAppearance(project: self.projectStore.selectedProject, global: self.projectStore.globalSettings)
                self.observeGlobalSettings()
            }
        }
    }

    private func observeActiveSessionsForConnections() {
        _ = withObservationTracking {
            environmentState.sessionGroup.activeSessions
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                let sessions = self.environmentState.sessionGroup.activeSessions
                if sessions.isEmpty {
#if !os(macOS)
                    self.presentConnectionsIfNeeded()
#endif
                } else {
                    self.dismissConnectionsIfNeeded()
                }
                self.observeActiveSessionsForConnections()
            }
        }
    }

    private func applyEditorAppearance(project: Project?, global: GlobalSettings) {
        AppearanceStore.shared.applyAppearanceMode(global.appearanceMode)
        appState.sqlEditorDisplay = SQLEditorThemeResolver.resolveDisplayOptions(globalSettings: global, project: project)
        appState.workspaceTabBarStyle = global.workspaceTabBarStyle
        appState.keepTabsInMemory = global.keepTabsInMemory
        applyEditorTheme(project: project, global: global)
    }

    private func applyEditorTheme(project: Project?, global: GlobalSettings) {
        let tone: SQLEditorPalette.Tone = AppearanceStore.shared.effectiveColorScheme == .dark ? .dark : .light
        appState.sqlEditorTheme = SQLEditorThemeResolver.resolve(globalSettings: global, project: project, tone: tone)
    }

    private func observeAppearanceChanges() {
        _ = withObservationTracking {
            AppearanceStore.shared.effectiveColorScheme
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.applyEditorTheme(project: self.projectStore.selectedProject, global: self.projectStore.globalSettings)
                self.observeAppearanceChanges() // Re-track
            }
        }
    }

    private func ensureInitialWorkspaceState() {
        if environmentState.sessionGroup.activeSessions.isEmpty {
#if !os(macOS)
            presentConnectionsIfNeeded()
#endif
        } else if tabStore.tabs.isEmpty {
            environmentState.openQueryTab()
        }
    }

    internal func presentConnectionsIfNeeded() {
        guard !navigationStore.isManageConnectionsPresented else { return }
#if os(macOS)
        ManageConnectionsWindowController.shared.present()
#else
        navigationStore.isManageConnectionsPresented = true
#endif
    }

    internal func dismissConnectionsIfNeeded() {
#if os(macOS)
        if navigationStore.isManageConnectionsPresented {
            ManageConnectionsWindowController.shared.closeWindow()
        }
#else
        navigationStore.isManageConnectionsPresented = false
#endif
    }

#if os(macOS)
    private func observeWindowFocusChanges() {
        let center = NotificationCenter.default

        let keyObserver = center.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateWorkspaceKeyState()
            }
        }

        let resignObserver = center.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateWorkspaceKeyState()
            }
        }

        windowFocusObservers = [keyObserver, resignObserver]

        Task { @MainActor [weak self] in
            self?.updateWorkspaceKeyState()
        }
    }

    private func updateWorkspaceKeyState() {
        guard let keyWindow = NSApplication.shared.keyWindow else {
            navigationStore.isWorkspaceWindowKey = false
            return
        }
        navigationStore.isWorkspaceWindowKey = keyWindow.identifier == AppWindowIdentifier.workspace
    }
#endif

    // MARK: - Sync Lifecycle

    private func startSync() async {
        guard let syncEngine else { return }

        // If the user changed since last sign-in, reset sync state
        let currentUserID = authState.currentUser?.userID
        await syncEngine.resetIfUserChanged(currentUserID: currentUserID)

        // Check E2E enrollment and try auto-unlock
        await e2eEnrollmentManager.checkEnrollmentStatus()
        await e2eEnrollmentManager.tryAutoUnlock()

        await syncEngine.start()
        syncScheduler?.start()

        // Start realtime listener for instant cross-device sync
        let listener = SyncRealtimeListener(syncEngine: syncEngine)
        self.syncRealtimeListener = listener
        await listener.start()
    }

    private func stopSync() async {
        syncScheduler?.stop()
        await syncRealtimeListener?.stop()
        syncRealtimeListener = nil
        e2eEnrollmentManager.clearOnSignOut()
        guard let syncEngine else { return }
        await syncEngine.stop()
    }

    private func observeAuthState() {
        _ = withObservationTracking {
            authState.isSignedIn
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.authState.isSignedIn {
                    await self.startSync()
                } else {
                    await self.stopSync()
                }
                self.observeAuthState()
            }
        }
    }

    /// Notify the sync engine that a local data change occurred.
    /// Called from stores after persisting changes.
    func notifySyncDataChanged() {
        syncScheduler?.scheduleSync()
    }

    deinit {
#if os(macOS)
        windowFocusObservers.forEach { NotificationCenter.default.removeObserver($0) }
#endif
    }
}
