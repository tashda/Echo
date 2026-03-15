//
//  AppCoordinator.swift
//  Echo
//
//  Created by Assistant on 23/09/2025.
//

import Foundation
import SwiftUI
import Combine
#if os(macOS)
import AppKit
#endif

/// Central coordinator that manages the app's main dependencies and initialization
@MainActor
final class AppCoordinator: ObservableObject {
    
    // MARK: - Singleton
    static let shared = AppCoordinator()
    
    // MARK: - Dependencies
    let projectStore: ProjectStore
    let connectionStore: ConnectionStore
    let navigationStore: NavigationStore
    let tabStore: TabStore
    let resultSpoolConfigCoordinator: ResultSpoolConfigCoordinator
    let diagramCoordinator: DiagramCoordinator
    let identityRepository: IdentityRepository
    let schemaDiscoveryCoordinator: MetadataDiscoveryCoordinator
    let bookmarkRepository: BookmarkRepository
    let historyRepository: HistoryRepository
    let environmentState: EnvironmentState
    let appState: AppState
    let clipboardHistory: ClipboardHistoryStore
    let appearanceStore: AppearanceStore
    let notificationEngine: NotificationEngine
    let resultSpoolManager: ResultSpoolCoordinator
    let diagramCacheStore: DiagramCacheStore
    let diagramKeyStore: DiagramEncryptionKeyStore
    private var cancellables = Set<AnyCancellable>()
#if os(macOS)
    private nonisolated(unsafe) var windowFocusObservers: [NSObjectProtocol] = []
#endif

    // MARK: - Initialization State
    @Published private(set) var isInitialized = false

    // MARK: - Private Init (Singleton)
    private init() {
        self.appState = AppState()
        let clipboardHistory = ClipboardHistoryStore()
        self.clipboardHistory = clipboardHistory
        let spoolRoot = ResultSpoolCoordinator.defaultRootDirectory()
        let spoolConfig = ResultSpoolConfiguration.defaultConfiguration(rootDirectory: spoolRoot)
        self.resultSpoolManager = ResultSpoolCoordinator(configuration: spoolConfig)
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
        self.schemaDiscoveryCoordinator = MetadataDiscoveryCoordinator(identityRepository: identityRepository, connectionStore: connectionStore)
        self.bookmarkRepository = BookmarkRepository()
        self.historyRepository = HistoryRepository()
        
        self.navigationStore = NavigationStore()
        self.tabStore = TabStore()
        self.appearanceStore = AppearanceStore.shared
        
        // Initialize new domain coordinators
        self.resultSpoolConfigCoordinator = ResultSpoolConfigCoordinator(spoolManager: resultSpoolManager)
        self.diagramCoordinator = DiagramCoordinator(cacheManager: cacheManager, keyStore: keyStore)
        
        self.environmentState = EnvironmentState(
            projectStore: projectStore,
            connectionStore: connectionStore,
            navigationStore: navigationStore,
            tabStore: tabStore,
            clipboardHistory: clipboardHistory,
            resultSpoolConfigCoordinator: resultSpoolConfigCoordinator,
            diagramCoordinator: diagramCoordinator,
            identityRepository: identityRepository,
            schemaDiscoveryCoordinator: schemaDiscoveryCoordinator,
            bookmarkRepository: bookmarkRepository,
            historyRepository: historyRepository,
            resultSpoolManager: resultSpoolManager,
            diagramCacheStore: cacheManager,
            diagramKeyStore: keyStore
        )
        
        let projectStoreRef = self.projectStore
        self.notificationEngine = NotificationEngine(
            toastCoordinator: environmentState.toastCoordinator,
            preferencesProvider: { [projectStoreRef] in
                projectStoreRef.globalSettings.notificationPreferences
            }
        )
        environmentState.notificationEngine = notificationEngine

        schemaDiscoveryCoordinator.onPersistConnections = { @MainActor [weak self] in
            await self?.environmentState.persistConnections()
        }
        schemaDiscoveryCoordinator.onEnqueuePrefetch = { @MainActor [weak self] session in
            await self?.environmentState.enqueuePrefetchForSessionIfNeeded(session)
        }
        
        // Setup cross-domain providers for DiagramCoordinator after EnvironmentState is initialized
        diagramCoordinator.globalSettingsProvider = { @MainActor [weak self] in
            self?.projectStore.globalSettings ?? GlobalSettings()
        }
        diagramCoordinator.sessionProvider = { @MainActor [weak self] sessionID in
            guard let self = self else { return nil }
            return self.environmentState.sessionCoordinator.activeSessions.first { $0.id == sessionID }
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

        isInitialized = true
        ensureInitialWorkspaceState()
    }

    // MARK: - Theme Binding
    private func setupBindings() {
        // Observe ProjectStore state for appearance changes
        // Using withObservationTracking is an alternative for @Observable,
        // but since we are in a Coordinator with Combine/Task logic, 
        // we'll bridge manually or use the Store's published-like behavior.
        // For now, we still need to sync EnvironmentState's legacy references until they are fully removed.

        _ = withObservationTracking {
            projectStore.selectedProject
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.applyEditorAppearance(project: self.projectStore.selectedProject, global: self.projectStore.globalSettings)
                self.setupBindings() // Re-track
            }
        }

        _ = withObservationTracking {
            projectStore.globalSettings
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.applyEditorAppearance(project: self.projectStore.selectedProject, global: self.projectStore.globalSettings)
                self.setupBindings() // Re-track
            }
        }

        AppearanceStore.shared.$effectiveColorScheme
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.applyEditorTheme(project: self.projectStore.selectedProject, global: self.projectStore.globalSettings)
            }
            .store(in: &cancellables)

        environmentState.sessionCoordinator.$activeSessions
            .receive(on: RunLoop.main)
            .sink { [weak self] sessions in
                guard let self else { return }
                if sessions.isEmpty {
#if !os(macOS)
                    self.presentConnectionsIfNeeded()
#endif
                } else {
                    self.dismissConnectionsIfNeeded()
                }
            }
            .store(in: &cancellables)
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

    private func ensureInitialWorkspaceState() {
        if environmentState.sessionCoordinator.activeSessions.isEmpty {
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

#if os(macOS)
    deinit {
        windowFocusObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }
#endif
}
