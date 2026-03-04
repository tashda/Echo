import SwiftUI

struct SQLEditorTokenPalette: Codable, Equatable, Hashable, Identifiable {
    enum Kind: String, Codable {
        case builtIn
        case custom
    }

    struct ResultGridStyle: Codable, Equatable, Hashable {
        var color: ColorRepresentable
        var isBold: Bool
        var isItalic: Bool

        init(color: ColorRepresentable, isBold: Bool = false, isItalic: Bool = false) {
            self.color = color
            self.isBold = isBold
            self.isItalic = isItalic
        }

        var swiftColor: Color { color.color }

#if os(macOS)
        var nsColor: NSColor { color.nsColor }
#elseif canImport(UIKit)
        var uiColor: UIColor { color.uiColor }
#endif
    }

    struct ResultGridColors: Codable, Equatable, Hashable {
        var null: ResultGridStyle
        var numeric: ResultGridStyle
        var boolean: ResultGridStyle
        var temporal: ResultGridStyle
        var binary: ResultGridStyle
        var identifier: ResultGridStyle
        var json: ResultGridStyle

        static func defaults(for tone: SQLEditorPalette.Tone) -> ResultGridColors {
            switch tone {
            case .light:
                return ResultGridColors(
                    null: ResultGridStyle(color: ColorRepresentable(hex: 0x6B7280, alpha: 0.7), isItalic: true),
                    numeric: ResultGridStyle(color: ColorRepresentable(hex: 0x1D4ED8)),
                    boolean: ResultGridStyle(color: ColorRepresentable(hex: 0x047857)),
                    temporal: ResultGridStyle(color: ColorRepresentable(hex: 0xB45309)),
                    binary: ResultGridStyle(color: ColorRepresentable(hex: 0x7C3AED)),
                    identifier: ResultGridStyle(color: ColorRepresentable(hex: 0x4338CA)),
                    json: ResultGridStyle(color: ColorRepresentable(hex: 0x0F766E))
                )
            case .dark:
                return ResultGridColors(
                    null: ResultGridStyle(color: ColorRepresentable(hex: 0xCBD5F5, alpha: 0.85), isItalic: true),
                    numeric: ResultGridStyle(color: ColorRepresentable(hex: 0x60A5FA)),
                    boolean: ResultGridStyle(color: ColorRepresentable(hex: 0x34D399)),
                    temporal: ResultGridStyle(color: ColorRepresentable(hex: 0xFBBF24)),
                    binary: ResultGridStyle(color: ColorRepresentable(hex: 0xC084FC)),
                    identifier: ResultGridStyle(color: ColorRepresentable(hex: 0xA5B4FF)),
                    json: ResultGridStyle(color: ColorRepresentable(hex: 0x5EEAD4))
                )
            }
        }
    }

    var id: String
    var name: String
    var kind: Kind
    var tone: SQLEditorPalette.Tone
    var tokens: SQLEditorPalette.TokenColors
    var resultGrid: ResultGridColors

    init(
        id: String,
        name: String,
        kind: Kind,
        tone: SQLEditorPalette.Tone,
        tokens: SQLEditorPalette.TokenColors,
        resultGrid: ResultGridColors? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.tone = tone
        self.tokens = tokens
        self.resultGrid = resultGrid ?? ResultGridColors.defaults(for: tone)
    }

    init(from palette: SQLEditorPalette) {
        self.init(
            id: palette.id,
            name: palette.name,
            kind: palette.kind == .custom ? .custom : .builtIn,
            tone: palette.tone,
            tokens: palette.tokens,
            resultGrid: ResultGridColors.defaults(for: palette.tone)
        )
    }

