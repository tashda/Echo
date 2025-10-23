import SwiftUI
import Combine
#if os(macOS)
import AppKit
import QuartzCore

/// AppKit-based settings window that mirrors Xcode Settings appearance.
final class AppKitSettingsWindowController: NSWindowController {
    static let shared = AppKitSettingsWindowController()

    private let navigationBridge = SettingsNavigationBridge()
    private let hostingController: SettingsHostingViewController
    private let toolbarAccessoryView: SettingsToolbarAccessoryView
    private let sidebarWidth: CGFloat = 280
    private var navigationToolbarItem: SettingsNavigationToolbarItem?
    private var splitViewDelegate: FixedSidebarSplitViewDelegate?

    private var cancellables: Set<AnyCancellable> = []

    private override init(window: NSWindow?) {
        toolbarAccessoryView = SettingsToolbarAccessoryView()
        hostingController = SettingsHostingViewController(bridge: navigationBridge)

        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        window.title = ""
        window.setContentSize(NSSize(width: 960, height: 660))
        window.contentMinSize = NSSize(width: 820, height: 580)

        let toolbar = NSToolbar(identifier: NSToolbar.Identifier("SettingsToolbar"))
        toolbar.showsBaselineSeparator = false
        toolbar.allowsExtensionItems = false
        toolbar.allowsUserCustomization = false
        toolbar.centeredItemIdentifier = nil
        window.toolbar = toolbar
        window.toolbarStyle = .unified

        super.init(window: window)

        toolbar.delegate = self

        toolbarAccessoryView.onNavigateBack = { [weak self] in self?.handleBack() }
        toolbarAccessoryView.onNavigateForward = { [weak self] in self?.handleForward() }

        connectBridge()
        observeWindowActivation()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(section: SettingsView.SettingsSection? = nil) {
        print("🔷 AppKitSettingsWindowController.present() called")
        print("🔷 Window: \(String(describing: window))")

        if let section {
            NotificationCenter.default.post(name: .openSettingsSection, object: section.rawValue)
        }

        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        print("🔷 Window should now be visible")
    }

    // MARK: - Bridge wiring

    private func connectBridge() {
        navigationBridge.$title
            .receive(on: RunLoop.main)
            .sink { [weak self] title in
                self?.toolbarAccessoryView.updateTitle(title)
            }
            .store(in: &cancellables)

        navigationBridge.$canNavigateBack
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.toolbarAccessoryView.updateBackEnabled(enabled)
            }
            .store(in: &cancellables)

        navigationBridge.$canNavigateForward
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.toolbarAccessoryView.updateForwardEnabled(enabled)
            }
            .store(in: &cancellables)
    }

    @objc private func handleBack() {
        navigationBridge.triggerBack()
    }

    @objc private func handleForward() {
        navigationBridge.triggerForward()
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        updateWindowActivationAppearance()
        configureSplitViewForFixedSidebar()
    }

    private func observeWindowActivation() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleWindowActivationChange),
                                               name: NSWindow.didBecomeKeyNotification,
                                               object: window)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleWindowActivationChange),
                                               name: NSWindow.didResignKeyNotification,
                                               object: window)
    }

    @objc private func handleWindowActivationChange(_ notification: Notification) {
        updateWindowActivationAppearance()
    }

    private func updateWindowActivationAppearance() {
        let isKey = window?.isKeyWindow ?? false
        toolbarAccessoryView.updateWindowIsKey(isKey)
    }

    private func configureSplitViewForFixedSidebar() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let splitView = self.findSplitView(in: self.hostingController.view) else { return }
            let delegate = FixedSidebarSplitViewDelegate(sidebarWidth: self.sidebarWidth)
            self.splitViewDelegate = delegate
            splitView.delegate = delegate
            splitView.setPosition(self.sidebarWidth, ofDividerAt: 0)
        }
    }

    private func findSplitView(in view: NSView) -> NSSplitView? {
        if let splitView = view as? NSSplitView {
            return splitView
        }
        for subview in view.subviews {
            if let result = findSplitView(in: subview) {
                return result
            }
        }
        return nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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

// MARK: - Accessory view

private final class SettingsToolbarAccessoryView: NSView {
    var onNavigateBack: (() -> Void)?
    var onNavigateForward: (() -> Void)?

    private let backButton: ToolbarNavigationButton
    private let forwardButton: ToolbarNavigationButton
    private let titleLabel: NSTextField
    init() {
        self.backButton = ToolbarNavigationButton(systemName: "chevron.left", accessibilityDescription: "Back")
        self.forwardButton = ToolbarNavigationButton(systemName: "chevron.right", accessibilityDescription: "Forward")
        self.titleLabel = NSTextField(labelWithString: "Appearance")
        super.init(frame: NSRect(x: 0, y: 0, width: 360, height: 44))
        configureViewHierarchy()
        configureActions()
        updateBackEnabled(false)
        updateForwardEnabled(false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 44)
    }

    func updateTitle(_ title: String) {
        titleLabel.stringValue = title
        titleLabel.invalidateIntrinsicContentSize()
    }

    func updateBackEnabled(_ isEnabled: Bool) {
        backButton.isEnabled = isEnabled
    }

    func updateForwardEnabled(_ isEnabled: Bool) {
        forwardButton.isEnabled = isEnabled
    }

    private func configureViewHierarchy() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = false

        let buttonPill = NSVisualEffectView()
        buttonPill.material = .hudWindow
        buttonPill.state = .active
        buttonPill.blendingMode = .withinWindow
        buttonPill.wantsLayer = true
        buttonPill.layer?.cornerRadius = 16
        if #available(macOS 13.0, *) {
            buttonPill.layer?.cornerCurve = .continuous
        }
        buttonPill.layer?.masksToBounds = true
        buttonPill.translatesAutoresizingMaskIntoConstraints = false
        buttonPill.setContentHuggingPriority(.required, for: .horizontal)
        buttonPill.setContentCompressionResistancePriority(.required, for: .horizontal)

        let buttonStack = NSStackView(views: [backButton, forwardButton])
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.spacing = 6
        buttonStack.edgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        buttonPill.addSubview(buttonStack)
        NSLayoutConstraint.activate([
            buttonStack.leadingAnchor.constraint(equalTo: buttonPill.leadingAnchor),
            buttonStack.trailingAnchor.constraint(equalTo: buttonPill.trailingAnchor),
            buttonStack.topAnchor.constraint(equalTo: buttonPill.topAnchor),
            buttonStack.bottomAnchor.constraint(equalTo: buttonPill.bottomAnchor)
        ])

        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .left
        titleLabel.backgroundColor = .clear
        titleLabel.isBordered = false
        titleLabel.drawsBackground = false
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let mainStack = NSStackView(views: [buttonPill, titleLabel])
        mainStack.orientation = .horizontal
        mainStack.alignment = .centerY
        mainStack.spacing = 10
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.setContentHuggingPriority(.required, for: .horizontal)
        mainStack.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            mainStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
            mainStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            mainStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 4),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -4)
        ])
    }

    private func configureActions() {
        backButton.target = self
        backButton.action = #selector(handleBackTapped)
        forwardButton.target = self
        forwardButton.action = #selector(handleForwardTapped)
    }

    @objc private func handleBackTapped() {
        onNavigateBack?()
    }

    @objc private func handleForwardTapped() {
        onNavigateForward?()
    }

    func updateWindowIsKey(_ isKey: Bool) {
        titleLabel.textColor = isKey ? .labelColor : .tertiaryLabelColor
    }
}

