import SwiftUI
import Combine
#if os(macOS)
import AppKit

/// Xcode-style settings window with navigation toolbar
final class AppKitSettingsWindowController: NSWindowController {
    static let shared = AppKitSettingsWindowController()

    private let navigationBridge = SettingsNavigationBridge()
    private let selectionModel = SettingsSelectionModel()
    private var cancellables: Set<AnyCancellable> = []

    // Navigation controls
    private var backButton: NSButton!
    private var forwardButton: NSButton!
    private var titleLabel: NSTextField!
    private var navigationContainer: NSView!

    private override init(window: NSWindow?) {
        super.init(window: window)

        setupNavigationControls()
        setupWindow()
        setupNavigation()
    }

    private func setupNavigationControls() {
        // Create navigation controls
        backButton = NSButton()
        backButton.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back")
        backButton.bezelStyle = .rounded
        backButton.controlSize = .regular
        backButton.isBordered = true
        backButton.translatesAutoresizingMaskIntoConstraints = false

        forwardButton = NSButton()
        forwardButton.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Forward")
        forwardButton.bezelStyle = .rounded
        forwardButton.controlSize = .regular
        forwardButton.isBordered = true
        forwardButton.translatesAutoresizingMaskIntoConstraints = false

        titleLabel = NSTextField()
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .left
        titleLabel.stringValue = "Appearance"
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        navigationContainer = NSView()
        navigationContainer.wantsLayer = true
        navigationContainer.translatesAutoresizingMaskIntoConstraints = false

        setupNavigationContainer()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupNavigationContainer() {
        // Add controls to container
        navigationContainer.addSubview(backButton)
        navigationContainer.addSubview(forwardButton)
        navigationContainer.addSubview(titleLabel)

        // Use constraints to position the controls (296px = 280 sidebar + 16 margin)
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: navigationContainer.leadingAnchor, constant: 296),
            backButton.centerYAnchor.constraint(equalTo: navigationContainer.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 28),
            backButton.heightAnchor.constraint(equalToConstant: 28),

            forwardButton.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 4),
            forwardButton.centerYAnchor.constraint(equalTo: navigationContainer.centerYAnchor),
            forwardButton.widthAnchor.constraint(equalToConstant: 28),
            forwardButton.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.leadingAnchor.constraint(equalTo: forwardButton.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: navigationContainer.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: navigationContainer.trailingAnchor, constant: -16),

            // Container size
            navigationContainer.heightAnchor.constraint(equalToConstant: 32),
            navigationContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 500)
        ])

        // Button actions
        backButton.target = self
        backButton.action = #selector(handleBack(_:))
        forwardButton.target = self
        forwardButton.action = #selector(handleForward(_:))
    }

    private func setupWindow() {
        // Create window with hidden titlebar like Xcode
        let window = NSWindow()
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none

        let settingsView = SettingsView(toolbarBridge: navigationBridge)
            .environmentObject(selectionModel)
            .environmentObject(AppCoordinator.shared.appModel)
            .environmentObject(AppCoordinator.shared.appState)
            .environmentObject(AppCoordinator.shared.clipboardHistory)
            .environmentObject(ThemeManager.shared)

        window.contentViewController = NSHostingController(rootView: settingsView)
        window.setContentSize(NSSize(width: 1200, height: 800))
        window.contentMinSize = NSSize(width: 1000, height: 700)
        window.center()
        window.isReleasedWhenClosed = false

        self.window = window
    }

    private func setupNavigation() {
        // Connect bridge to UI controls
        navigationBridge.title = "Appearance"
        navigationBridge.canNavigateBack = false
        navigationBridge.canNavigateForward = false

        navigationBridge.$title
            .receive(on: RunLoop.main)
            .sink { [weak self] title in
                self?.titleLabel.stringValue = title
            }
            .store(in: &cancellables)

        navigationBridge.$canNavigateBack
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.backButton.isEnabled = enabled
            }
            .store(in: &cancellables)

        navigationBridge.$canNavigateForward
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.forwardButton.isEnabled = enabled
            }
            .store(in: &cancellables)

        // Sync selection model changes with bridge
        selectionModel.$selection
            .compactMap { $0 }
            .sink { [weak self] section in
                self?.navigationBridge.title = section.title
            }
            .store(in: &cancellables)
    }

    @objc private func handleBack(_ sender: NSButton) {
        navigationBridge.triggerBack()
    }

    @objc private func handleForward(_ sender: NSButton) {
        navigationBridge.triggerForward()
    }

    func present(section: SettingsView.SettingsSection? = nil) {
        if let section {
            NotificationCenter.default.post(name: .openSettingsSection, object: section.rawValue)
        }

        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}


// MARK: - Array Extensions

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#endif