    func asCustomCopy(named name: String? = nil) -> SQLEditorTokenPalette {
        SQLEditorTokenPalette(
            id: "custom-\(UUID().uuidString)",
            name: name ?? "\(self.name) Copy",
            kind: .custom,
            tone: tone,
            tokens: tokens,
            resultGrid: resultGrid
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case tone
        case tokens
        case resultGrid
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        kind = try container.decode(Kind.self, forKey: .kind)
        tone = try container.decode(SQLEditorPalette.Tone.self, forKey: .tone)
        tokens = try container.decode(SQLEditorPalette.TokenColors.self, forKey: .tokens)
        resultGrid = try container.decodeIfPresent(ResultGridColors.self, forKey: .resultGrid)
            ?? ResultGridColors.defaults(for: tone)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(kind, forKey: .kind)
        try container.encode(tone, forKey: .tone)
        try container.encode(tokens, forKey: .tokens)
        try container.encode(resultGrid, forKey: .resultGrid)
    }

    static let builtIn: [SQLEditorTokenPalette] = SQLEditorPalette.builtIn.map { SQLEditorTokenPalette(from: $0) }

    static func palette(withID id: String, customPalettes: [SQLEditorTokenPalette] = []) -> SQLEditorTokenPalette? {
        if let custom = customPalettes.first(where: { $0.id == id }) {
            return custom
        }
        return builtIn.first(where: { $0.id == id })
    }

    static func defaultSymbolHighlightStrong(
        selection: ColorRepresentable,
        accent: ColorRepresentable?,
        background: ColorRepresentable,
        isDark: Bool
    ) -> ColorRepresentable {
        let base = accent ?? selection
        let blend = isDark ? 0.24 : 0.32
        let alpha = isDark ? 0.48 : 0.42
        let tinted = base.blended(with: background, fraction: blend)
        return tinted.withAlpha(alpha)
    }

    static func defaultSymbolHighlightBright(
        selection: ColorRepresentable,
        accent: ColorRepresentable?,
        background: ColorRepresentable,
        isDark: Bool
    ) -> ColorRepresentable {
        let base = accent ?? selection
        let blend = isDark ? 0.55 : 0.68
        let alpha = isDark ? 0.3 : 0.26
        let tinted = base.blended(with: background, fraction: blend)
        return tinted.withAlpha(alpha)
    }
}

extension SQLEditorTokenPalette {
    var showcaseColors: [Color] {
        [
            tokens.keyword.swiftColor,
            tokens.string.swiftColor,
            tokens.operatorSymbol.swiftColor,
            tokens.identifier.swiftColor,
            tokens.comment.swiftColor
        ]
    }

    func style(for kind: ResultGridValueKind) -> SQLEditorTokenPalette.ResultGridStyle {
        switch kind {
        case .null:
            return resultGrid.null
        case .numeric:
            return resultGrid.numeric
        case .boolean:
            return resultGrid.boolean
        case .temporal:
            return resultGrid.temporal
        case .binary:
            return resultGrid.binary
        case .identifier:
            return resultGrid.identifier
        case .json:
            return resultGrid.json
        case .text:
#if os(macOS)
            return SQLEditorTokenPalette.ResultGridStyle(color: ColorRepresentable(color: Color(nsColor: .labelColor)))
#else
            return SQLEditorTokenPalette.ResultGridStyle(color: ColorRepresentable(color: Color(uiColor: .label)))
#endif
        }
    }
}

extension SQLEditorTokenPalette.ResultGridColors {
    func style(for kind: ResultGridValueKind) -> SQLEditorTokenPalette.ResultGridStyle {
        switch kind {
        case .null: return null
        case .numeric: return numeric
        case .boolean: return boolean
        case .temporal: return temporal
        case .binary: return binary
        case .identifier: return identifier
        case .json: return json
        case .text:
#if os(macOS)
            return SQLEditorTokenPalette.ResultGridStyle(color: ColorRepresentable(color: Color(nsColor: .labelColor)))
#else
            return SQLEditorTokenPalette.ResultGridStyle(color: ColorRepresentable(color: Color(uiColor: .label)))
#endif
        }
    }
}
