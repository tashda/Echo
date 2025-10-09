//
//  ThemeManager.swift
//  Echo
//
//  Created by Assistant on 08/10/2025.
//

import SwiftUI
import Combine

#if os(macOS)
import AppKit
#endif

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published private(set) var effectiveColorScheme: ColorScheme
    @Published private(set) var activeTheme: AppColorTheme
    @Published private(set) var accentColor: Color
    @Published private(set) var windowBackgroundColor: Color

#if os(macOS)
    @Published private(set) var accentNSColor: NSColor
    @Published private(set) var windowBackgroundNSColor: NSColor
#endif

    /// Combine publisher for imperative consumers that need to react to accent color changes.
    var accentPublisher: AnyPublisher<Color, Never> {
        accentSubject.eraseToAnyPublisher()
    }

    var activePaletteTone: SQLEditorPalette.Tone { activeTone }
    var windowBackground: Color { windowBackgroundColor }

    private var themesByTone: [SQLEditorPalette.Tone: AppColorTheme]
    private var activeTone: SQLEditorPalette.Tone
    private let accentSubject: CurrentValueSubject<Color, Never>
#if os(macOS)
    private var appearanceObserver: NSObjectProtocol?
#endif

    private init() {
        let defaultLightTheme = AppColorTheme.builtInThemes(for: .light).first
            ?? AppColorTheme.fromPalette(.aurora, idOverride: "builtin-initial-light", isCustom: false)
        let defaultDarkTheme = AppColorTheme.builtInThemes(for: .dark).first
            ?? AppColorTheme.fromPalette(.midnight, idOverride: "builtin-initial-dark", isCustom: false)
        themesByTone = [.light: defaultLightTheme, .dark: defaultDarkTheme]

#if os(macOS)
        let initialScheme = ThemeManager.currentSystemColorScheme()
#else
        let initialScheme: ColorScheme = .light
#endif
        effectiveColorScheme = initialScheme
        activeTone = ThemeManager.tone(for: initialScheme)
        activeTheme = themesByTone[activeTone] ?? defaultLightTheme

        let accentRepresentable = ThemeManager.accentRepresentable(from: activeTheme)
        accentColor = accentRepresentable.color
        windowBackgroundColor = activeTheme.windowBackground.color
        accentSubject = CurrentValueSubject<Color, Never>(accentColor)

#if os(macOS)
        accentNSColor = accentRepresentable.nsColor
        windowBackgroundNSColor = activeTheme.windowBackground.nsColor
        observeSystemAppearanceChanges()
#endif
    }

    // MARK: - Theme Accessors

    func theme(for tone: SQLEditorPalette.Tone) -> AppColorTheme {
        if let stored = themesByTone[tone] {
            return stored
        }
        let fallback = AppColorTheme.builtInThemes(for: tone).first
            ?? AppColorTheme.fromPalette(tone == .dark ? .midnight : .aurora)
        themesByTone[tone] = fallback
        return fallback
    }

    func accentColor(for tone: SQLEditorPalette.Tone) -> Color {
        ThemeManager.accentRepresentable(from: theme(for: tone)).color
    }

    func windowBackgroundColor(for tone: SQLEditorPalette.Tone) -> Color {
        theme(for: tone).windowBackground.color
    }

#if os(macOS)
    func windowBackgroundNSColor(for tone: SQLEditorPalette.Tone) -> NSColor {
        theme(for: tone).windowBackground.nsColor
    }

    func accentNSColor(for tone: SQLEditorPalette.Tone) -> NSColor {
        ThemeManager.accentRepresentable(from: theme(for: tone)).nsColor
    }
#endif

    // MARK: - Mutating API

    func applyChrome(theme: AppColorTheme, tone: SQLEditorPalette.Tone) {
        themesByTone[tone] = theme
        if tone == activeTone {
            updateOutputs(for: tone)
        }
#if os(macOS)
        applyChromeToWindows(theme)
#endif
    }

    func setActiveTone(_ tone: SQLEditorPalette.Tone) {
        guard tone != activeTone else { return }
        activeTone = tone
        effectiveColorScheme = ThemeManager.colorScheme(for: tone)
        updateOutputs(for: tone)
    }

    func overrideColorScheme(_ scheme: ColorScheme) {
        let tone = ThemeManager.tone(for: scheme)
        effectiveColorScheme = scheme
        activeTone = tone
        updateOutputs(for: tone)
    }

    func applyAppearanceMode(_ mode: AppearanceMode) {
        switch mode {
        case .light:
            setActiveTone(.light)
        case .dark:
            setActiveTone(.dark)
        case .system:
#if os(macOS)
            let scheme = ThemeManager.currentSystemColorScheme()
            effectiveColorScheme = scheme
            activeTone = ThemeManager.tone(for: scheme)
            updateOutputs(for: activeTone)
#else
            setActiveTone(.light)
#endif
        }
    }

    // MARK: - Private Helpers

    private func updateOutputs(for tone: SQLEditorPalette.Tone) {
        let theme = theme(for: tone)
        activeTheme = theme

        let accentRepresentable = ThemeManager.accentRepresentable(from: theme)
        accentColor = accentRepresentable.color
        windowBackgroundColor = theme.windowBackground.color
        accentSubject.send(accentColor)

#if os(macOS)
        accentNSColor = accentRepresentable.nsColor
        windowBackgroundNSColor = theme.windowBackground.nsColor
        applyChromeToWindows(theme)
#endif
    }

#if os(macOS)
    private func observeSystemAppearanceChanges() {
        appearanceObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeEffectiveAppearanceNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let scheme = ThemeManager.currentSystemColorScheme()
            self.effectiveColorScheme = scheme
            self.activeTone = ThemeManager.tone(for: scheme)
            self.updateOutputs(for: self.activeTone)
        }
    }

    private func applyChromeToWindows(_ theme: AppColorTheme) {
        for window in NSApp?.windows ?? [] {
            window.backgroundColor = theme.windowBackground.nsColor
        }
    }

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

    private static func tone(for scheme: ColorScheme) -> SQLEditorPalette.Tone {
        scheme == .dark ? .dark : .light
    }

    private static func colorScheme(for tone: SQLEditorPalette.Tone) -> ColorScheme {
        tone == .dark ? .dark : .light
    }

    private static func accentRepresentable(from theme: AppColorTheme) -> ColorRepresentable {
        if let accent = theme.accent {
            return accent
        }
        if let swatch = theme.swatchColors.first {
            return swatch
        }
        return theme.surfaceForeground
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
