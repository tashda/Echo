#if os(macOS)
import AppKit

final class ResultTableDataCellView: NSTableCellView {
    let contentTextField: NSTextField
    private let actionButton: NSButton
    private var actionHandler: (() -> Void)?
    private var isIconVisible = false
    private var baseTextColor: NSColor = .labelColor
    private var selectionTextColor: NSColor = .labelColor
    private var isSelectionActive = false
    private var textTrailingToContainerConstraint: NSLayoutConstraint?
    private var textTrailingToButtonConstraint: NSLayoutConstraint?
    private var actionButtonConstraints: [NSLayoutConstraint] = []

    override init(frame frameRect: NSRect) {
        contentTextField = NSTextField(frame: .zero)
        actionButton = NSButton(frame: .zero)
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        contentTextField = NSTextField(frame: .zero)
        actionButton = NSButton(frame: .zero)
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
            layer.cornerRadius = 6
            if #available(macOS 10.15, *) {
                layer.cornerCurve = .continuous
            }
        }
        contentTextField.lineBreakMode = .byTruncatingTail
        contentTextField.usesSingleLineMode = true
        contentTextField.maximumNumberOfLines = 1
        contentTextField.alignment = .left
        contentTextField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentTextField)
        textField = contentTextField
        NSLayoutConstraint.activate([
            contentTextField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: ResultsGridMetrics.horizontalPadding),
            contentTextField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        textTrailingToContainerConstraint = contentTextField.trailingAnchor.constraint(
            equalTo: trailingAnchor,
            constant: -ResultsGridMetrics.horizontalPadding
        )
        textTrailingToContainerConstraint?.isActive = true

        actionButton.target = self
        actionButton.action = #selector(handleAction)
        actionButton.isBordered = false
        actionButton.bezelStyle = .inline
        actionButton.image = NSImage(systemSymbolName: "arrow.up.right.square", accessibilityDescription: "Show Inspector")
        actionButton.imageScaling = .scaleProportionallyDown
        actionButton.contentTintColor = NSColor.secondaryLabelColor
        actionButton.isHidden = true
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(actionButton)
        actionButtonConstraints = [
            actionButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -ResultsGridMetrics.horizontalPadding),
            actionButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: 18),
            actionButton.heightAnchor.constraint(equalToConstant: 16)
        ]
        textTrailingToButtonConstraint = contentTextField.trailingAnchor.constraint(
            equalTo: actionButton.leadingAnchor,
            constant: -6
        )
        updateIconConstraintActivation()
    }

    func apply(text: String,
               font: NSFont,
               baseTextColor: NSColor,
               selectionTextColor: NSColor,
               isSelected: Bool) {
        var shouldInvalidateMetrics = false
        if contentTextField.stringValue != text {
            contentTextField.stringValue = text
            shouldInvalidateMetrics = true
        }
        if contentTextField.font !== font {
            contentTextField.font = font
            shouldInvalidateMetrics = true
        }
        // Ensure left alignment is always enforced
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
        self.baseTextColor = baseTextColor
        self.selectionTextColor = selectionTextColor
        updateSelectionState(isSelected: isSelected, force: true)
    }

    func configureIcon(_ handler: (() -> Void)?) {
        actionHandler = handler
        let shouldShow = handler != nil
        if isIconVisible != shouldShow {
            isIconVisible = shouldShow
            actionButton.isHidden = !shouldShow
            actionButton.isEnabled = shouldShow
            updateIconConstraintActivation()
            needsLayout = true
            needsDisplay = true
        } else {
            actionButton.isEnabled = shouldShow
            updateIconConstraintActivation()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        actionHandler = nil
        configureIcon(nil)
        baseTextColor = .labelColor
        selectionTextColor = .labelColor
        isSelectionActive = false
        contentTextField.textColor = baseTextColor
    }

    @objc private func handleAction() {
        actionHandler?()
    }

    func updateSelectionState(isSelected: Bool) {
        updateSelectionState(isSelected: isSelected, force: false)
    }

    private func updateSelectionState(isSelected: Bool, force: Bool) {
        guard force || isSelectionActive != isSelected else { return }
        isSelectionActive = isSelected
        let targetColor = isSelected ? selectionTextColor : baseTextColor
        if contentTextField.textColor != targetColor {
            contentTextField.textColor = targetColor
        }
    }

    private func updateIconConstraintActivation() {
        if isIconVisible {
            textTrailingToContainerConstraint?.isActive = false
            if let toButton = textTrailingToButtonConstraint {
                toButton.isActive = true
            }
            NSLayoutConstraint.activate(actionButtonConstraints)
        } else {
            if let toButton = textTrailingToButtonConstraint {
                toButton.isActive = false
            }
            NSLayoutConstraint.deactivate(actionButtonConstraints)
            textTrailingToContainerConstraint?.isActive = true
        }
    }
}
#endif
