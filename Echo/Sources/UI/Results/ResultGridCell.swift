#if os(iOS)
import UIKit

final class ResultGridCell: UICollectionViewCell {
    enum Kind {
        case headerIndex
        case header
        case rowIndex
        case data
    }

    static let reuseIdentifier = "ResultGridCell"

    private let titleLabel = UILabel()
    private let indicatorView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        indicatorView.isHidden = true
        indicatorView.image = nil
    }

    private func configureView() {
        contentView.layer.cornerRadius = 6
        contentView.layer.masksToBounds = false
        contentView.backgroundColor = .clear

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        indicatorView.contentMode = .scaleAspectFit
        indicatorView.isHidden = true

        contentView.addSubview(titleLabel)
        contentView.addSubview(indicatorView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: ResultGridMetrics.cellHorizontalPadding),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            indicatorView.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 4),
            indicatorView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -ResultGridMetrics.cellHorizontalPadding),
            indicatorView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            indicatorView.widthAnchor.constraint(equalToConstant: 12),
            indicatorView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }

    func configure(
        text: String,
        kind: Kind,
        palette: ResultGridPalette,
        isHighlightedColumn: Bool,
        isRowSelected: Bool,
        isCellSelected: Bool,
        sortIndicator: SortIndicator?,
        isNullValue: Bool,
        isAlternateRow: Bool,
        valueKind: ResultGridValueKind = .text
    ) {
        titleLabel.text = text
        titleLabel.textColor = palette.primaryText
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        titleLabel.textAlignment = .left
        indicatorView.isHidden = true

        var background = palette.background

        switch kind {
        case .headerIndex:
            titleLabel.textAlignment = .center
            titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            titleLabel.textColor = palette.headerText.withAlphaComponent(0.9)
            background = palette.headerBackground
        case .header:
            titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            titleLabel.textColor = palette.headerText
            titleLabel.textAlignment = .left
            background = isHighlightedColumn ? palette.columnHighlight : palette.headerBackground
            if let sortIndicator {
                indicatorView.isHidden = false
                let symbolName = sortIndicator == .ascending ? "arrow.up" : "arrow.down"
                indicatorView.image = UIImage(systemName: symbolName)
                indicatorView.tintColor = palette.headerText.withAlphaComponent(0.8)
            }
        case .rowIndex:
            titleLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            titleLabel.textAlignment = .right
            titleLabel.textColor = palette.secondaryText
            background = isRowSelected ? palette.rowHighlight : palette.headerBackground
        case .data:
            titleLabel.textAlignment = .left
            let textStyle = palette.style(for: valueKind)
            titleLabel.font = font(for: textStyle)
            titleLabel.textColor = textStyle.color
            if isCellSelected {
                background = palette.selectionFill
            } else if isHighlightedColumn {
                background = palette.columnHighlight
            } else if isRowSelected {
                background = palette.rowHighlight
            } else if isAlternateRow, let alternate = palette.alternateRow {
                background = alternate
            } else {
                background = palette.background
            }
        }

        contentView.backgroundColor = background
        contentView.layer.borderWidth = isCellSelected ? 1 : 0
        contentView.layer.borderColor = isCellSelected ? palette.accent.withAlphaComponent(0.6).cgColor : UIColor.clear.cgColor
        if isCellSelected {
            titleLabel.textColor = palette.primaryText
        }
    }

    private func font(for style: ResultGridPalette.ResultGridTextStyle) -> UIFont {
        var descriptor = UIFont.systemFont(ofSize: 13, weight: .regular).fontDescriptor
        var traits = descriptor.symbolicTraits
        if style.isBold {
            traits.insert(.traitBold)
        }
        if style.isItalic {
            traits.insert(.traitItalic)
        }
        if let resolved = descriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: resolved, size: 13)
        }
        if style.isBold {
            return UIFont.boldSystemFont(ofSize: 13)
        }
        return UIFont.systemFont(ofSize: 13)
    }
}
#endif
