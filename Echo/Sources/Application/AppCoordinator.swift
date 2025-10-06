//
//  AppCoordinator.swift
//  Echo
//
//  Created by Assistant on 23/09/2025.
//

import Foundation
import SwiftUI
import Combine
import AppKit

/// Central coordinator that manages the app's main dependencies and initialization
@MainActor
final class AppCoordinator: ObservableObject {
    
    // MARK: - Singleton
    static let shared = AppCoordinator()
    
    // MARK: - Dependencies
    let appModel: AppModel
    let appState: AppState
    let clipboardHistory: ClipboardHistoryStore
    private var cancellables = Set<AnyCancellable>()
    
    private var workspaceWindowController: WorkspaceWindowController?
    private var connectionsWindowController: ConnectionsWindowController?
    
    // MARK: - Initialization State
    @Published private(set) var isInitialized = false
    
    // MARK: - Private Init (Singleton)
    private init() {
        // Initialize dependencies in the correct order
        self.appState = AppState()
        let clipboardHistory = ClipboardHistoryStore()
        self.clipboardHistory = clipboardHistory
        self.appModel = AppModel(clipboardHistory: clipboardHistory)
        self.appModel.tabManager.delegate = self
        setupBindings()
    }
    
    // MARK: - Public Methods
    func initialize() async {
        guard !isInitialized else { return }

        // Perform any async initialization here
        await appModel.load()

        isInitialized = true
        ensureWorkspaceWindow(makeKey: true)
        workspaceWindowController?.bind(to: appModel.tabManager.activeTab)
    }

    // MARK: - Window Lifecycle

    private func ensureWorkspaceWindow(makeKey: Bool) {
        if workspaceWindowController == nil {
            workspaceWindowController = WorkspaceWindowController(coordinator: self)
        }
        workspaceWindowController?.show(makeKey: makeKey)
    }

    func openInitialWorkspaceIfNeeded() {
        guard appModel.tabManager.tabs.isEmpty else { return }
        ensureWorkspaceWindow(makeKey: true)
        if appModel.sessionManager.activeSessions.isEmpty {
            showConnectionsWindowIfNeeded(makeKey: true)
        } else {
            appModel.openQueryTab()
        }
    }

    func openQueryTabDuplicatingSession(of tab: WorkspaceTab) {
        if let session = appModel.sessionManager.activeSessions.first(where: { $0.id == tab.connectionSessionID }) {
            appModel.openQueryTab(for: session)
        } else {
            appModel.openQueryTab()
        }
    }

    func workspaceWindowDidBecomeMain(_ controller: WorkspaceWindowController) {
        guard controller === workspaceWindowController else { return }
        if let activeTab = appModel.tabManager.activeTab {
            appModel.sessionManager.setActiveSession(activeTab.connectionSessionID)
            workspaceWindowController?.bind(to: activeTab)
        }
    }

    func workspaceWindowWillClose(_ controller: WorkspaceWindowController) {
        guard controller === workspaceWindowController else { return }
        workspaceWindowController = nil
    }

    func reopenLastWindow() {
        ensureWorkspaceWindow(makeKey: true)
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
                    if self.appModel.tabManager.tabs.isEmpty {
                        self.showConnectionsWindowIfNeeded(makeKey: true)
                    }
                } else {
                    self.hideConnectionsWindowIfNeeded()
                }
            }
            .store(in: &cancellables)
    }

    private func applyEditorAppearance(project: Project?, global: GlobalSettings) {
        appState.sqlEditorDisplay = SQLEditorThemeResolver.resolveDisplayOptions(globalSettings: global, project: project)
        applyEditorTheme(project: project, global: global)
    }

    private func applyEditorTheme(project: Project?, global: GlobalSettings) {
        let tone = ThemeManager.shared.activePaletteTone
        appState.sqlEditorTheme = SQLEditorThemeResolver.resolve(globalSettings: global, project: project, tone: tone)
    }

    private func updateWindowBindingForActiveTab() {
        workspaceWindowController?.bind(to: appModel.tabManager.activeTab)
    }
}

// MARK: - TabManagerDelegate

extension AppCoordinator: TabManagerDelegate {
    func tabManager(_ manager: TabManager, didAdd tab: WorkspaceTab) {
        hideConnectionsWindowIfNeeded()
        ensureWorkspaceWindow(makeKey: manager.activeTabId == tab.id)
        if manager.activeTabId == tab.id {
            appModel.sessionManager.setActiveSession(tab.connectionSessionID)
            workspaceWindowController?.bind(to: tab)
        }
    }

    func tabManager(_ manager: TabManager, didRemoveTabID tabID: UUID) {
        if let activeTab = manager.activeTab {
            appModel.sessionManager.setActiveSession(activeTab.connectionSessionID)
            workspaceWindowController?.bind(to: activeTab)
        } else {
            appModel.sessionManager.activeSessionID = nil
            workspaceWindowController?.bind(to: nil)
        }
    }

    func tabManager(_ manager: TabManager, didSetActiveTabID tabID: UUID?) {
        guard let tabID, let tab = manager.getTab(id: tabID) else {
            appModel.sessionManager.activeSessionID = nil
            workspaceWindowController?.bind(to: nil)
            return
        }

        ensureWorkspaceWindow(makeKey: true)
        appModel.sessionManager.setActiveSession(tab.connectionSessionID)
        workspaceWindowController?.bind(to: tab)
    }

    func tabManagerDidReorderTabs(_ manager: TabManager) {
        updateWindowBindingForActiveTab()
    }
}

// MARK: - Connections Window

private extension AppCoordinator {
    func showConnectionsWindowIfNeeded(makeKey: Bool) {
        if connectionsWindowController == nil {
            connectionsWindowController = ConnectionsWindowController(coordinator: self)
        }
        connectionsWindowController?.show(makeKey: makeKey)
    }

    func hideConnectionsWindowIfNeeded() {
        if let controller = connectionsWindowController {
            controller.window?.close()
            connectionsWindowController = nil
        }
    }
}
