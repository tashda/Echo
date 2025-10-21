import SwiftUI
import Combine
#if os(macOS)
import AppKit
import QuartzCore

/// AppKit-based settings window that mirrors the SwiftUI layout while giving us
/// native control over the titlebar chrome (matching Xcode).
final class AppKitSettingsWindowController: NSWindowController {
    static let shared = AppKitSettingsWindowController()

    private let navigationBridge = SettingsNavigationBridge()
    private let hostingController: SettingsHostingViewController

    private let navControl: NSSegmentedControl
    private let capsuleView: CapsuleTitleAccessoryView
    private let titlebarAccessory: NSTitlebarAccessoryViewController
    private let headerView: SettingsTitlebarHeaderView
    private var cancellables: Set<AnyCancellable> = []

    private override init(window: NSWindow?) {
        navControl = NSSegmentedControl(images: [
            NSImage(systemSymbolName: "chevron.left", accessibilityDescription: nil) ?? NSImage(),
            NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil) ?? NSImage()
        ], trackingMode: .momentary, target: nil, action: nil)

        capsuleView = CapsuleTitleAccessoryView()
        hostingController = SettingsHostingViewController(bridge: navigationBridge)
        headerView = SettingsTitlebarHeaderView(navControl: navControl, capsule: capsuleView)
        titlebarAccessory = NSTitlebarAccessoryViewController()

        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.title = "Settings"
        window.setContentSize(NSSize(width: 960, height: 660))
        window.contentMinSize = NSSize(width: 820, height: 580)

        super.init(window: window)

        configureTitlebar(for: window)
        connectBridge()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(section: SettingsView.SettingsSection? = nil) {
        if let section {
            NotificationCenter.default.post(name: .openSettingsSection, object: section.rawValue)
        }

        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Titlebar configuration

    private func configureTitlebar(for window: NSWindow) {
        navControl.segmentStyle = .roundRect
        navControl.controlSize = .regular
        navControl.setWidth(30, forSegment: 0)
        navControl.setWidth(30, forSegment: 1)
        navControl.target = self
        navControl.action = #selector(handleNavigation(_:))
        navControl.setEnabled(false, forSegment: 0)
        navControl.setEnabled(false, forSegment: 1)
        navControl.translatesAutoresizingMaskIntoConstraints = false
        navControl.setContentHuggingPriority(.required, for: .horizontal)
        navControl.setContentCompressionResistancePriority(.required, for: .horizontal)
        if let cell = navControl.cell as? NSSegmentedCell {
            cell.trackingMode = .momentary
            cell.controlSize = navControl.controlSize
            cell.isBordered = true
        }
        capsuleView.translatesAutoresizingMaskIntoConstraints = false

        titlebarAccessory.layoutAttribute = .top
        titlebarAccessory.view = headerView
        titlebarAccessory.fullScreenMinHeight = headerView.intrinsicContentSize.height
        headerView.heightAnchor.constraint(equalToConstant: headerView.intrinsicContentSize.height).isActive = true
        if !window.titlebarAccessoryViewControllers.contains(titlebarAccessory) {
            window.addTitlebarAccessoryViewController(titlebarAccessory)
        }
    }

    // MARK: - Bridge wiring

    private func connectBridge() {
        navigationBridge.$title
            .receive(on: RunLoop.main)
            .sink { [weak self] title in
                self?.capsuleView.title = title
            }
            .store(in: &cancellables)

        navigationBridge.$canNavigateBack
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.navControl.setEnabled(enabled, forSegment: 0)
            }
            .store(in: &cancellables)

        navigationBridge.$canNavigateForward
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.navControl.setEnabled(enabled, forSegment: 1)
            }
            .store(in: &cancellables)
    }

    @objc private func handleNavigation(_ sender: NSSegmentedControl) {
        defer { sender.selectedSegment = -1 }
        switch sender.selectedSegment {
        case 0:
            navigationBridge.triggerBack()
        case 1:
            navigationBridge.triggerForward()
        default:
            break
        }
    }
}

// MARK: - Hosting controller wrapper

