#if os(macOS)
import AppKit
import SwiftUI

struct ResultTableHeaderStyle {
    let topColor: NSColor
    let bottomColor: NSColor
    let sheenTopAlpha: CGFloat
    let sheenMidAlpha: CGFloat
    let highlightAlpha: CGFloat
    let borderColor: NSColor
    let separatorColor: CGColor

    @MainActor static func make(for theme: AppearanceStore) -> ResultTableHeaderStyle {
        let headerBg = NSColor(ColorTokens.Background.secondary)
        let baseColor = headerBg.usingColorSpace(.extendedSRGB) ?? headerBg
        let accentColor = theme.accentNSColor.usingColorSpace(.extendedSRGB) ?? theme.accentNSColor
        let isDarkMode = theme.effectiveColorScheme == .dark

        let topBlendFraction: CGFloat = isDarkMode ? 0.12 : 0.08
        let bottomBlendFraction: CGFloat = isDarkMode ? 0.28 : 0.24
        let topBlendColor: NSColor = isDarkMode ? NSColor.white : accentColor
        let bottomBlendColor: NSColor
        if isDarkMode {
            bottomBlendColor = accentColor
        } else if let shadedAccent = accentColor.shadow(withLevel: 0.2) {
            bottomBlendColor = shadedAccent
        } else {
            bottomBlendColor = accentColor
        }

        let topColor = baseColor.blended(withFraction: topBlendFraction, of: topBlendColor) ?? baseColor
        let bottomColor = baseColor.blended(withFraction: bottomBlendFraction, of: bottomBlendColor) ?? baseColor

        let highlightAlpha: CGFloat = isDarkMode ? 0.12 : 0.16
        let sheenTop: CGFloat = isDarkMode ? 0.08 : 0.12
        let sheenMid: CGFloat = isDarkMode ? 0.04 : 0.06
        let borderColor: NSColor
        if isDarkMode {
            borderColor = accentColor.withAlphaComponent(0.5)
        } else if let shadedBase = baseColor.shadow(withLevel: 0.25) {
            borderColor = shadedBase
        } else {
            borderColor = NSColor(ColorTokens.Separator.primary)
        }
        let separatorColor = theme.accentNSColor.withAlphaComponent(isDarkMode ? 0.3 : 0.22).cgColor

        return ResultTableHeaderStyle(
            topColor: topColor,
            bottomColor: bottomColor,
            sheenTopAlpha: sheenTop,
            sheenMidAlpha: sheenMid,
            highlightAlpha: highlightAlpha,
            borderColor: borderColor,
            separatorColor: separatorColor
        )
    }
}
#endif
