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

        super.init(window: window)
        
        // Use empty toolbar for the unified style but no items
        let toolbar = NSToolbar(identifier: NSToolbar.Identifier("SettingsToolbar"))
        toolbar.showsBaselineSeparator = false
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        
        // Use titlebar accessory instead of toolbar items for proper positioning
        let accessoryController = NSTitlebarAccessoryViewController()
        accessoryController.view = toolbarAccessoryView
        accessoryController.layoutAttribute = .leading
        window.addTitlebarAccessoryViewController(accessoryController)

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

    private let backButton: NSButton
    private let forwardButton: NSButton
    private let titleLabel: NSTextField
    private let sidebarWidth: CGFloat = 280
    
    init() {
        self.backButton = NSButton()
        self.forwardButton = NSButton()
        self.titleLabel = NSTextField(labelWithString: "")
        super.init(frame: NSRect(x: 0, y: 0, width: 600, height: 40))
        configureViewHierarchy()
        configureActions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 600, height: 40)
    }

    func updateTitle(_ title: String) {
        titleLabel.stringValue = title
        needsLayout = true
    }

    func updateBackEnabled(_ isEnabled: Bool) {
        backButton.isEnabled = isEnabled
    }

    func updateForwardEnabled(_ isEnabled: Bool) {
        forwardButton.isEnabled = isEnabled
    }

    private func configureViewHierarchy() {
        // Use manual layout - no auto layout constraints
        autoresizesSubviews = false
        
        // Create container for both buttons with Xcode's pill background
        let buttonContainer = NSView()
        buttonContainer.wantsLayer = true
        buttonContainer.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        buttonContainer.layer?.cornerRadius = 12
        
        // Configure back button - match Xcode exactly
        backButton.isBordered = false
        backButton.bezelStyle = .shadowlessSquare
        backButton.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back")
        backButton.imagePosition = .imageOnly
        backButton.imageScaling = .scaleProportionallyDown
        backButton.toolTip = "Back"
        
        // Configure forward button - match Xcode exactly  
        forwardButton.isBordered = false
        forwardButton.bezelStyle = .shadowlessSquare
        forwardButton.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Forward")
        forwardButton.imagePosition = .imageOnly
        forwardButton.imageScaling = .scaleProportionallyDown
        forwardButton.toolTip = "Forward"

        // Configure title label
        titleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .left
        titleLabel.backgroundColor = .clear
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.drawsBackground = false
        titleLabel.lineBreakMode = .byTruncatingTail

        addSubview(buttonContainer)
        buttonContainer.addSubview(backButton)
        buttonContainer.addSubview(forwardButton)
        addSubview(titleLabel)
    }
    
    override func layout() {
        super.layout()
        
        // Match Xcode's exact positioning
        let startX = sidebarWidth + 8  // Sidebar + small margin
        let containerWidth: CGFloat = 54  // Width for both buttons (26+2+26)
        let containerHeight: CGFloat = 24
        let containerY = (bounds.height - containerHeight) / 2
        
        // Position button container with pill background
        if let buttonContainer = subviews.first(where: { $0 !== titleLabel && $0 !== backButton && $0 !== forwardButton }) {
            buttonContainer.frame = NSRect(x: startX, y: containerY, width: containerWidth, height: containerHeight)
            
            // Position buttons within container
            backButton.frame = NSRect(x: 1, y: 0, width: 26, height: 24)
            forwardButton.frame = NSRect(x: 27, y: 0, width: 26, height: 24)
        }
        
        // Position title label
        let titleX = startX + containerWidth + 8
        let titleY = (bounds.height - 20) / 2
        let titleWidth = max(100, bounds.width - titleX - 20)
        titleLabel.frame = NSRect(x: titleX, y: titleY, width: titleWidth, height: 20)
    }

    private func configureActions() {
        backButton.target = self
        backButton.action = #selector(handleBack)
        forwardButton.target = self
        forwardButton.action = #selector(handleForward)
    }
    
    @objc private func handleBack() {
        onNavigateBack?()
    }
    
    @objc private func handleForward() {
        onNavigateForward?()
    }

    func updateWindowIsKey(_ isKey: Bool) {
        titleLabel.textColor = isKey ? .labelColor : .secondaryLabelColor
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

#endif