// MARK: - Toolbar delegate

extension AppKitSettingsWindowController: NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.settingsNavigation, .flexibleSpace]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.settingsNavigation, .flexibleSpace]
    }

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .settingsNavigation:
            let item = SettingsNavigationToolbarItem(identifier: itemIdentifier,
                                                     accessoryView: toolbarAccessoryView,
                                                     spacerWidth: sidebarWidth)
            navigationToolbarItem = item
            return item
        case .flexibleSpace:
            return NSToolbarItem(itemIdentifier: .flexibleSpace)
        default:
            return nil
        }
    }
}

private final class SettingsNavigationToolbarItem: NSToolbarItem {
    init(identifier: NSToolbarItem.Identifier,
         accessoryView: SettingsToolbarAccessoryView,
         spacerWidth: CGFloat) {
        accessoryView.translatesAutoresizingMaskIntoConstraints = false

        let spacerView = NSView()
        spacerView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSStackView(views: [spacerView, accessoryView])
        container.orientation = .horizontal
        container.alignment = .centerY
        container.spacing = 0
        container.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.setContentHuggingPriority(.required, for: .horizontal)
        container.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        super.init(itemIdentifier: identifier)

        view = container

        NSLayoutConstraint.activate([
            spacerView.widthAnchor.constraint(equalToConstant: spacerWidth),
            container.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
}

private final class FixedSidebarSplitViewDelegate: NSObject, NSSplitViewDelegate {
    private let sidebarWidth: CGFloat

    init(sidebarWidth: CGFloat) {
        self.sidebarWidth = sidebarWidth
    }

    func splitView(_ splitView: NSSplitView,
                   constrainSplitPosition proposedPosition: CGFloat,
                   ofSubviewAt dividerIndex: Int) -> CGFloat {
        guard dividerIndex == 0 else { return proposedPosition }
        return sidebarWidth
    }

    func splitView(_ splitView: NSSplitView, shouldAdjustSizeOfSubview view: NSView) -> Bool {
        guard let index = splitView.subviews.firstIndex(of: view) else { return true }
        return index != 0
    }
}

private extension NSToolbarItem.Identifier {
    static let settingsNavigation = NSToolbarItem.Identifier("SettingsNavigationItem")
}

private final class ToolbarNavigationButton: NSButton {
    convenience init(systemName: String, accessibilityDescription: String) {
        let image = NSImage(systemSymbolName: systemName, accessibilityDescription: accessibilityDescription) ?? NSImage()
        self.init(image: image)
        self.image?.isTemplate = true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    private init(image: NSImage) {
        super.init(frame: .zero)
        configure()
        self.image = image
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        bezelStyle = .texturedRounded
        isBordered = true
        setButtonType(.momentaryPushIn)
        translatesAutoresizingMaskIntoConstraints = false
        focusRingType = .default
        imageScaling = .scaleProportionallyDown
        contentTintColor = .secondaryLabelColor
        controlSize = .small
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 28),
            heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    override var isEnabled: Bool {
        didSet {
            contentTintColor = isEnabled
                ? .secondaryLabelColor
                : NSColor.secondaryLabelColor.withAlphaComponent(0.35)
        }
    }
}

#endif
