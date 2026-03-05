import SwiftUI

extension SQLEditorPalette {
    static let builtIn: [SQLEditorPalette] = [
        echoLight,
        aurora,
        solstice,
        githubLight,
        catppuccinLatte,
        emberLight,
        seaBreeze,
        orchard,
        paperwhite,
        echoDark,
        midnight,
        oneDark,
        dracula,
        nord,
        nebulaNight,
        emberDark,
        charcoal,
        catppuccinMocha,
        solarizedDark,
        violetStorm
    ]

    static func palette(withID id: String) -> SQLEditorPalette? {
        builtIn.first { $0.id == id }
    }
}
