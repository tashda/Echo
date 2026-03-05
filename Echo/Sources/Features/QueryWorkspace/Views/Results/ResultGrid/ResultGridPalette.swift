#if os(iOS)
import UIKit

struct ResultGridPalette {
    struct ResultGridTextStyle {
        let color: UIColor
        let isBold: Bool
        let isItalic: Bool
    }

    let background: UIColor
    let headerBackground: UIColor
    let headerText: UIColor
    let primaryText: UIColor
    let secondaryText: UIColor
    let accent: UIColor
    let selectionFill: UIColor
    let columnHighlight: UIColor
    let rowHighlight: UIColor
    let alternateRow: UIColor?
    private let dataStyles: [ResultGridValueKind: ResultGridTextStyle]
    private let defaultDataStyle: ResultGridTextStyle

    static let `default` = ResultGridPalette(
        background: .systemBackground,
        headerBackground: .secondarySystemBackground,
        headerText: .label,
        primaryText: .label,
        secondaryText: .secondaryLabel,
        accent: .systemBlue,
        selectionFill: UIColor.systemBlue.withAlphaComponent(0.18),
        columnHighlight: UIColor.systemBlue.withAlphaComponent(0.1),
        rowHighlight: UIColor.systemBlue.withAlphaComponent(0.12),
        alternateRow: UIColor.systemGray6.withAlphaComponent(0.35),
        dataStyles: [
            .null: ResultGridTextStyle(color: .secondaryLabel, isBold: false, isItalic: true),
            .numeric: ResultGridTextStyle(color: .systemBlue, isBold: false, isItalic: false),
            .boolean: ResultGridTextStyle(color: .systemGreen, isBold: false, isItalic: false),
            .temporal: ResultGridTextStyle(color: .systemOrange, isBold: false, isItalic: false),
            .binary: ResultGridTextStyle(color: .systemPurple, isBold: false, isItalic: false),
            .identifier: ResultGridTextStyle(color: .systemIndigo, isBold: false, isItalic: false),
            .json: ResultGridTextStyle(color: .systemTeal, isBold: false, isItalic: false)
        ],
        defaultDataStyle: ResultGridTextStyle(color: .label, isBold: false, isItalic: false)
    )

    init(appearanceStore: AppearanceStore, traitCollection: UITraitCollection) {
        let backgroundColor = UIColor(ColorTokens.Background.tertiary).resolvedColor(with: traitCollection)
        let accentColor = UIColor(appearanceStore.accentColor).resolvedColor(with: traitCollection)
        background = backgroundColor

        let surfaceBg = UIColor(ColorTokens.Background.secondary).resolvedColor(with: traitCollection)
        let surfaceFg = UIColor(ColorTokens.Text.primary).resolvedColor(with: traitCollection)
        headerBackground = surfaceBg
        headerText = surfaceFg
        primaryText = surfaceFg
        secondaryText = surfaceFg.withAlphaComponent(0.7)

        accent = accentColor
        selectionFill = accentColor.withAlphaComponent(0.18)
        columnHighlight = accentColor.withAlphaComponent(0.1)
        rowHighlight = accentColor.withAlphaComponent(0.12)

        alternateRow = nil

        dataStyles = [
            .null: ResultGridTextStyle(color: surfaceFg.withAlphaComponent(0.7), isBold: false, isItalic: true),
            .numeric: ResultGridTextStyle(color: .systemBlue, isBold: false, isItalic: false),
            .boolean: ResultGridTextStyle(color: .systemGreen, isBold: false, isItalic: false),
            .temporal: ResultGridTextStyle(color: .systemOrange, isBold: false, isItalic: false),
            .binary: ResultGridTextStyle(color: .systemPurple, isBold: false, isItalic: false),
            .identifier: ResultGridTextStyle(color: .systemIndigo, isBold: false, isItalic: false),
            .json: ResultGridTextStyle(color: .systemTeal, isBold: false, isItalic: false)
        ]
        defaultDataStyle = ResultGridTextStyle(color: surfaceFg, isBold: false, isItalic: false)
    }

    private init(
        background: UIColor,
        headerBackground: UIColor,
        headerText: UIColor,
        primaryText: UIColor,
        secondaryText: UIColor,
        accent: UIColor,
        selectionFill: UIColor,
        columnHighlight: UIColor,
        rowHighlight: UIColor,
        alternateRow: UIColor?,
        dataStyles: [ResultGridValueKind: ResultGridTextStyle],
        defaultDataStyle: ResultGridTextStyle
    ) {
        self.background = background
        self.headerBackground = headerBackground
        self.headerText = headerText
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.accent = accent
        self.selectionFill = selectionFill
        self.columnHighlight = columnHighlight
        self.rowHighlight = rowHighlight
        self.alternateRow = alternateRow
        self.dataStyles = dataStyles
        self.defaultDataStyle = defaultDataStyle
    }

    private static func mix(color: UIColor, with accent: UIColor, amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        guard color.getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              accent.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else {
            return color.withAlphaComponent(0.9)
        }
        let inverse = 1 - amount
        return UIColor(red: r1 * inverse + r2 * amount,
                       green: g1 * inverse + g2 * amount,
                       blue: b1 * inverse + b2 * amount,
                       alpha: a1)
    }

    func style(for kind: ResultGridValueKind) -> ResultGridTextStyle {
        if let style = dataStyles[kind] {
            return style
        }
        return defaultDataStyle
    }
}
#endif
