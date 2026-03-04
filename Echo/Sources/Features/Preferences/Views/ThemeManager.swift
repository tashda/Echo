import SwiftUI
import Combine

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Simplified theme management for Echo, supporting only Light/Dark mode and accent color.
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

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
        let initialScheme = ThemeManager.currentSystemColorScheme()
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
            effectiveColorScheme = ThemeManager.currentSystemColorScheme()
            #else
            effectiveColorScheme = .light
            #endif
        }
    }

    // MARK: - Legacy Compatibility (Temporary)
    // These are kept to prevent breaking the build while we migrate components.
    
    var activePaletteTone: SQLEditorPalette.Tone { effectiveColorScheme == .dark ? .dark : .light }
    var windowBackgroundColor: Color { ColorTokens.Background.primary }
    var surfaceBackgroundColor: Color { ColorTokens.Background.secondary }
    var surfaceForegroundColor: Color { ColorTokens.Text.primary }
    var resultsAlternateRowShading: Bool { false }
    var useAppThemeForResultsGrid: Bool { true }
    
    #if os(macOS)
    var accentNSColor: NSColor { NSColor(accentColor) }
    var windowBackgroundNSColor: NSColor { NSColor(ColorTokens.Background.primary) }
    var surfaceBackgroundNSColor: NSColor { NSColor(ColorTokens.Background.secondary) }
    var surfaceForegroundNSColor: NSColor { NSColor(ColorTokens.Text.primary) }
    #endif

    // MARK: - Private Helpers

    #if os(macOS)
    private func observeSystemAppearanceChanges() {
        appearanceObserver = NotificationCenter.default.addObserver(
            forName: ThemeManager.appearanceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Only update if we are in "system" mode. 
                // For now, we'll just always sync until we have the settings state accessible here.
                self.effectiveColorScheme = ThemeManager.currentSystemColorScheme()
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

// Minimal Compatibility Extensions
extension ThemeManager {
    var resultsGridBackground: Color { ColorTokens.Background.tertiary }
    
    #if os(macOS)
    var resultsGridBackgroundNSColor: NSColor { NSColor(resultsGridBackground) }
    var resultsGridCellTextNSColor: NSColor { NSColor(ColorTokens.Text.primary) }
    var resultsGridHeaderBackgroundNSColor: NSColor { NSColor(ColorTokens.Background.secondary) }
    var resultsGridHeaderTextNSColor: NSColor { NSColor(ColorTokens.Text.primary) }
    var resultsGridHeaderSeparatorNSColor: NSColor { NSColor(ColorTokens.Separator.primary) }
    #endif
}
