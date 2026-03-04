import Foundation
import SwiftUI
import EchoSense

private struct BuiltInThemeDefinition {
    let identifier: String
    let name: String
    let tone: SQLEditorPalette.Tone
    let defaultPaletteID: String
    let accent: ColorRepresentable
    let windowBackground: ColorRepresentable
    let surfaceBackground: ColorRepresentable
    let surfaceForeground: ColorRepresentable
    let swatches: [ColorRepresentable]?

    func makeTheme(fallbackPaletteID: String) -> AppColorTheme {
        let palette = SQLEditorPalette.palette(withID: defaultPaletteID)
            ?? SQLEditorPalette.palette(withID: fallbackPaletteID)
            ?? (tone == .dark ? SQLEditorPalette.midnight : SQLEditorPalette.aurora)

        let strongHighlight = SQLEditorTokenPalette.defaultSymbolHighlightStrong(
            selection: palette.selection,
            accent: accent,
            background: palette.background,
            isDark: tone == .dark
        )

        let brightHighlight = SQLEditorTokenPalette.defaultSymbolHighlightBright(
            selection: palette.selection,
            accent: accent,
            background: palette.background,
            isDark: tone == .dark
        )

        let defaultSwatches = [
            accent,
            palette.tokens.keyword.color,
            palette.tokens.string.color,
            palette.tokens.operatorSymbol.color,
            palette.tokens.comment.color
        ]

        return AppColorTheme(
            id: "builtin-\(identifier)-\(tone.rawValue)",
            name: name,
            tone: tone,
            defaultPaletteID: palette.id,
            isCustom: false,
            accent: accent,
            swatchColors: swatches ?? defaultSwatches,
            windowBackground: windowBackground,
            surfaceBackground: surfaceBackground,
            surfaceForeground: surfaceForeground,
            editorBackground: palette.background,
            editorForeground: palette.text,
            editorGutterBackground: palette.gutterBackground,
            editorGutterForeground: palette.gutterText,
            editorSelection: palette.selection,
            editorCurrentLine: palette.currentLine,
            editorSymbolHighlightStrong: strongHighlight,
            editorSymbolHighlightBright: brightHighlight
        )
    }
}

