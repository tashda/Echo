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
    let appModel: AppModel
    let appState: AppState
    let clipboardHistory: ClipboardHistoryStore
    let themeManager: ThemeManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization State
    @Published private(set) var isInitialized = false

    // MARK: - Private Init (Singleton)
    private init() {
        self.appState = AppState()
        let clipboardHistory = ClipboardHistoryStore()
        self.clipboardHistory = clipboardHistory
        self.appModel = AppModel(clipboardHistory: clipboardHistory)
        self.themeManager = ThemeManager.shared
        self.appModel.tabManager.delegate = self
        setupBindings()
    }

    // MARK: - Public Methods
    func initialize() async {
        guard !isInitialized else { return }

        await appModel.load()

        isInitialized = true
        ensureInitialWorkspaceState()
    }

    // MARK: - Theme Binding
    private func setupBindings() {
        appModel.$selectedProject
            .combineLatest(appModel.$globalSettings)
            .receive(on: RunLoop.main)
            .sink { [weak self] project, global in
                self?.applyEditorAppearance(project: project, global: global)
            }
            .store(in: &cancellables)

        ThemeManager.shared.$effectiveColorScheme
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.applyEditorTheme(project: self.appModel.selectedProject, global: self.appModel.globalSettings)
            }
            .store(in: &cancellables)

        appModel.$projects
            .receive(on: RunLoop.main)
            .sink { [weak self] projects in
                guard let self, let selectedId = self.appModel.selectedProject?.id else { return }
                if let updated = projects.first(where: { $0.id == selectedId }), updated != self.appModel.selectedProject {
                    self.appModel.selectedProject = updated
                }
            }
            .store(in: &cancellables)

        appModel.sessionManager.$activeSessions
            .receive(on: RunLoop.main)
            .sink { [weak self] sessions in
                guard let self else { return }
                if sessions.isEmpty {
                    self.presentConnectionsIfNeeded()
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
        applyEditorTheme(project: project, global: global)
    }

    private func applyEditorTheme(project: Project?, global: GlobalSettings) {
        let tone = ThemeManager.shared.activePaletteTone
        appState.sqlEditorTheme = SQLEditorThemeResolver.resolve(globalSettings: global, project: project, tone: tone)
    }

    private func ensureInitialWorkspaceState() {
        if appModel.sessionManager.activeSessions.isEmpty {
            presentConnectionsIfNeeded()
        } else if appModel.tabManager.tabs.isEmpty {
            appModel.openQueryTab()
        }
    }

    private func presentConnectionsIfNeeded() {
        guard !appModel.isManageConnectionsPresented else { return }
        appModel.isManageConnectionsPresented = true
    }

    private func dismissConnectionsIfNeeded() {
        appModel.isManageConnectionsPresented = false
    }

#if os(macOS)
    func workspaceWindowDidBecomeMain(_ controller: WorkspaceWindowController) {
        if let activeTab = appModel.tabManager.activeTab {
            appModel.sessionManager.setActiveSession(activeTab.connectionSessionID)
        }
    }

    func workspaceWindowWillClose(_ controller: WorkspaceWindowController) {
        appModel.sessionManager.activeSessionID = nil
        appModel.tabManager.activeTabId = nil
        presentConnectionsIfNeeded()
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
            presentConnectionsIfNeeded()
            return
        }

        appModel.sessionManager.setActiveSession(tab.connectionSessionID)
    }

    func tabManagerDidReorderTabs(_ manager: TabManager) {
        // Future hook for syncing external UI
    }
}
