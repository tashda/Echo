import SwiftUI

struct SQLEditorPalette: Codable, Equatable, Hashable, Identifiable {
    enum Kind: String, Codable {
        case builtIn
        case custom
    }

    enum Tone: String, Codable, CaseIterable {
        case light
        case dark
    }

    var id: String
    var name: String
    var kind: Kind
    var isDark: Bool
    var background: ColorRepresentable
    var text: ColorRepresentable
    var gutterBackground: ColorRepresentable
    var gutterText: ColorRepresentable
    var gutterAccent: ColorRepresentable
    var selection: ColorRepresentable
    var currentLine: ColorRepresentable
    var tokens: TokenColors

    init(
        id: String,
        name: String,
        kind: Kind,
        isDark: Bool,
        background: ColorRepresentable,
        text: ColorRepresentable,
        gutterBackground: ColorRepresentable,
        gutterText: ColorRepresentable,
        gutterAccent: ColorRepresentable,
        selection: ColorRepresentable,
        currentLine: ColorRepresentable,
        tokens: TokenColors
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.isDark = isDark
        self.background = background
        self.text = text
        self.gutterBackground = gutterBackground
        self.gutterText = gutterText
        self.gutterAccent = gutterAccent
        self.selection = selection
        self.currentLine = currentLine
        self.tokens = tokens
    }
}

extension SQLEditorPalette {
    var tone: Tone { isDark ? .dark : .light }
    var backgroundColor: Color { background.color }
    var textColor: Color { text.color }
    var gutterBackgroundColor: Color { gutterBackground.color }
    var gutterTextColor: Color { gutterText.color }
    var gutterAccentColor: Color { gutterAccent.color }
    var selectionColor: Color { selection.color }
    var currentLineColor: Color { currentLine.color }

    func asCustomCopy(named name: String? = nil) -> SQLEditorPalette {
        SQLEditorPalette(
            id: "custom-" + UUID().uuidString,
            name: name ?? "\(self.name) Copy",
            kind: .custom,
            isDark: isDark,
            background: background,
            text: text,
            gutterBackground: gutterBackground,
            gutterText: gutterText,
            gutterAccent: gutterAccent,
            selection: selection,
            currentLine: currentLine,
            tokens: tokens
        )
    }
}