extension AppColorTheme {
    private static let builtInThemeCatalog: [BuiltInThemeDefinition] = [
        BuiltInThemeDefinition(
            identifier: "echo",
            name: "Echo Light",
            tone: .light,
            defaultPaletteID: SQLEditorPalette.echoLight.id,
            accent: ColorRepresentable(hex: 0x0A84FF),
            windowBackground: ColorRepresentable(hex: 0xFFFFFF),
            surfaceBackground: ColorRepresentable(hex: 0xFFFFFF),
            surfaceForeground: ColorRepresentable(hex: 0x1C1C1E),
            swatches: [
                ColorRepresentable(hex: 0x0A84FF),
                ColorRepresentable(hex: 0x30D158),
                ColorRepresentable(hex: 0xFF9F0A),
                ColorRepresentable(hex: 0xFF375F),
                ColorRepresentable(hex: 0x8E8E93)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "default",
            name: "Light+",
            tone: .light,
            defaultPaletteID: SQLEditorPalette.aurora.id,
            accent: ColorRepresentable(hex: 0x007ACC),
            windowBackground: ColorRepresentable(hex: 0xF5F7FE),
            surfaceBackground: ColorRepresentable(hex: 0xFFFFFF),
            surfaceForeground: ColorRepresentable(hex: 0x1F2329),
            swatches: [
                ColorRepresentable(hex: 0x007ACC),
                ColorRepresentable(hex: 0x1F6FEB),
                ColorRepresentable(hex: 0xD83B01),
                ColorRepresentable(hex: 0x117E67),
                ColorRepresentable(hex: 0x5E6A7D)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "sunrise",
            name: "Solarized Light",
            tone: .light,
            defaultPaletteID: SQLEditorPalette.solstice.id,
            accent: ColorRepresentable(hex: 0x268BD2),
            windowBackground: ColorRepresentable(hex: 0xFDF6E3),
            surfaceBackground: ColorRepresentable(hex: 0xFFFDF0),
            surfaceForeground: ColorRepresentable(hex: 0x586E75),
            swatches: [
                ColorRepresentable(hex: 0x268BD2),
                ColorRepresentable(hex: 0x2AA198),
                ColorRepresentable(hex: 0xB58900),
                ColorRepresentable(hex: 0xCB4B16),
                ColorRepresentable(hex: 0x6C71C4)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "meadow",
            name: "Catppuccin Latte",
            tone: .light,
            defaultPaletteID: SQLEditorPalette.catppuccinLatte.id,
            accent: ColorRepresentable(hex: 0x7287FD),
            windowBackground: ColorRepresentable(hex: 0xF4F1FB),
            surfaceBackground: ColorRepresentable(hex: 0xFFFFFF),
            surfaceForeground: ColorRepresentable(hex: 0x4C4F69),
            swatches: [
                ColorRepresentable(hex: 0x7287FD),
                ColorRepresentable(hex: 0x40A02B),
                ColorRepresentable(hex: 0xDF8E1D),
                ColorRepresentable(hex: 0xE64553),
                ColorRepresentable(hex: 0x179299)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "slate",
            name: "GitHub Light",
            tone: .light,
            defaultPaletteID: SQLEditorPalette.githubLight.id,
            accent: ColorRepresentable(hex: 0x0969DA),
            windowBackground: ColorRepresentable(hex: 0xF6F8FA),
            surfaceBackground: ColorRepresentable(hex: 0xFFFFFF),
            surfaceForeground: ColorRepresentable(hex: 0x1F2328),
            swatches: [
                ColorRepresentable(hex: 0x0969DA),
                ColorRepresentable(hex: 0x1F2328),
                ColorRepresentable(hex: 0x953800),
                ColorRepresentable(hex: 0x116329),
                ColorRepresentable(hex: 0x6E7781)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "cascade",
            name: "Nord Snow",
            tone: .light,
            defaultPaletteID: SQLEditorPalette.orchard.id,
            accent: ColorRepresentable(hex: 0x5E81AC),
            windowBackground: ColorRepresentable(hex: 0xE5EEF6),
            surfaceBackground: ColorRepresentable(hex: 0xFFFFFF),
            surfaceForeground: ColorRepresentable(hex: 0x2E3440),
            swatches: [
                ColorRepresentable(hex: 0x5E81AC),
                ColorRepresentable(hex: 0x88C0D0),
                ColorRepresentable(hex: 0xA3BE8C),
                ColorRepresentable(hex: 0xBF616A),
                ColorRepresentable(hex: 0xEBCB8B)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "pearl",
            name: "One Light",
            tone: .light,
            defaultPaletteID: SQLEditorPalette.paperwhite.id,
            accent: ColorRepresentable(hex: 0x7C61C9),
            windowBackground: ColorRepresentable(hex: 0xF8F9FF),
            surfaceBackground: ColorRepresentable(hex: 0xFFFFFF),
            surfaceForeground: ColorRepresentable(hex: 0x2B2D33),
            swatches: [
                ColorRepresentable(hex: 0x7C61C9),
                ColorRepresentable(hex: 0x50A14F),
                ColorRepresentable(hex: 0x986801),
                ColorRepresentable(hex: 0x0184BC),
                ColorRepresentable(hex: 0xE45649)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "harbor",
            name: "Sea Breeze",
            tone: .light,
            defaultPaletteID: SQLEditorPalette.seaBreeze.id,
            accent: ColorRepresentable(hex: 0x0EA5E9),
            windowBackground: ColorRepresentable(hex: 0xEFF6FF),
            surfaceBackground: ColorRepresentable(hex: 0xFFFFFF),
            surfaceForeground: ColorRepresentable(hex: 0x10203A),
            swatches: [
                ColorRepresentable(hex: 0x0EA5E9),
                ColorRepresentable(hex: 0x22D3EE),
                ColorRepresentable(hex: 0x1E8B6F),
                ColorRepresentable(hex: 0x0A75C2),
                ColorRepresentable(hex: 0x94A3B8)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "citrus",
            name: "Monokai Daybreak",
            tone: .light,
            defaultPaletteID: SQLEditorPalette.emberLight.id,
            accent: ColorRepresentable(hex: 0xFC9867),
            windowBackground: ColorRepresentable(hex: 0xFFF4EB),
            surfaceBackground: ColorRepresentable(hex: 0xFFFFFF),
            surfaceForeground: ColorRepresentable(hex: 0x2F2117),
            swatches: [
                ColorRepresentable(hex: 0xFC9867),
                ColorRepresentable(hex: 0xFFD866),
                ColorRepresentable(hex: 0xA9DC76),
                ColorRepresentable(hex: 0x78DCE8),
                ColorRepresentable(hex: 0xAB9DF2)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "evergreen",
            name: "Quiet Light",
            tone: .light,
            defaultPaletteID: SQLEditorPalette.aurora.id,
            accent: ColorRepresentable(hex: 0x3B76F6),
            windowBackground: ColorRepresentable(hex: 0xF7F8FC),
            surfaceBackground: ColorRepresentable(hex: 0xFFFFFF),
            surfaceForeground: ColorRepresentable(hex: 0x1F2933),
            swatches: [
                ColorRepresentable(hex: 0x3B76F6),
                ColorRepresentable(hex: 0x60A5FA),
                ColorRepresentable(hex: 0x1F6FEB),
                ColorRepresentable(hex: 0x2A5CBF),
                ColorRepresentable(hex: 0x6B7280)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "tahoe",
            name: "Tahoe",
            tone: .light,
            defaultPaletteID: SQLEditorPalette.aurora.id,
            accent: ColorRepresentable(hex: 0x2F5FFF),
            windowBackground: ColorRepresentable(hex: 0xEEF3FF),
            surfaceBackground: ColorRepresentable(hex: 0xFFFFFF),
            surfaceForeground: ColorRepresentable(hex: 0x0F1A2B),
            swatches: [
                ColorRepresentable(hex: 0x2F5FFF),
                ColorRepresentable(hex: 0x2563EB),
                ColorRepresentable(hex: 0x38BDF8),
                ColorRepresentable(hex: 0x60A5FA),
                ColorRepresentable(hex: 0x0F172A)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "default",
            name: "Dark+",
            tone: .dark,
            defaultPaletteID: SQLEditorPalette.midnight.id,
            accent: ColorRepresentable(hex: 0x569CD6),
            windowBackground: ColorRepresentable(hex: 0x1E1E1E),
            surfaceBackground: ColorRepresentable(hex: 0x252526),
            surfaceForeground: ColorRepresentable(hex: 0xD4D4D4),
            swatches: [
                ColorRepresentable(hex: 0x569CD6),
                ColorRepresentable(hex: 0xCE9178),
                ColorRepresentable(hex: 0xC586C0),
                ColorRepresentable(hex: 0xB5CEA8),
                ColorRepresentable(hex: 0x6A9955)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "echo",
            name: "Echo Dark",
            tone: .dark,
            defaultPaletteID: SQLEditorPalette.echoDark.id,
            accent: ColorRepresentable(hex: 0x0A84FF),
            windowBackground: ColorRepresentable(hex: 0x12131B),
            surfaceBackground: ColorRepresentable(hex: 0x1D1E27),
            surfaceForeground: ColorRepresentable(hex: 0xF2F2F7),
            swatches: [
                ColorRepresentable(hex: 0x0A84FF),
                ColorRepresentable(hex: 0x30D158),
                ColorRepresentable(hex: 0xFF9F0A),
                ColorRepresentable(hex: 0xFF453A),
                ColorRepresentable(hex: 0xAEAEB2)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "neon",
            name: "Dracula",
            tone: .dark,
            defaultPaletteID: SQLEditorPalette.dracula.id,
            accent: ColorRepresentable(hex: 0xFF79C6),
            windowBackground: ColorRepresentable(hex: 0x1E1F2A),
            surfaceBackground: ColorRepresentable(hex: 0x282A36),
            surfaceForeground: ColorRepresentable(hex: 0xF8F8F2),
            swatches: [
                ColorRepresentable(hex: 0xFF79C6),
                ColorRepresentable(hex: 0x50FA7B),
                ColorRepresentable(hex: 0xBD93F9),
                ColorRepresentable(hex: 0xFFB86C),
                ColorRepresentable(hex: 0x8BE9FD)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "aurora",
            name: "Night Owl",
            tone: .dark,
            defaultPaletteID: SQLEditorPalette.nebulaNight.id,
            accent: ColorRepresentable(hex: 0x82AAFF),
            windowBackground: ColorRepresentable(hex: 0x0B1D32),
            surfaceBackground: ColorRepresentable(hex: 0x15243B),
            surfaceForeground: ColorRepresentable(hex: 0xD6DEEB),
            swatches: [
                ColorRepresentable(hex: 0x82AAFF),
                ColorRepresentable(hex: 0x7DE2CF),
                ColorRepresentable(hex: 0xF6C177),
                ColorRepresentable(hex: 0x5E6A85),
                ColorRepresentable(hex: 0x9F7BFF)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "carbon",
            name: "Carbon",
            tone: .dark,
            defaultPaletteID: SQLEditorPalette.charcoal.id,
            accent: ColorRepresentable(hex: 0x64A9F6),
            windowBackground: ColorRepresentable(hex: 0x12131C),
            surfaceBackground: ColorRepresentable(hex: 0x181B24),
            surfaceForeground: ColorRepresentable(hex: 0xD8DEE6),
            swatches: [
                ColorRepresentable(hex: 0x64A9F6),
                ColorRepresentable(hex: 0x4BD0A0),
                ColorRepresentable(hex: 0xF2A65A),
                ColorRepresentable(hex: 0xF5546B),
                ColorRepresentable(hex: 0x8AD1FF)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "obsidian",
            name: "One Dark",
            tone: .dark,
            defaultPaletteID: SQLEditorPalette.oneDark.id,
            accent: ColorRepresentable(hex: 0x61AFEF),
            windowBackground: ColorRepresentable(hex: 0x22262E),
            surfaceBackground: ColorRepresentable(hex: 0x282C34),
            surfaceForeground: ColorRepresentable(hex: 0xABB2BF),
            swatches: [
                ColorRepresentable(hex: 0x61AFEF),
                ColorRepresentable(hex: 0x98C379),
                ColorRepresentable(hex: 0xC678DD),
                ColorRepresentable(hex: 0xE06C75),
                ColorRepresentable(hex: 0xE5C07B)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "lunar",
            name: "Nord",
            tone: .dark,
            defaultPaletteID: SQLEditorPalette.nord.id,
            accent: ColorRepresentable(hex: 0x88C0D0),
            windowBackground: ColorRepresentable(hex: 0x1F242E),
            surfaceBackground: ColorRepresentable(hex: 0x2E3440),
            surfaceForeground: ColorRepresentable(hex: 0xECEFF4),
            swatches: [
                ColorRepresentable(hex: 0x88C0D0),
                ColorRepresentable(hex: 0x5E81AC),
                ColorRepresentable(hex: 0x8FBCBB),
                ColorRepresentable(hex: 0xA3BE8C),
                ColorRepresentable(hex: 0xBF616A)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "velvet",
            name: "Tokyo Night",
            tone: .dark,
            defaultPaletteID: SQLEditorPalette.violetStorm.id,
            accent: ColorRepresentable(hex: 0x7AA2F7),
            windowBackground: ColorRepresentable(hex: 0x161725),
            surfaceBackground: ColorRepresentable(hex: 0x1A1B26),
            surfaceForeground: ColorRepresentable(hex: 0xA9B1D6),
            swatches: [
                ColorRepresentable(hex: 0x7AA2F7),
                ColorRepresentable(hex: 0x9ECE6A),
                ColorRepresentable(hex: 0xF78C6C),
                ColorRepresentable(hex: 0x2AC3DE),
                ColorRepresentable(hex: 0xC099FF)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "ember",
            name: "Monokai",
            tone: .dark,
            defaultPaletteID: SQLEditorPalette.emberDark.id,
            accent: ColorRepresentable(hex: 0xF92672),
            windowBackground: ColorRepresentable(hex: 0x201F1F),
            surfaceBackground: ColorRepresentable(hex: 0x272822),
            surfaceForeground: ColorRepresentable(hex: 0xF8F8F2),
            swatches: [
                ColorRepresentable(hex: 0xF92672),
                ColorRepresentable(hex: 0xA6E22E),
                ColorRepresentable(hex: 0x66D9EF),
                ColorRepresentable(hex: 0xFD971F),
                ColorRepresentable(hex: 0xE6DB74)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "noir",
            name: "Catppuccin Mocha",
            tone: .dark,
            defaultPaletteID: SQLEditorPalette.catppuccinMocha.id,
            accent: ColorRepresentable(hex: 0xCBA6F7),
            windowBackground: ColorRepresentable(hex: 0x171727),
            surfaceBackground: ColorRepresentable(hex: 0x1E1E2E),
            surfaceForeground: ColorRepresentable(hex: 0xCDD6F4),
            swatches: [
                ColorRepresentable(hex: 0xCBA6F7),
                ColorRepresentable(hex: 0xA6E3A1),
                ColorRepresentable(hex: 0xF5C2E7),
                ColorRepresentable(hex: 0x94E2D5),
                ColorRepresentable(hex: 0x89B4FA)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "dusk",
            name: "Solarized Dark",
            tone: .dark,
            defaultPaletteID: SQLEditorPalette.solarizedDark.id,
            accent: ColorRepresentable(hex: 0x268BD2),
            windowBackground: ColorRepresentable(hex: 0x001F27),
            surfaceBackground: ColorRepresentable(hex: 0x002B36),
            surfaceForeground: ColorRepresentable(hex: 0x93A1A1),
            swatches: [
                ColorRepresentable(hex: 0x268BD2),
                ColorRepresentable(hex: 0x2AA198),
                ColorRepresentable(hex: 0xB58900),
                ColorRepresentable(hex: 0xCB4B16),
                ColorRepresentable(hex: 0x859900)
            ]
        )
    ]

    static func builtInThemes(for tone: SQLEditorPalette.Tone) -> [AppColorTheme] {
        let fallbackPaletteID = tone == .light ? SQLEditorPalette.aurora.id : SQLEditorPalette.midnight.id
        return builtInThemeCatalog
            .filter { $0.tone == tone }
            .map { $0.makeTheme(fallbackPaletteID: fallbackPaletteID) }
    }

    static func fallbackTheme(for tone: SQLEditorPalette.Tone, defaultPaletteID: String, themeID: AppColorTheme.ID? = nil) -> AppColorTheme {
        if let themeID,
           let idMatch = builtInThemes(for: tone).first(where: { $0.id == themeID }) {
            return idMatch
        }
        if let builtInMatch = builtInThemes(for: tone).first(where: { $0.defaultPaletteID == defaultPaletteID }) {
            return builtInMatch
        }
        if let palette = SQLEditorPalette.palette(withID: defaultPaletteID) {
            return AppColorTheme.fromPalette(palette, idOverride: "builtin-\(palette.id)", isCustom: false)
        }
        return tone == .dark ? AppColorTheme.fromPalette(.midnight) : AppColorTheme.fromPalette(.aurora)
    }
}
