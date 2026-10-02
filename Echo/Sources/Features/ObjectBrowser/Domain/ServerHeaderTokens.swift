import SwiftUI

/// The title banner header's fixed values (round 53, F5). What the user can change is
/// `ServerHeaderLook`; these stay Echo's.
enum ServerHeaderTokens {
    /// The line over the name: 10pt bold small capitals, tracked out, white at 82%.
    static let eyebrowFont = Font.system(size: 10, weight: .bold)
    static let eyebrowTracking: CGFloat = 1.1
    static let eyebrowOpacity = 0.82
    /// Dark type on a light colour (Automatic): the same black at 82% the lab drew.
    static let darkInk = Color.black.opacity(0.82)
    /// The banner's gradient, top to bottom: the colour at this opacity, then in full.
    static let bannerTopOpacity = 0.92
    /// A hairline of white along the banner's bottom edge (ED1).
    static let hairlineOpacity = 0.35
    static let hairlineWidth: CGFloat = 0.5
    /// The soft fade holds the colour to here, then clears (ED2).
    static let softFadeHold = 0.62
    /// The frosted fade: the colour holds to here, a band of material this tall blurs the end (ED3).
    static let frostedFadeHold = 0.8
    static let frostedBandHeight: CGFloat = SpacingTokens.xl + SpacingTokens.xxs
    /// The dock's icons on the banner: the current one is filled, bold and full; the others medium
    /// at this opacity.
    static let dockIdleOpacity = 0.72
    /// The chevron on the banner.
    static let chevronOpacity = 0.9

    /// The name in the chosen typeface and size, semibold. The size is the user's setting, so it
    /// is built here instead of from the type tokens.
    static func nameFont(_ look: ServerHeaderLook) -> Font {
        let size = look.nameSize.points
        switch look.typeface {
        case .system: return .system(size: size, weight: .semibold)
        case .rounded: return .system(size: size, weight: .semibold, design: .rounded)
        case .serif: return .system(size: size, weight: .semibold, design: .serif)
        case .monospaced: return .system(size: size, weight: .semibold, design: .monospaced)
        case .expanded: return Font.system(size: size, weight: .semibold).width(.expanded)
        }
    }

    /// The dock's icon size on the banner, following the sidebar size (15pt at the default).
    static func dockIconSize(for density: SidebarDensity) -> CGFloat {
        switch density {
        case .compact: 13
        case .small: 14
        case .medium: 15
        case .large: 16
        }
    }
}
