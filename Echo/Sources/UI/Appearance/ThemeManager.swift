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
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published private(set) var effectiveColorScheme: ColorScheme
    @Published private(set) var activeTheme: AppColorTheme
    @Published private(set) var accentColor: Color
    @Published private(set) var windowBackgroundColor: Color
    @Published private(set) var surfaceBackgroundColor: Color
    @Published private(set) var surfaceForegroundColor: Color
    @Published private(set) var useAppThemeForResultsGrid: Bool
    @Published private(set) var resultsAlternateRowShading: Bool

#if os(macOS)
    @Published private(set) var accentNSColor: NSColor
    @Published private(set) var windowBackgroundNSColor: NSColor
    @Published private(set) var surfaceBackgroundNSColor: NSColor
    @Published private(set) var surfaceForegroundNSColor: NSColor
#endif

    /// Combine publisher for imperative consumers that need to react to accent color changes.
    var accentPublisher: AnyPublisher<Color, Never> {
        accentSubject.eraseToAnyPublisher()
    }

    var activePaletteTone: SQLEditorPalette.Tone { activeTone }
    var windowBackground: Color { windowBackgroundColor }
    var surfaceBackground: Color { surfaceBackgroundColor }
    var surfaceForeground: Color { surfaceForegroundColor }

    private var themesByTone: [SQLEditorPalette.Tone: AppColorTheme]
    private var activeTone: SQLEditorPalette.Tone
    private let accentSubject: CurrentValueSubject<Color, Never>
#if os(macOS)
    private var appearanceObserver: NSObjectProtocol?
    private static let appearanceDidChangeNotification = Notification.Name("NSApplicationDidChangeEffectiveAppearanceNotification")
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
        let initialTheme = themesByTone[activeTone] ?? defaultLightTheme
        activeTheme = initialTheme

        let accentRepresentable = ThemeManager.accentRepresentable(from: initialTheme)
        let initialAccentColor = accentRepresentable.color
        accentColor = initialAccentColor
        windowBackgroundColor = initialTheme.windowBackground.color
        surfaceBackgroundColor = initialTheme.surfaceBackground.color
        surfaceForegroundColor = initialTheme.surfaceForeground.color
        useAppThemeForResultsGrid = true
        resultsAlternateRowShading = false
        accentSubject = CurrentValueSubject<Color, Never>(initialAccentColor)

