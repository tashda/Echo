import SwiftUI
import Combine
import AppKit

/// Simplified theme management for Echo, supporting only Light/Dark mode and accent color.
@MainActor
final class AppearanceStore: ObservableObject {
    static let shared = AppearanceStore()

    @Published private(set) var effectiveColorScheme: ColorScheme
    @Published private(set) var accentColor: Color = .accentColor

    /// Tracks the user's chosen appearance mode so the system-change observer
    /// only updates `effectiveColorScheme` when in `.system` mode.
    private(set) var currentMode: AppearanceMode = .system

    // User preference for accent color override (if any)
    private var customAccentColor: Color?

    private nonisolated(unsafe) var appearanceObserver: NSObjectProtocol?
    private static let appearanceDidChangeNotification = Notification.Name("NSApplicationDidChangeEffectiveAppearanceNotification")

    private init() {
        self.effectiveColorScheme = AppearanceStore.currentSystemColorScheme()
        observeSystemAppearanceChanges()
    }

    // MARK: - Public API

    func setAccentColor(_ color: Color?) {
        customAccentColor = color
        accentColor = color ?? .accentColor
    }

    func applyAppearanceMode(_ mode: AppearanceMode) {
        currentMode = mode
        switch mode {
        case .light:
            effectiveColorScheme = .light
        case .dark:
            effectiveColorScheme = .dark
        case .system:
            effectiveColorScheme = AppearanceStore.currentSystemColorScheme()
        }
    }

    var accentNSColor: NSColor { NSColor(accentColor) }

    // MARK: - Private Helpers

    private func observeSystemAppearanceChanges() {
        appearanceObserver = NotificationCenter.default.addObserver(
            forName: AppearanceStore.appearanceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.currentMode == .system else { return }
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

    deinit {
        if let appearanceObserver {
            NotificationCenter.default.removeObserver(appearanceObserver)
        }
    }
}