private final class SettingsHostingViewController: NSHostingController<SettingsRootSwiftUIView> {
    init(bridge: SettingsNavigationBridge) {
        super.init(rootView: SettingsRootSwiftUIView(bridge: bridge))
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct SettingsRootSwiftUIView: View {
    let bridge: SettingsNavigationBridge

    var body: some View {
        SettingsView(toolbarBridge: bridge)
            .environmentObject(AppCoordinator.shared.appModel)
            .environmentObject(AppCoordinator.shared.appState)
            .environmentObject(AppCoordinator.shared.clipboardHistory)
            .environmentObject(ThemeManager.shared)
    }
}

// MARK: - Capsule accessory view

private final class CapsuleTitleAccessoryView: NSVisualEffectView {
    private let titleField: NSTextField

    var title: String = "Appearance" {
        didSet { titleField.stringValue = title }
    }

    override init(frame frameRect: NSRect) {
        titleField = NSTextField(labelWithString: "Appearance")
        super.init(frame: frameRect)

        translatesAutoresizingMaskIntoConstraints = false
        material = .hudWindow
        state = .active
        blendingMode = .withinWindow
        isEmphasized = false
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor

        titleField.font = .systemFont(ofSize: 16, weight: .semibold)
        titleField.textColor = .labelColor
        titleField.alignment = .center
        titleField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleField)

        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            titleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        let labelSize = titleField.intrinsicContentSize
        let width = max(200, labelSize.width + 48)
        return NSSize(width: width, height: 32)
    }
}

private final class SettingsTitlebarHeaderView: NSView {
    private let backgroundView = NSVisualEffectView()
    private let separator = NSView(frame: .zero)
    private let stackView = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "Settings")
    private let navControl: NSSegmentedControl
    private let capsuleView: CapsuleTitleAccessoryView
    private let highlightLayer = CAGradientLayer()

    init(navControl: NSSegmentedControl, capsule: CapsuleTitleAccessoryView) {
        self.navControl = navControl
        self.capsuleView = capsule
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.material = .underWindowBackground
        backgroundView.state = .active
        backgroundView.blendingMode = .withinWindow
        backgroundView.isEmphasized = false
        backgroundView.wantsLayer = true
        backgroundView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.2).cgColor
        backgroundView.layer?.shadowOpacity = 0.15
        backgroundView.layer?.shadowRadius = 18
        backgroundView.layer?.shadowOffset = CGSize(width: 0, height: -6)

        addSubview(backgroundView)

        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 14
        stackView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .natural
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        capsuleView.setContentHuggingPriority(.required, for: .horizontal)
        capsuleView.setContentCompressionResistancePriority(.required, for: .horizontal)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(navControl)
        stackView.addArrangedSubview(capsuleView)
        stackView.setCustomSpacing(20, after: navControl)
        addSubview(stackView)

        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.wantsLayer = true
        separator.layer = CALayer()
        separator.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        addSubview(separator)

        highlightLayer.colors = [
            NSColor.white.withAlphaComponent(0.24).cgColor,
            NSColor.white.withAlphaComponent(0.08).cgColor,
            NSColor.clear.cgColor
        ]
        highlightLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
        highlightLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
        highlightLayer.needsDisplayOnBoundsChange = true
        backgroundView.layer?.addSublayer(highlightLayer)

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            stackView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 12),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])

        applyHighlightColors()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 72)
    }

    override func layout() {
        super.layout()
        highlightLayer.frame = CGRect(x: 0, y: bounds.height / 2, width: bounds.width, height: bounds.height / 2)
        applyHighlightColors()
        if let layer = backgroundView.layer {
            let shadowRect = CGRect(x: -40, y: -40, width: bounds.width + 80, height: bounds.height + 80)
            layer.shadowPath = CGPath(roundedRect: shadowRect, cornerWidth: 40, cornerHeight: 40, transform: nil)
        }
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        super.updateLayer()
        applyHighlightColors()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyHighlightColors()
    }

    private func applyHighlightColors() {
        let appearance = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        if appearance == .darkAqua {
            highlightLayer.colors = [
                NSColor.white.withAlphaComponent(0.08).cgColor,
                NSColor.white.withAlphaComponent(0.02).cgColor,
                NSColor.clear.cgColor
            ]
            separator.layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.18).cgColor
            navControl.appearance = NSAppearance(named: .darkAqua)
            capsuleView.layer?.borderColor = NSColor.white.withAlphaComponent(0.22).cgColor
        } else {
            highlightLayer.colors = [
                NSColor.white.withAlphaComponent(0.24).cgColor,
                NSColor.white.withAlphaComponent(0.08).cgColor,
                NSColor.clear.cgColor
            ]
            separator.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
            navControl.appearance = NSAppearance(named: .aqua)
            capsuleView.layer?.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor
        }
    }
}

#endif
