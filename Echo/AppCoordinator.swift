//
//  AppCoordinator.swift
//  Echo
//
//  Created by Assistant on 23/09/2025.
//

import Foundation
import SwiftUI
import Combine

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
    
    // MARK: - Initialization State
    @Published private(set) var isInitialized = false
    
    // MARK: - Private Init (Singleton)
    private init() {
        // Initialize dependencies in the correct order
        self.appState = AppState()
        let clipboardHistory = ClipboardHistoryStore()
        self.clipboardHistory = clipboardHistory
        self.appModel = AppModel(clipboardHistory: clipboardHistory)
        setupBindings()
    }
    
    // MARK: - Public Methods
    func initialize() async {
        guard !isInitialized else { return }
        
        // Perform any async initialization here
        await appModel.load()

        isInitialized = true
    }

    // MARK: - Theme Binding
    private func setupBindings() {
        appModel.$selectedProject
            .combineLatest(appModel.$globalSettings)
            .receive(on: RunLoop.main)
            .sink { [weak self] project, global in
                guard let self else { return }
                self.appState.sqlEditorTheme = SQLEditorThemeResolver.resolve(globalSettings: global, project: project)
                self.appState.sqlEditorDisplay = SQLEditorThemeResolver.resolveDisplayOptions(globalSettings: global, project: project)
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
    }
}
