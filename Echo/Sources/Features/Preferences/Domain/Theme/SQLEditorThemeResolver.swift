import Foundation
import SwiftUI

enum SQLEditorThemeResolver {
    static func resolve(globalSettings: GlobalSettings, project: Project?, tone: SQLEditorPalette.Tone) -> SQLEditorTheme {
        FontRegistrar.registerBundledFonts()

        let tokenPalette = resolveTokenPalette(globalSettings: globalSettings, project: project, tone: tone)
        let basePalette = resolveSurfacePalette(globalSettings: globalSettings, tone: tone)

        let projectFontName = sanitizedFontName(project?.settings.editorFontFamily)
        let globalFontName = sanitizedFontName(globalSettings.defaultEditorFontFamily)
        let fontName = projectFontName ?? globalFontName ?? SQLEditorTheme.defaultFontName
        let fontSizeValue = project?.settings.editorFontSize ?? globalSettings.defaultEditorFontSize
        let lineHeightValue = project?.settings.editorLineHeight ?? globalSettings.defaultEditorLineHeight

        let fontSize = max(8, CGFloat(fontSizeValue))
        let lineHeight = max(1.0, CGFloat(lineHeightValue))

        let strongHighlight = SQLEditorTokenPalette.defaultSymbolHighlightStrong(
            selection: basePalette.selection,
            accent: nil,
            background: basePalette.background,
            isDark: tone == .dark
        )
        let brightHighlight = SQLEditorTokenPalette.defaultSymbolHighlightBright(
            selection: basePalette.selection,
            accent: nil,
            background: basePalette.background,
            isDark: tone == .dark
        )

        let surfaces = SQLEditorSurfaceColors(
            background: basePalette.background,
            text: basePalette.text,
            gutterBackground: basePalette.gutterBackground,
            gutterText: basePalette.gutterText,
            gutterAccent: basePalette.gutterAccent,
            selection: basePalette.selection,
            currentLine: basePalette.currentLine,
            symbolHighlightStrong: strongHighlight,
            symbolHighlightBright: brightHighlight
        )

        return SQLEditorTheme(
            fontName: fontName,
            fontSize: fontSize,
            lineHeightMultiplier: lineHeight,
            ligaturesEnabled: globalSettings.ligaturesEnabled(for: fontName),
            surfaces: surfaces,
            tokenPalette: tokenPalette
        )
    }

    static func resolveDisplayOptions(globalSettings: GlobalSettings, project _: Project?) -> SQLEditorDisplayOptions {
        SQLEditorDisplayOptions(
            showLineNumbers: globalSettings.editorShowLineNumbers,
            highlightSelectedSymbol: globalSettings.editorHighlightSelectedSymbol,
            highlightDelay: clamped(globalSettings.editorHighlightDelay, min: 0.0, max: 5.0),
            wrapLines: globalSettings.editorWrapLines,
            indentWrappedLines: max(0, globalSettings.editorIndentWrappedLines),
            autoCompletionEnabled: globalSettings.editorEnableAutocomplete,
            qualifyTableCompletions: globalSettings.editorQualifyTableCompletions,
            showSystemSchemasInCompletion: globalSettings.editorShowSystemSchemas
        )
    }

    private static func resolveSurfacePalette(globalSettings: GlobalSettings, tone: SQLEditorPalette.Tone) -> SQLEditorPalette {
        let paletteID = tone == .light ? globalSettings.defaultEditorPaletteIDLight : globalSettings.defaultEditorPaletteIDDark
        if let palette = SQLEditorPalette.palette(withID: paletteID) {
            return palette
        }
        return tone == .dark ? SQLEditorPalette.midnight : SQLEditorPalette.aurora
    }

    private static func resolveTokenPalette(globalSettings: GlobalSettings, project _: Project?, tone: SQLEditorPalette.Tone) -> SQLEditorTokenPalette {
        if let palette = globalSettings.defaultPalette(for: tone) {
            return palette
        }

        let alternateTone: SQLEditorPalette.Tone = tone == .light ? .dark : .light
        if let palette = globalSettings.defaultPalette(for: alternateTone) {
            return palette
        }

        if let legacy = palette(withID: globalSettings.defaultEditorTheme, globalSettings: globalSettings) {
            return legacy
        }

        let fallback = tone == .dark ? SQLEditorPalette.midnight : SQLEditorPalette.aurora
        return SQLEditorTokenPalette(from: fallback)
    }

    private static func sanitizedFontName(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        switch trimmed {
        case SQLEditorTheme.systemFontIdentifier, "System", "system", "MonospacedSystem", ".monospacedSystemFont", ".SystemMonospaced":
            return SQLEditorTheme.systemFontIdentifier
        case "IBMPlexMono-Regular":
            return "IBMPlexMono"
        case "Iosevka-Regular":
            return "Iosevka"
        default:
            return trimmed
        }
    }

    static func normalizedFontName(_ value: String?) -> String {
        sanitizedFontName(value) ?? SQLEditorTheme.defaultFontName
    }

    private static func palette(withID id: String, globalSettings: GlobalSettings) -> SQLEditorTokenPalette? {
        if let custom = globalSettings.customEditorPalettes.first(where: { $0.id == id }) {
            return custom
        }

        return SQLEditorTokenPalette.builtIn.first(where: { $0.id == id })
    }

    private static func clamped(_ value: Double, min: Double, max: Double) -> Double {
        if value < min { return min }
        if value > max { return max }
        return value
    }
}