#if os(macOS)
        accentNSColor = accentRepresentable.nsColor
        windowBackgroundNSColor = initialTheme.windowBackground.nsColor
        surfaceBackgroundNSColor = initialTheme.surfaceBackground.nsColor
        surfaceForegroundNSColor = initialTheme.surfaceForeground.nsColor
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

    func surfaceBackgroundColor(for tone: SQLEditorPalette.Tone) -> Color {
        theme(for: tone).surfaceBackground.color
    }

    func surfaceForegroundColor(for tone: SQLEditorPalette.Tone) -> Color {
        theme(for: tone).surfaceForeground.color
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
        NSApp?.appearance = NSAppearance(named: tone == .dark ? .darkAqua : .aqua)
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

    func applyResultsGridPreferences(themeResultsGrid: Bool, alternateRowShading: Bool) {
        if useAppThemeForResultsGrid != themeResultsGrid {
            useAppThemeForResultsGrid = themeResultsGrid
        }
        if resultsAlternateRowShading != alternateRowShading {
            resultsAlternateRowShading = alternateRowShading
        }
    }

    // MARK: - Private Helpers

    private func updateOutputs(for tone: SQLEditorPalette.Tone) {
        let theme = theme(for: tone)
        activeTheme = theme

        let accentRepresentable = ThemeManager.accentRepresentable(from: theme)
        accentColor = accentRepresentable.color
        windowBackgroundColor = theme.windowBackground.color
        surfaceBackgroundColor = theme.surfaceBackground.color
        surfaceForegroundColor = theme.surfaceForeground.color
        accentSubject.send(accentColor)

#if os(macOS)
        accentNSColor = accentRepresentable.nsColor
        windowBackgroundNSColor = theme.windowBackground.nsColor
        surfaceBackgroundNSColor = theme.surfaceBackground.nsColor
        surfaceForegroundNSColor = theme.surfaceForeground.nsColor
        applyChromeToWindows(theme)
#endif
    }

#if os(macOS)
    private func observeSystemAppearanceChanges() {
        appearanceObserver = NotificationCenter.default.addObserver(
            forName: ThemeManager.appearanceDidChangeNotification,
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
#if os(macOS)
        if theme.id.hasPrefix("builtin-echo-") {
            return ColorRepresentable(color: Color(nsColor: NSColor.controlAccentColor))
        }
#elseif canImport(UIKit)
        if theme.id.hasPrefix("builtin-echo-") {
            return ColorRepresentable(color: Color(uiColor: .tintColor))
        }
#endif
        if let accent = theme.accent {
            return accent
        }
        if let swatch = theme.swatchColors.first {
            return swatch
        }
        return theme.surfaceForeground
    }
}

extension ThemeManager {
    /// Legacy compatibility for components that still expect this flag.
    var showAlternateRowShading: Bool { resultsAlternateRowShading }

    var resultsGridBackground: Color {
#if os(macOS)
        let fallback = Color(NSColor.textBackgroundColor)
#else
        let fallback = Color(uiColor: .systemBackground)
#endif
        return useAppThemeForResultsGrid ? windowBackgroundColor : fallback
    }

#if os(macOS)
    var resultsGridBackgroundNSColor: NSColor {
        useAppThemeForResultsGrid ? windowBackgroundNSColor : NSColor.textBackgroundColor
    }
#elseif canImport(UIKit)
    var resultsGridBackgroundUIColor: UIColor {
        if useAppThemeForResultsGrid {
            return UIColor(resultsGridBackground)
        } else {
            return UIColor.systemBackground
        }
    }
#endif

    var resultsGridLeadingInset: CGFloat {
#if os(macOS)
        return 0
#else
        return 0
#endif
    }

#if os(macOS)
    var resultsGridCellBackgroundNSColor: NSColor { resultsGridBackgroundNSColor }

    var resultsGridCellTextNSColor: NSColor {
        useAppThemeForResultsGrid ? surfaceForegroundNSColor : NSColor.labelColor
    }

    var resultsGridAlternateRowNSColor: NSColor {
        guard resultsAlternateRowShading else { return resultsGridCellBackgroundNSColor }
        if useAppThemeForResultsGrid {
            let base = resultsGridCellBackgroundNSColor.usingColorSpace(.extendedSRGB) ?? resultsGridCellBackgroundNSColor
            let accent = accentNSColor.usingColorSpace(.extendedSRGB) ?? accentNSColor
            return base.blended(withFraction: 0.04, of: accent) ?? base
        } else {
            let alternating = NSColor.controlAlternatingRowBackgroundColors
            if alternating.count > 1 {
                return alternating[1]
            }
            return alternating.first ?? NSColor.textBackgroundColor
        }
    }

    var resultsGridHeaderBackgroundNSColor: NSColor {
        useAppThemeForResultsGrid ? surfaceBackgroundNSColor : NSColor.windowBackgroundColor
    }

    var resultsGridHeaderTextNSColor: NSColor {
        useAppThemeForResultsGrid ? surfaceForegroundNSColor : NSColor.labelColor
    }

    var resultsGridHeaderSeparatorNSColor: NSColor {
        useAppThemeForResultsGrid ? accentNSColor.withAlphaComponent(0.2) : NSColor.separatorColor
    }
#elseif canImport(UIKit)
    var resultsGridAlternateRowUIColor: UIColor {
        guard resultsAlternateRowShading else { return resultsGridBackgroundUIColor }
        return useAppThemeForResultsGrid ? UIColor.systemGray6 : UIColor.secondarySystemBackground
    }
#endif
}
