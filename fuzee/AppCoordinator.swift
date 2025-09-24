//
//  AppCoordinator.swift
//  fuzee
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
    
    // MARK: - Initialization State
    @Published private(set) var isInitialized = false
    
    // MARK: - Private Init (Singleton)
    private init() {
        // Initialize dependencies in the correct order
        self.appState = AppState()
        self.appModel = AppModel()
    }
    
    // MARK: - Public Methods
    func initialize() async {
        guard !isInitialized else { return }
        
        // Perform any async initialization here
        await appModel.load()
        
        isInitialized = true
    }
}
