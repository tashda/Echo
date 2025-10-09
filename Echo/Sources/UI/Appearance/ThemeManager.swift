//
//  ThemeManager.swift
//  Echo
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

    @Published private(set) var effectiveColorScheme: ColorScheme = .light
    
    var activePaletteTone: SQLEditorPalette.Tone {
        effectiveColorScheme == .dark ? .dark : .light
    }

    private let userDefaults = UserDefaults.standard
    private var appearanceObserver: AnyCancellable?

    private init() {
        let savedTheme = userDefaults.string(forKey: "selectedTheme")
        self.currentTheme = AppTheme(rawValue: savedTheme ?? AppTheme.system.rawValue) ?? .system
        updateAppearance()
        observeSystemAppearanceChanges()
    }

    /// Public initializer for testing/previews; does not update appearance unless for production singleton

    public init(forTesting: Bool = false) {
        let savedTheme = userDefaults.string(forKey: "selectedTheme")
        self.currentTheme = AppTheme(rawValue: savedTheme ?? AppTheme.system.rawValue) ?? .system
        if !forTesting {
            updateAppearance()
            observeSystemAppearanceChanges()
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
        updateEffectiveColorScheme()
    }

    private func observeSystemAppearanceChanges() {
        let notificationName = Notification.Name("NSApplicationDidChangeEffectiveAppearanceNotification")
        appearanceObserver = NotificationCenter.default.publisher(for: notificationName)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if self.currentTheme == .system {
                    self.updateEffectiveColorScheme()
                }
            }
    }

    private func updateEffectiveColorScheme() {
        let resolvedScheme: ColorScheme
        switch currentTheme {
        case .light:
            resolvedScheme = .light
        case .dark:
            resolvedScheme = .dark
        case .system:
            let appearance = NSApp?.effectiveAppearance ?? NSAppearance(named: .aqua)
            let match = appearance?.bestMatch(from: [.darkAqua, .aqua]) ?? .aqua
            resolvedScheme = match == .darkAqua ? .dark : .light
        }

        if effectiveColorScheme != resolvedScheme {
            effectiveColorScheme = resolvedScheme
        }
    }

    // Convenience computed properties for theme-aware styling
    @Published var showAlternateRowShading: Bool = true

    // Convenience computed properties for theme-aware styling
    var backgroundColor: Color {
        Color(NSColor.controlBackgroundColor)
    }

    var sidebarBackground: NSVisualEffectView.Material {
        .sidebar
    }

    var windowBackground: Color {
        switch currentTheme {
        case .light:
            return Color.white
        case .dark:
            return Color(NSColor.windowBackgroundColor)
        case .system:
            return Color(NSColor.windowBackgroundColor)
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
