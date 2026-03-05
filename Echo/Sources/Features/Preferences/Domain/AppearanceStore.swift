import SwiftUI
import Combine

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Simplified theme management for Echo, supporting only Light/Dark mode and accent color.
@MainActor
final class AppearanceStore: ObservableObject {
    static let shared = AppearanceStore()

    @Published private(set) var effectiveColorScheme: ColorScheme
    @Published private(set) var accentColor: Color = .accentColor
    
    // User preference for accent color override (if any)
    private var customAccentColor: Color?

    #if os(macOS)
    private nonisolated(unsafe) var appearanceObserver: NSObjectProtocol?
    private static let appearanceDidChangeNotification = Notification.Name("NSApplicationDidChangeEffectiveAppearanceNotification")
    #endif

    private init() {
        #if os(macOS)
        let initialScheme = AppearanceStore.currentSystemColorScheme()
        #else
        let initialScheme: ColorScheme = .light
        #endif
        
        self.effectiveColorScheme = initialScheme
        
        #if os(macOS)
        observeSystemAppearanceChanges()
        #endif
    }

    // MARK: - Public API

    func setAccentColor(_ color: Color?) {
        customAccentColor = color
        accentColor = color ?? .accentColor
    }

    func applyAppearanceMode(_ mode: AppearanceMode) {
        switch mode {
        case .light:
            effectiveColorScheme = .light
        case .dark:
            effectiveColorScheme = .dark
        case .system:
            #if os(macOS)
            effectiveColorScheme = AppearanceStore.currentSystemColorScheme()
            #else
            effectiveColorScheme = .light
            #endif
        }
    }

    #if os(macOS)
    var accentNSColor: NSColor { NSColor(accentColor) }
    #endif

    // MARK: - Private Helpers

    #if os(macOS)
    private func observeSystemAppearanceChanges() {
        appearanceObserver = NotificationCenter.default.addObserver(
            forName: AppearanceStore.appearanceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Only update if we are in "system" mode. 
                // For now, we'll just always sync until we have the settings state accessible here.
                self.effectiveColorScheme = AppearanceStore.currentSystemColorScheme()
            }
        }
    }

    @MainActor
    private static func currentSystemColorScheme() -> ColorScheme {
        guard let appearance = NSApp?.effectiveAppearance else {
            return .light
        }
        let match = appearance.bestMatch(from: [.darkAqua, .aqua]) ?? .aqua
        return match == .darkAqua ? .dark : .light
    }
    #endif

    deinit {
        #if os(macOS)
        if let appearanceObserver {
            NotificationCenter.default.removeObserver(appearanceObserver)
        }
        #endif
    }
}

