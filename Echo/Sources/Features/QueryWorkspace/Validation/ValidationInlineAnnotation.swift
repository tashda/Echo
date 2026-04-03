#if os(macOS)
import AppKit

/// Xcode/VS Code-style inline error annotation.
/// Rendered as a compact label with a warning icon, positioned after the end of the affected line.
final class ValidationInlineAnnotation: NSView {
    let diagnostic: SQLDiagnostic

    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")

    private static let annotationFont = NSFont.systemFont(ofSize: 11, weight: .medium)
    private static let horizontalPadding: CGFloat = 6
    private static let verticalPadding: CGFloat = 2
    private static let iconSize: CGFloat = 12
    private static let spacing: CGFloat = 4
    private static let cornerRadius: CGFloat = 4

    init(diagnostic: SQLDiagnostic) {
        self.diagnostic = diagnostic
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        let textSize = label.intrinsicContentSize
        let width = Self.horizontalPadding + Self.iconSize + Self.spacing + textSize.width + Self.horizontalPadding
        let height = max(textSize.height, Self.iconSize) + Self.verticalPadding * 2
        return NSSize(width: width, height: height)
    }

    private func setupViews() {
        wantsLayer = true
        layer?.cornerRadius = Self.cornerRadius

        let backgroundColor: NSColor
        let textColor: NSColor
        let iconColor: NSColor

        switch diagnostic.severity {
        case .error:
            backgroundColor = NSColor(red: 0.95, green: 0.25, blue: 0.25, alpha: 0.12)
            textColor = NSColor(red: 0.90, green: 0.22, blue: 0.22, alpha: 1.0)
            iconColor = textColor
        case .warning:
            backgroundColor = NSColor(red: 1.0, green: 0.75, blue: 0.25, alpha: 0.12)
            textColor = NSColor(red: 0.75, green: 0.55, blue: 0.10, alpha: 1.0)
            iconColor = textColor
        }

        layer?.backgroundColor = backgroundColor.cgColor

        let iconName: String
        switch diagnostic.kind {
        case .syntaxError: iconName = "exclamationmark.circle.fill"
        case .unknownTable: iconName = "tablecells"
        case .unknownSchema: iconName = "folder.badge.questionmark"
        case .unknownColumn: iconName = "text.badge.xmark"
        }

        let icon = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: Self.iconSize, weight: .medium))
        iconView.image = icon
        iconView.contentTintColor = iconColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        label.font = Self.annotationFont
        label.textColor = textColor
        label.stringValue = annotationText
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalPadding),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: Self.iconSize),
            iconView.heightAnchor.constraint(equalToConstant: Self.iconSize),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: Self.spacing),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Self.horizontalPadding),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    private var annotationText: String {
        switch diagnostic.kind {
        case .syntaxError:
            return diagnostic.message
        case .unknownTable:
            return "Unknown table '\(diagnostic.token)'"
        case .unknownSchema:
            return "Unknown schema '\(diagnostic.token)'"
        case .unknownColumn:
            return "Unknown column '\(diagnostic.token)'"
        }
    }
}

#endif
