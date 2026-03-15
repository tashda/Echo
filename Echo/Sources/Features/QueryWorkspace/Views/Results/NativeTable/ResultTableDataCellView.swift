#if os(macOS)
import AppKit

final class ResultTableDataCellView: NSTableCellView {
    let contentTextField: NSTextField
    private var actionButton: NSButton?
    private var actionHandler: (() -> Void)?
    private var isIconVisible = false
    private var currentTextColor: NSColor = .labelColor
    private var textTrailingConstraint: NSLayoutConstraint!

    override init(frame frameRect: NSRect) {
        contentTextField = NSTextField(frame: .zero)
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        contentTextField = NSTextField(frame: .zero)
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        contentTextField.isEditable = false
        contentTextField.isSelectable = false
        contentTextField.isBordered = false
        contentTextField.drawsBackground = false
        contentTextField.focusRingType = .none
        contentTextField.wantsLayer = true
        if let layer = contentTextField.layer {
            layer.masksToBounds = true
            layer.cornerRadius = SpacingTokens.xxs2
            layer.cornerCurve = .continuous
        }
        contentTextField.lineBreakMode = .byTruncatingTail
        contentTextField.usesSingleLineMode = true
        contentTextField.maximumNumberOfLines = 1
        contentTextField.alignment = .left
        contentTextField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentTextField)
        textField = contentTextField
        textTrailingConstraint = contentTextField.trailingAnchor.constraint(
            equalTo: trailingAnchor,
            constant: -ResultsGridMetrics.horizontalPadding
        )
        NSLayoutConstraint.activate([
            contentTextField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: ResultsGridMetrics.horizontalPadding),
            contentTextField.centerYAnchor.constraint(equalTo: centerYAnchor),
            textTrailingConstraint
        ])
    }

    func apply(text: String,
               font: NSFont,
               textColor: NSColor) {
        var shouldInvalidateMetrics = false
        if contentTextField.stringValue != text {
            contentTextField.stringValue = text
            shouldInvalidateMetrics = true
        }
        if contentTextField.font !== font {
            contentTextField.font = font
            shouldInvalidateMetrics = true
        }
        if contentTextField.alignment != .left {
            contentTextField.alignment = .left
        }
        if let cell = contentTextField.cell as? VerticallyCenteredTextFieldCell {
            if cell.alignment != .left {
                cell.alignment = .left
                shouldInvalidateMetrics = true
            }
            if shouldInvalidateMetrics {
                cell.invalidateCachedMetrics()
            }
        }
        currentTextColor = textColor
        if contentTextField.textColor != textColor {
            contentTextField.textColor = textColor
        }
    }

    func configureIcon(_ handler: (() -> Void)?) {
        configureIcon(symbolName: "arrow.up.right.square", handler: handler)
    }

    func configureIcon(symbolName: String, handler: (() -> Void)?) {
        actionHandler = handler
        let shouldShow = handler != nil
        if shouldShow, let button = actionButton ?? Optional(createActionButton()) {
            let newImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Inspect")
            if button.image !== newImage { button.image = newImage }
            button.isHidden = false
        }
        guard isIconVisible != shouldShow else { return }
        isIconVisible = shouldShow
        if shouldShow {
            textTrailingConstraint.constant = -(ResultsGridMetrics.horizontalPadding + 18 + SpacingTokens.xxs2)
        } else {
            actionButton?.isHidden = true
            textTrailingConstraint.constant = -ResultsGridMetrics.horizontalPadding
        }
    }

    private func createActionButton() -> NSButton {
        let button = NSButton(frame: .zero)
        button.target = self
        button.action = #selector(handleAction)
        button.isBordered = false
        button.bezelStyle = .inline
        button.image = NSImage(systemSymbolName: "arrow.up.right.square", accessibilityDescription: "Show Inspector")
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .secondaryLabelColor
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)
        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -ResultsGridMetrics.horizontalPadding),
            button.centerYAnchor.constraint(equalTo: centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 18),
            button.heightAnchor.constraint(equalToConstant: 16)
        ])
        actionButton = button
        return button
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        actionHandler = nil
        if isIconVisible {
            isIconVisible = false
            actionButton?.isHidden = true
            textTrailingConstraint.constant = -ResultsGridMetrics.horizontalPadding
        }
    }

    @objc private func handleAction() {
        actionHandler?()
    }
}
#endif
