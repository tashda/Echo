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
    let resultSpoolCoordinator: ResultSpoolCoordinator
    let diagramCoordinator: DiagramCoordinator
    let appModel: AppModel
    let appState: AppState
    let clipboardHistory: ClipboardHistoryStore
    let themeManager: ThemeManager
    let resultSpoolManager: ResultSpoolManager
    let diagramCacheManager: DiagramCacheManager
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
        let spoolRoot = ResultSpoolManager.defaultRootDirectory()
        let spoolConfig = ResultSpoolConfiguration.defaultConfiguration(rootDirectory: spoolRoot)
        self.resultSpoolManager = ResultSpoolManager(configuration: spoolConfig)
        let cacheRoot = DiagramCacheManager.defaultRootDirectory()
        let diagramConfig = DiagramCacheManager.Configuration(rootDirectory: cacheRoot)
        let keyStore = DiagramEncryptionKeyStore()
        let cacheManager = DiagramCacheManager(configuration: diagramConfig)
        self.diagramCacheManager = cacheManager
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
        
        self.navigationStore = NavigationStore()
        self.tabStore = TabStore()
        self.themeManager = ThemeManager.shared
        
        // Initialize new domain coordinators
        self.resultSpoolCoordinator = ResultSpoolCoordinator(spoolManager: resultSpoolManager)
        self.diagramCoordinator = DiagramCoordinator(cacheManager: cacheManager, keyStore: keyStore)
        
        self.appModel = AppModel(
            projectStore: projectStore,
            connectionStore: connectionStore,
            navigationStore: navigationStore,
            tabStore: tabStore,
            clipboardHistory: clipboardHistory,
            resultSpoolCoordinator: resultSpoolCoordinator,
            diagramCoordinator: diagramCoordinator,
            resultSpoolManager: resultSpoolManager,
            diagramCacheManager: cacheManager,
            diagramKeyStore: keyStore
        )
        
        // Setup cross-domain providers for DiagramCoordinator after AppModel is initialized
        diagramCoordinator.globalSettingsProvider = { @MainActor [weak self] in
            self?.projectStore.globalSettings ?? GlobalSettings()
        }
        diagramCoordinator.sessionProvider = { @MainActor [weak self] sessionID in
            guard let self = self else { return nil }
            return self.appModel.sessionManager.activeSessions.first { $0.id == sessionID }
        }

        Task {
            await cacheManager.updateKeyProvider { projectID in
                try await MainActor.run {
                    try keyStore.symmetricKey(forProjectID: projectID)
                }
            }
        }

        self.appModel.tabManager.delegate = self
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

        await appModel.load()

        isInitialized = true
        ensureInitialWorkspaceState()
    }

    // MARK: - Theme Binding
    private func setupBindings() {
        // Observe ProjectStore state for appearance changes
        // Using withObservationTracking is an alternative for @Observable,
        // but since we are in a Coordinator with Combine/Task logic, 
        // we'll bridge manually or use the Store's published-like behavior.
        // For now, we still need to sync AppModel's legacy references until they are fully removed.

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

        ThemeManager.shared.$effectiveColorScheme
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.applyEditorTheme(project: self.projectStore.selectedProject, global: self.projectStore.globalSettings)
            }
            .store(in: &cancellables)

        appModel.sessionManager.$activeSessions
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
        ThemeManager.shared.applyAppearanceMode(global.appearanceMode)
        appState.sqlEditorDisplay = SQLEditorThemeResolver.resolveDisplayOptions(globalSettings: global, project: project)
        appState.themeTabs = global.themeTabs
        appState.workspaceTabBarStyle = global.workspaceTabBarStyle
        appState.keepTabsInMemory = global.keepTabsInMemory
        applyEditorTheme(project: project, global: global)
    }

    private func applyEditorTheme(project: Project?, global: GlobalSettings) {
        let tone = ThemeManager.shared.activePaletteTone
        appState.sqlEditorTheme = SQLEditorThemeResolver.resolve(globalSettings: global, project: project, tone: tone)
    }

    private func ensureInitialWorkspaceState() {
        if appModel.sessionManager.activeSessions.isEmpty {
#if !os(macOS)
            presentConnectionsIfNeeded()
#endif
        } else if appModel.tabManager.tabs.isEmpty {
            appModel.openQueryTab()
        }
    }

    private func presentConnectionsIfNeeded() {
        guard !navigationStore.isManageConnectionsPresented else { return }
#if os(macOS)
        ManageConnectionsWindowController.shared.present()
#else
        navigationStore.isManageConnectionsPresented = true
#endif
    }

    private func dismissConnectionsIfNeeded() {
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

// MARK: - TabManagerDelegate

extension AppCoordinator: TabManagerDelegate {
    func tabManager(_ manager: TabManager, didAdd tab: WorkspaceTab) {
        if manager.activeTabId == tab.id {
            appModel.sessionManager.setActiveSession(tab.connectionSessionID)
        }
    }

    func tabManager(_ manager: TabManager, shouldClose tab: WorkspaceTab) -> Bool {
        guard let context = tab.bookmarkContext, let queryState = tab.query else {
            return true
        }

#if os(macOS)
        let alert = NSAlert()
        alert.messageText = "Save bookmark \"\(context.displayName)\"?"
        alert.informativeText = "Do you want to save the current query back to this bookmark before closing the tab?"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            let currentQuery = queryState.sql
            Task { [weak self] in
                await self?.appModel.updateBookmarkQuery(context.bookmarkID, newQuery: currentQuery)
            }
            return true
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
#else
        return true
#endif
    }

    func tabManager(_ manager: TabManager, didRemoveTabID tabID: UUID) {
        if let activeTab = manager.activeTab {
            appModel.sessionManager.setActiveSession(activeTab.connectionSessionID)
        } else {
            appModel.sessionManager.activeSessionID = nil
        }
    }

    func tabManager(_ manager: TabManager, didSetActiveTabID tabID: UUID?) {
        guard let tabID, let tab = manager.getTab(id: tabID) else {
            appModel.sessionManager.activeSessionID = nil
#if !os(macOS)
            presentConnectionsIfNeeded()
#endif
            return
        }

        appModel.sessionManager.setActiveSession(tab.connectionSessionID)
    }

    func tabManagerDidReorderTabs(_ manager: TabManager) {
        // Future hook for syncing external UI
    }
}
