//
//  ThemeManager.swift
//  fuzee
//
//  Created by Assistant on 23/09/2025.
//

import SwiftUI
import Combine
import AppKit

/// Manages the app's theme settings and appearance
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
            updateAppearance()
        }
    }
    
    private let userDefaults = UserDefaults.standard

    private init() {
        let savedTheme = userDefaults.string(forKey: "selectedTheme")
        self.currentTheme = AppTheme(rawValue: savedTheme ?? AppTheme.system.rawValue) ?? .system
        updateAppearance()
    }

    /// Public initializer for testing/previews; does not update appearance unless for production singleton

    public init(forTesting: Bool = false) {
        let savedTheme = userDefaults.string(forKey: "selectedTheme")
        self.currentTheme = AppTheme(rawValue: savedTheme ?? AppTheme.system.rawValue) ?? .system
        if !forTesting {
            updateAppearance()
        }
    }
    
    private func updateAppearance() {
        switch currentTheme {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system:
            NSApp.appearance = nil // Use system setting
        }
    }

    // Convenience computed properties for theme-aware styling
    var backgroundColor: Color {
        return Color(NSColor.controlBackgroundColor)
    }

    var sidebarBackground: NSVisualEffectView.Material {
        return .sidebar
    }

    var windowBackground: Color {
        switch currentTheme {
        case .light:
            return Color.white
        case .dark:
            return Color(NSColor.windowBackgroundColor)
        case .system:
            return Color(NSColor.controlBackgroundColor)
        }
    }
}

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .system:
            return "System"
        }
    }
    
    var iconName: String {
        switch self {
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        case .system:
            return "circle.lefthalf.filled"
        }
    }
}