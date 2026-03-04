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

    init(themeManager: ThemeManager, traitCollection: UITraitCollection) {
        let backgroundColor = themeManager.resultsGridBackgroundUIColor.resolvedColor(with: traitCollection)
        let accentColor = UIColor(themeManager.accentColor).resolvedColor(with: traitCollection)
        background = backgroundColor

        if themeManager.useAppThemeForResultsGrid {
            let surfaceBackground = UIColor(themeManager.surfaceBackground).resolvedColor(with: traitCollection)
            let surfaceForeground = UIColor(themeManager.surfaceForeground).resolvedColor(with: traitCollection)
            headerBackground = surfaceBackground
            headerText = surfaceForeground
            primaryText = surfaceForeground
            secondaryText = surfaceForeground.withAlphaComponent(0.7)
        } else {
            headerBackground = UIColor.secondarySystemBackground
            headerText = UIColor.label
            primaryText = UIColor.label
            secondaryText = UIColor.secondaryLabel
        }

        accent = accentColor
        selectionFill = accentColor.withAlphaComponent(0.18)
        columnHighlight = accentColor.withAlphaComponent(0.1)
        rowHighlight = accentColor.withAlphaComponent(0.12)

        if themeManager.resultsAlternateRowShading {
            let alternateBase = themeManager.resultsGridAlternateRowUIColor
            alternateRow = alternateBase.resolvedColor(with: traitCollection)
        } else {
            alternateRow = nil
        }

        if themeManager.useAppThemeForResultsGrid {
            func makeStyle(_ kind: ResultGridValueKind) -> ResultGridTextStyle {
                let style = themeManager.resultGridStyle(for: kind)
                return ResultGridTextStyle(
                    color: UIColor(style.swiftColor).resolvedColor(with: traitCollection),
                    isBold: style.isBold,
                    isItalic: style.isItalic
                )
            }
            dataStyles = [
                .null: makeStyle(.null),
                .numeric: makeStyle(.numeric),
                .boolean: makeStyle(.boolean),
                .temporal: makeStyle(.temporal),
                .binary: makeStyle(.binary),
                .identifier: makeStyle(.identifier),
                .json: makeStyle(.json)
            ]
            defaultDataStyle = makeStyle(.text)
        } else {
            dataStyles = [
                .null: ResultGridTextStyle(color: UIColor.secondaryLabel.withAlphaComponent(0.7), isBold: false, isItalic: true),
                .numeric: ResultGridTextStyle(color: .systemBlue, isBold: false, isItalic: false),
                .boolean: ResultGridTextStyle(color: .systemGreen, isBold: false, isItalic: false),
                .temporal: ResultGridTextStyle(color: .systemOrange, isBold: false, isItalic: false),
                .binary: ResultGridTextStyle(color: .systemPurple, isBold: false, isItalic: false),
                .identifier: ResultGridTextStyle(color: .systemIndigo, isBold: false, isItalic: false),
                .json: ResultGridTextStyle(color: .systemTeal, isBold: false, isItalic: false)
            ]
            defaultDataStyle = ResultGridTextStyle(color: .label, isBold: false, isItalic: false)
        }
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
