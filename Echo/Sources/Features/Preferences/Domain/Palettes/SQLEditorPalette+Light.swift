import SwiftUI

extension SQLEditorPalette {
    static let aurora = SQLEditorPalette(
        id: "aurora",
        name: "Aurora",
        kind: .builtIn,
        isDark: false,
        background: ColorRepresentable(hex: 0xFFFFFF),
        text: ColorRepresentable(hex: 0x1E1E1E),
        gutterBackground: ColorRepresentable(hex: 0xF3F4F6),
        gutterText: ColorRepresentable(hex: 0x6D6D6D),
        gutterAccent: ColorRepresentable(hex: 0xD9D9DC),
        selection: ColorRepresentable(hex: 0xCCE8FF, alpha: 0.85),
        currentLine: ColorRepresentable(hex: 0xF3F3F3),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0x0000FF),
            string: ColorRepresentable(hex: 0xA31515),
            number: ColorRepresentable(hex: 0x098658),
            comment: ColorRepresentable(hex: 0x008000),
            plain: ColorRepresentable(hex: 0x1E1E1E),
            function: ColorRepresentable(hex: 0x795E26),
            operatorSymbol: ColorRepresentable(hex: 0x1B1B1B),
            identifier: ColorRepresentable(hex: 0x267F99)
        )
    )
}
