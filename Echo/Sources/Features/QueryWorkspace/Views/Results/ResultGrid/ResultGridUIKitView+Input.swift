#if os(iOS)
import UIKit

extension ResultGridCoordinator {
    private var keyCommandList_: [UIKeyCommand] {
        [
            UIKeyCommand(input: "c", modifierFlags: .command, action: #selector(handleCopyCommand_(_:)), discoverabilityTitle: "Copy"),
            UIKeyCommand(input: "c", modifierFlags: [.command, .shift], action: #selector(handleCopyWithHeadersCommand_(_:)), discoverabilityTitle: "Copy with Headers"),
            UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(handleArrowKey_(_:))),
            UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [.shift], action: #selector(handleArrowKey_(_:))),
            UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(handleArrowKey_(_:))),
            UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [.shift], action: #selector(handleArrowKey_(_:))),
            UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(handleArrowKey_(_:))),
            UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [.shift], action: #selector(handleArrowKey_(_:))),
            UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(handleArrowKey_(_:))),
            UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [.shift], action: #selector(handleArrowKey_(_:))),
            UIKeyCommand(input: UIKeyCommand.inputPageUp, modifierFlags: [], action: #selector(handleArrowKey_(_:))),
            UIKeyCommand(input: UIKeyCommand.inputPageDown, modifierFlags: [], action: #selector(handleArrowKey_(_:))),
            UIKeyCommand(input: UIKeyCommand.inputHome, modifierFlags: [], action: #selector(handleArrowKey_(_:))),
            UIKeyCommand(input: UIKeyCommand.inputEnd, modifierFlags: [], action: #selector(handleArrowKey_(_:)))
        ]
    }

    @objc private func handleCopyCommand_(_ command: UIKeyCommand) {
        copySelection(includeHeaders: false)
    }

    @objc private func handleCopyWithHeadersCommand_(_ command: UIKeyCommand) {
        copySelection(includeHeaders: true)
    }

    @objc private func handleArrowKey_(_ command: UIKeyCommand) {
        let extend = command.modifierFlags.contains(.shift)
        switch command.input {
        case UIKeyCommand.inputUpArrow:
            moveSelection(rowDelta: -1, columnDelta: 0, extend: extend)
        case UIKeyCommand.inputDownArrow:
            moveSelection(rowDelta: 1, columnDelta: 0, extend: extend)
        case UIKeyCommand.inputLeftArrow:
            moveSelection(rowDelta: 0, columnDelta: -1, extend: extend)
        case UIKeyCommand.inputRightArrow:
            moveSelection(rowDelta: 0, columnDelta: 1, extend: extend)
        case UIKeyCommand.inputPageUp:
            moveSelection(rowDelta: -pageJumpAmount(), columnDelta: 0, extend: extend)
        case UIKeyCommand.inputPageDown:
            moveSelection(rowDelta: pageJumpAmount(), columnDelta: 0, extend: extend)
        case UIKeyCommand.inputHome:
            moveSelection(rowDelta: -Int.max, columnDelta: 0, extend: extend)
        case UIKeyCommand.inputEnd:
            moveSelection(rowDelta: Int.max, columnDelta: 0, extend: extend)
        default:
            break
        }
    }
}

final class ResultGridValuePreviewController: UIViewController {
    private let value: String
    private let titleText: String?

    init(value: String, title: String?) {
        self.value = value
        self.titleText = title
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .formSheet
        preferredContentSize = CGSize(width: 420, height: 320)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.text = value
        textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.isEditable = false
        textView.isSelectable = true
        textView.alwaysBounceVertical = true

        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 12
        container.translatesAutoresizingMaskIntoConstraints = false

        if let titleText, !titleText.isEmpty {
            let titleLabel = UILabel()
            titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
            titleLabel.text = titleText
            container.addArrangedSubview(titleLabel)
        }

        container.addArrangedSubview(textView)

        view.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
}
#endif
