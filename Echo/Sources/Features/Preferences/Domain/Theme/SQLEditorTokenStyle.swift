import SwiftUI

extension SQLEditorPalette {
    struct TokenStyle: Codable, Equatable, Hashable {
        var color: ColorRepresentable
        var isBold: Bool
        var isItalic: Bool

        init(color: ColorRepresentable, isBold: Bool = false, isItalic: Bool = false) {
            self.color = color
            self.isBold = isBold
            self.isItalic = isItalic
        }

        init(from decoder: Decoder) throws {
            if let single = try? decoder.singleValueContainer(),
               let color = try? single.decode(ColorRepresentable.self) {
                self.init(color: color)
                return
            }

            let container = try decoder.container(keyedBy: CodingKeys.self)
            let color = try container.decode(ColorRepresentable.self, forKey: .color)
            let isBold = try container.decodeIfPresent(Bool.self, forKey: .isBold) ?? false
            let isItalic = try container.decodeIfPresent(Bool.self, forKey: .isItalic) ?? false
            self.init(color: color, isBold: isBold, isItalic: isItalic)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(color, forKey: .color)
            if isBold {
                try container.encode(isBold, forKey: .isBold)
            }
            if isItalic {
                try container.encode(isItalic, forKey: .isItalic)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case color
            case isBold
            case isItalic
        }

        var swiftColor: Color { color.color }

#if os(macOS)
        var nsColor: NSColor { color.nsColor }
#else
        var uiColor: UIColor { color.uiColor }
#endif

        func platformFont(from base: PlatformFont) -> PlatformFont {
#if os(macOS)
            var traits: NSFontTraitMask = []
            if isBold {
                traits.insert(.boldFontMask)
            }
            if isItalic {
                traits.insert(.italicFontMask)
            }
            guard !traits.isEmpty else { return base }
            return NSFontManager.shared.convert(base, toHaveTrait: traits)
#else
            var traits = base.fontDescriptor.symbolicTraits
            if isBold {
                traits.insert(.traitBold)
            }
            if isItalic {
                traits.insert(.traitItalic)
            }
            guard let descriptor = base.fontDescriptor.withSymbolicTraits(traits) else {
                return base
            }
            return UIFont(descriptor: descriptor, size: base.pointSize)
#endif
        }

        func swiftUIFont(from base: PlatformFont) -> Font {
#if os(macOS)
            Font(platformFont(from: base))
#else
            Font(platformFont(from: base))
#endif
        }
    }

    struct TokenColors: Codable, Equatable, Hashable {
        var keyword: TokenStyle
        var string: TokenStyle
        var number: TokenStyle
        var comment: TokenStyle
        var plain: TokenStyle
        var function: TokenStyle
        var operatorSymbol: TokenStyle
        var identifier: TokenStyle

        private enum CodingKeys: String, CodingKey {
            case keyword
            case primaryKeyword
            case secondaryKeyword
            case string
            case number
            case comment
            case plain
            case function
            case operatorSymbol
            case identifier
        }

        init(
            keyword: TokenStyle,
            string: TokenStyle,
            number: TokenStyle,
            comment: TokenStyle,
            plain: TokenStyle,
            function: TokenStyle,
            operatorSymbol: TokenStyle,
            identifier: TokenStyle
        ) {
            self.keyword = keyword
            self.string = string
            self.number = number
            self.comment = comment
            self.plain = plain
            self.function = function
            self.operatorSymbol = operatorSymbol
            self.identifier = identifier
        }

        init(
            keyword: ColorRepresentable,
            string: ColorRepresentable,
            number: ColorRepresentable,
            comment: ColorRepresentable,
            plain: ColorRepresentable,
            function: ColorRepresentable,
            operatorSymbol: ColorRepresentable,
            identifier: ColorRepresentable
        ) {
            self.init(
                keyword: TokenStyle(color: keyword, isBold: true),
                string: TokenStyle(color: string),
                number: TokenStyle(color: number),
                comment: TokenStyle(color: comment),
                plain: TokenStyle(color: plain),
                function: TokenStyle(color: function),
                operatorSymbol: TokenStyle(color: operatorSymbol),
                identifier: TokenStyle(color: identifier)
            )
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let explicit = try container.decodeIfPresent(TokenStyle.self, forKey: .keyword) {
                keyword = explicit
            } else if let legacyPrimary = try container.decodeIfPresent(ColorRepresentable.self, forKey: .primaryKeyword) {
                keyword = TokenStyle(color: legacyPrimary, isBold: true)
            } else if let legacySecondary = try container.decodeIfPresent(ColorRepresentable.self, forKey: .secondaryKeyword) {
                keyword = TokenStyle(color: legacySecondary, isBold: true)
            } else {
                keyword = TokenStyle(color: ColorRepresentable(hex: 0x3367D6), isBold: true)
            }

            string = try container.decode(TokenStyle.self, forKey: .string)
            number = try container.decode(TokenStyle.self, forKey: .number)
            comment = try container.decode(TokenStyle.self, forKey: .comment)
            plain = try container.decode(TokenStyle.self, forKey: .plain)
            function = try container.decode(TokenStyle.self, forKey: .function)
            operatorSymbol = try container.decode(TokenStyle.self, forKey: .operatorSymbol)
            identifier = try container.decode(TokenStyle.self, forKey: .identifier)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(keyword, forKey: .keyword)
            try container.encode(string, forKey: .string)
            try container.encode(number, forKey: .number)
            try container.encode(comment, forKey: .comment)
            try container.encode(plain, forKey: .plain)
            try container.encode(function, forKey: .function)
            try container.encode(operatorSymbol, forKey: .operatorSymbol)
            try container.encode(identifier, forKey: .identifier)
        }
    }
}

extension SQLEditorPalette.TokenStyle {
    init(color: Color, isBold: Bool = false, isItalic: Bool = false) {
        self.init(color: ColorRepresentable(color: color), isBold: isBold, isItalic: isItalic)
    }

    func withColor(_ color: Color) -> SQLEditorPalette.TokenStyle {
        SQLEditorPalette.TokenStyle(color: ColorRepresentable(color: color), isBold: isBold, isItalic: isItalic)
    }
}
