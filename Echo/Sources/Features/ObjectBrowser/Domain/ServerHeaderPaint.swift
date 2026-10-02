import SwiftUI

/// How a server's card header is painted (round 30.1), from Settings › Appearance and the
/// server's colour: the header's style and colour, the dock's current icon, and whether the
/// server's colour also marks the rail, its tabs and the footer's server pill (CO2).
struct ServerHeaderPaint: Equatable {
    let style: ServerHeaderStyle
    /// The header's colour; nil with Server Header Color set to None.
    let color: Color?
    /// The dock's current icon: the header's colour (DK1) or the accent.
    let dockColor: Color
    /// True with the server's colour: the rail's monogram is always in it, and the server's tabs
    /// and the footer's server pill carry a dot of it.
    let marksServer: Bool
    /// What the title banner lets the user change (round 53).
    let look: ServerHeaderLook
    /// The type on the banner is dark: Automatic text colour on a light colour (round 53, TC1).
    let usesDarkType: Bool

    init(style: ServerHeaderStyle, source: ServerHeaderColorSource, dockTint: SidebarDockCurrentIconTint,
         serverColor: Color, accent: Color, look: ServerHeaderLook = ServerHeaderLook(), isLightFill: Bool = false) {
        self.style = style
        self.look = look
        usesDarkType = style == .titleBanner && look.textColor == .automatic && source == .server && isLightFill
        switch source {
        case .none: color = nil
        case .server: color = serverColor
        case .accent: color = accent
        }
        dockColor = dockTint == .header ? (color ?? accent) : accent
        marksServer = source == .server
    }

    init(settings: GlobalSettings, serverColor: Color, accent: Color, isLightFill: Bool = false) {
        self.init(style: settings.serverHeaderStyle, source: settings.serverHeaderColorSource,
                  dockTint: settings.sidebarDockCurrentIconTint, serverColor: serverColor, accent: accent,
                  look: settings.serverHeaderLook, isLightFill: isLightFill)
    }

    /// What the wash or banner is painted with: the colour, or grey with None.
    var fill: Color { color ?? ColorTokens.Text.secondary }

    /// The header's text sits on the colour itself (white), not on the card.
    var isOnFill: Bool { style == .banner || style == .titleBanner }

    /// The type on the colour: white, or dark on a light colour with Automatic (round 53).
    var ink: Color { usesDarkType ? ServerHeaderTokens.darkInk : ColorTokens.Text.onFill }

    /// The space above the header's first line while the card is open: 12pt for the other styles,
    /// the chosen spacing's for the title banner (`ServerHeaderMetrics.topInset`).
    var headerTopInset: CGFloat {
        isTitleBanner ? CGFloat(ServerHeaderMetrics(look: look).topInset) : SpacingTokens.sm
    }

    /// The title banner is a banner of its own: the type, the dock's icons and the chevron sit on
    /// it, and the dock has no capsule.
    var isTitleBanner: Bool { style == .titleBanner }
}
