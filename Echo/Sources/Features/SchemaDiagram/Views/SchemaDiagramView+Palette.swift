import SwiftUI
import EchoSense

extension SchemaDiagramView {
    internal var palette: DiagramPalette {
        let accent = appearanceStore.accentColor
        let foreground = ColorTokens.Text.primary
        let detail = ColorTokens.Text.secondary
        let nodeShadow = Color.black.opacity(colorScheme == .dark ? 0.45 : 0.18)
        let canvasBackground = ColorTokens.Background.primary
        let surfaceBackground = ColorTokens.Background.secondary
        let controlBackground = ColorTokens.Background.tertiary

        if projectStore.globalSettings.diagramUseThemedAppearance {
            return DiagramPalette(
                canvasBackground: canvasBackground,
                gridLine: foreground.opacity(0.12),
                nodeBackground: surfaceBackground.opacity(0.95),
                nodeBorder: foreground.opacity(0.14),
                nodeShadow: nodeShadow,
                headerBackground: accent.opacity(0.22),
                headerBorder: accent.opacity(0.45),
                headerTitle: foreground,
                headerSubtitle: detail,
                columnText: foreground,
                columnDetail: detail,
                columnHighlight: accent.opacity(0.12),
                accent: accent,
                edgeColor: accent.opacity(0.9),
                overlayBackground: surfaceBackground.opacity(0.96),
                overlayBorder: foreground.opacity(0.14)
            )
        } else {
            let shadow = Color.black.opacity(colorScheme == .dark ? 0.5 : 0.16)
            return DiagramPalette(
                canvasBackground: canvasBackground,
                gridLine: foreground.opacity(colorScheme == .dark ? 0.14 : 0.08),
                nodeBackground: controlBackground.opacity(colorScheme == .dark ? 0.85 : 1.0),
                nodeBorder: foreground.opacity(0.12),
                nodeShadow: shadow,
                headerBackground: accent.opacity(0.18),
                headerBorder: accent.opacity(0.35),
                headerTitle: foreground,
                headerSubtitle: detail,
                columnText: foreground,
                columnDetail: detail,
                columnHighlight: accent.opacity(0.08),
                accent: accent.opacity(0.9),
                edgeColor: accent.opacity(0.85),
                overlayBackground: canvasBackground.opacity(0.98),
                overlayBorder: foreground.opacity(0.08)
            )
        }
    }
}
