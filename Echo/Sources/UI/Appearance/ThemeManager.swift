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
    private var tokenPalettesByTone: [SQLEditorPalette.Tone: SQLEditorTokenPalette]
    private var resultGridColorsByTone: [SQLEditorPalette.Tone: SQLEditorTokenPalette.ResultGridColors]
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
        tokenPalettesByTone = [:]
        resultGridColorsByTone = [:]

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
        resultGridColorsByTone[activeTone] = SQLEditorTokenPalette.ResultGridColors.defaults(for: activeTone)
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

    private func updateResultGridPalette(
        for tone: SQLEditorPalette.Tone,
        theme: AppColorTheme,
        palette: SQLEditorTokenPalette?
    ) {
        let resolved: SQLEditorTokenPalette
        if let palette {
            resolved = palette
        } else if let existing = tokenPalettesByTone[tone] {
            resolved = existing
        } else if let matched = SQLEditorTokenPalette.palette(withID: theme.defaultPaletteID) {
            resolved = matched
        } else if let fallback = SQLEditorTokenPalette.builtIn.first(where: { $0.tone == tone }) {
            resolved = fallback
        } else {
            let base = tone == .dark ? SQLEditorPalette.midnight : SQLEditorPalette.aurora
            resolved = SQLEditorTokenPalette(from: base)
        }

        tokenPalettesByTone[tone] = resolved
        resultGridColorsByTone[tone] = resolved.resultGrid
    }

    private func resultGridColors(for tone: SQLEditorPalette.Tone) -> SQLEditorTokenPalette.ResultGridColors {
        resultGridColorsByTone[tone] ?? SQLEditorTokenPalette.ResultGridColors.defaults(for: tone)
    }

    private var activeResultGridColors: SQLEditorTokenPalette.ResultGridColors {
        resultGridColors(for: activeTone)
    }

    func resultGridStyle(for kind: ResultGridValueKind) -> SQLEditorTokenPalette.ResultGridStyle {
        if useAppThemeForResultsGrid {
            let colors = activeResultGridColors
            switch kind {
            case .null:
                return colors.null
            case .numeric:
                return colors.numeric
            case .boolean:
                return colors.boolean
            case .temporal:
                return colors.temporal
            case .binary:
                return colors.binary
            case .identifier:
                return colors.identifier
            case .json:
                return colors.json
            case .text:
                return SQLEditorTokenPalette.ResultGridStyle(
                    color: ColorRepresentable(color: surfaceForegroundColor),
                    isBold: false,
                    isItalic: false
                )
        }
    } else {
        return fallbackResultGridStyle(for: kind)
    }
}

    private func fallbackResultGridStyle(for kind: ResultGridValueKind) -> SQLEditorTokenPalette.ResultGridStyle {
        switch kind {
        case .null:
#if os(macOS)
            return SQLEditorTokenPalette.ResultGridStyle(
                color: ColorRepresentable(color: Color(nsColor: NSColor.secondaryLabelColor.withAlphaComponent(0.7))),
                isBold: false,
                isItalic: true
            )
#else
            return SQLEditorTokenPalette.ResultGridStyle(
                color: ColorRepresentable(color: Color(uiColor: UIColor.secondaryLabel.withAlphaComponent(0.7))),
                isBold: false,
                isItalic: true
            )
#endif
        case .numeric:
#if os(macOS)
            return SQLEditorTokenPalette.ResultGridStyle(color: ColorRepresentable(color: Color(nsColor: .systemBlue)))
#else
            return SQLEditorTokenPalette.ResultGridStyle(color: ColorRepresentable(color: Color(uiColor: .systemBlue)))
#endif
        case .boolean:
#if os(macOS)
            return SQLEditorTokenPalette.ResultGridStyle(color: ColorRepresentable(color: Color(nsColor: .systemGreen)))
#else
            return SQLEditorTokenPalette.ResultGridStyle(color: ColorRepresentable(color: Color(uiColor: .systemGreen)))
#endif
        case .temporal:
#if os(macOS)
            return SQLEditorTokenPalette.ResultGridStyle(color: ColorRepresentable(color: Color(nsColor: .systemOrange)))
#else
            return SQLEditorTokenPalette.ResultGridStyle(color: ColorRepresentable(color: Color(uiColor: .systemOrange)))
#endif
        case .binary:
#if os(macOS)
            return SQLEditorTokenPalette.ResultGridStyle(color: ColorRepresentable(color: Color(nsColor: .systemPurple)))
#else
            return SQLEditorTokenPalette.ResultGridStyle(color: ColorRepresentable(color: Color(uiColor: .systemPurple)))
#endif
        case .identifier:
#if os(macOS)
            return SQLEditorTokenPalette.ResultGridStyle(color: ColorRepresentable(color: Color(nsColor: .systemIndigo)))
#else
            return SQLEditorTokenPalette.ResultGridStyle(color: ColorRepresentable(color: Color(uiColor: .systemIndigo)))
#endif
        case .json:
#if os(macOS)
            return SQLEditorTokenPalette.ResultGridStyle(color: ColorRepresentable(color: Color(nsColor: .systemTeal)))
#else
            return SQLEditorTokenPalette.ResultGridStyle(color: ColorRepresentable(color: Color(uiColor: .systemTeal)))
#endif
        case .text:
#if os(macOS)
            return SQLEditorTokenPalette.ResultGridStyle(color: ColorRepresentable(color: Color(nsColor: .labelColor)))
#else
            return SQLEditorTokenPalette.ResultGridStyle(color: ColorRepresentable(color: Color(uiColor: .label)))
#endif
        }
    }

    // MARK: - Mutating API

    func applyChrome(theme: AppColorTheme, tone: SQLEditorPalette.Tone, palette: SQLEditorTokenPalette? = nil) {
        themesByTone[tone] = theme
        updateResultGridPalette(for: tone, theme: theme, palette: palette)
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
        if resultGridColorsByTone[tone] == nil {
            updateResultGridPalette(for: tone, theme: theme, palette: nil)
        }

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

    var resultsGridNullTextNSColor: NSColor { resultGridStyle(for: .null).nsColor }
    var resultsGridNumericTextNSColor: NSColor { resultGridStyle(for: .numeric).nsColor }
    var resultsGridBooleanTextNSColor: NSColor { resultGridStyle(for: .boolean).nsColor }
    var resultsGridTemporalTextNSColor: NSColor { resultGridStyle(for: .temporal).nsColor }
    var resultsGridBinaryTextNSColor: NSColor { resultGridStyle(for: .binary).nsColor }
    var resultsGridIdentifierTextNSColor: NSColor { resultGridStyle(for: .identifier).nsColor }
    var resultsGridJSONTextNSColor: NSColor { resultGridStyle(for: .json).nsColor }
#elseif canImport(UIKit)
    var resultsGridAlternateRowUIColor: UIColor {
        guard resultsAlternateRowShading else { return resultsGridBackgroundUIColor }
        return useAppThemeForResultsGrid ? UIColor.systemGray6 : UIColor.secondarySystemBackground
    }

    var resultsGridNullTextUIColor: UIColor { resultGridStyle(for: .null).uiColor }
    var resultsGridNumericTextUIColor: UIColor { resultGridStyle(for: .numeric).uiColor }
    var resultsGridBooleanTextUIColor: UIColor { resultGridStyle(for: .boolean).uiColor }
    var resultsGridTemporalTextUIColor: UIColor { resultGridStyle(for: .temporal).uiColor }
    var resultsGridBinaryTextUIColor: UIColor { resultGridStyle(for: .binary).uiColor }
    var resultsGridIdentifierTextUIColor: UIColor { resultGridStyle(for: .identifier).uiColor }
    var resultsGridJSONTextUIColor: UIColor { resultGridStyle(for: .json).uiColor }
#endif
}
