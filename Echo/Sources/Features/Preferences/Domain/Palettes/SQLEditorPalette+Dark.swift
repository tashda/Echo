import SwiftUI

extension SQLEditorPalette {
    static let midnight = SQLEditorPalette(
        id: "midnight",
        name: "Midnight",
        kind: .builtIn,
        isDark: true,
        background: ColorRepresentable(hex: 0x1E1E1E),
        text: ColorRepresentable(hex: 0xD4D4D4),
        gutterBackground: ColorRepresentable(hex: 0x252526),
        gutterText: ColorRepresentable(hex: 0x858585),
        gutterAccent: ColorRepresentable(hex: 0x2D2D30),
        selection: ColorRepresentable(hex: 0x264F78, alpha: 0.9),
        currentLine: ColorRepresentable(hex: 0x2A2A2A),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0xC586C0),
            string: ColorRepresentable(hex: 0xCE9178),
            number: ColorRepresentable(hex: 0xB5CEA8),
            comment: ColorRepresentable(hex: 0x6A9955),
            plain: ColorRepresentable(hex: 0xD4D4D4),
            function: ColorRepresentable(hex: 0xDCDCAA),
            operatorSymbol: ColorRepresentable(hex: 0x569CD6),
            identifier: ColorRepresentable(hex: 0x9CDCFE)
        )
    )
}
