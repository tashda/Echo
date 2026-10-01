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

    init(style: ServerHeaderStyle, source: ServerHeaderColorSource, dockTint: SidebarDockCurrentIconTint,
         serverColor: Color, accent: Color) {
        self.style = style
        switch source {
        case .none: color = nil
        case .server: color = serverColor
        case .accent: color = accent
        }
        dockColor = dockTint == .header ? (color ?? accent) : accent
        marksServer = source == .server
    }

    init(settings: GlobalSettings, serverColor: Color, accent: Color) {
        self.init(style: settings.serverHeaderStyle, source: settings.serverHeaderColorSource,
                  dockTint: settings.sidebarDockCurrentIconTint, serverColor: serverColor, accent: accent)
    }

    /// What the wash or banner is painted with: the colour, or grey with None.
    var fill: Color { color ?? ColorTokens.Text.secondary }

    /// The header's text sits on the colour itself (white), not on the card.
    var isOnFill: Bool { style == .banner }
}
