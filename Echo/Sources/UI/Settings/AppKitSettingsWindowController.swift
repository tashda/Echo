import SwiftUI
import Combine
#if os(macOS)
import AppKit
import QuartzCore

/// AppKit-based settings window that mirrors Xcode Settings appearance exactly.
final class AppKitSettingsWindowController: NSWindowController {
    static let shared = AppKitSettingsWindowController()

    private let navigationBridge = SettingsNavigationBridge()
    private let hostingController: SettingsHostingViewController

    private let navControl: NSSegmentedControl
    private let capsuleView: CapsuleTitleAccessoryView
    private let titlebarAccessory: NSTitlebarAccessoryViewController
    private let titlebarContainer: TitlebarContainerView

    private var cancellables: Set<AnyCancellable> = []

    private override init(window: NSWindow?) {
        // Create nav control with separated buttons
        navControl = NSSegmentedControl(images: [
            NSImage(systemSymbolName: "chevron.left", accessibilityDescription: nil) ?? NSImage(),
            NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil) ?? NSImage()
        ], trackingMode: .momentary, target: nil, action: nil)

        navControl.segmentStyle = .separated
        navControl.controlSize = .small
        navControl.setWidth(28, forSegment: 0)
        navControl.setWidth(28, forSegment: 1)
        navControl.translatesAutoresizingMaskIntoConstraints = false

        // Create capsule view
        capsuleView = CapsuleTitleAccessoryView()
        capsuleView.translatesAutoresizingMaskIntoConstraints = false

        // Create container view for both nav control and capsule
        titlebarContainer = TitlebarContainerView()
        titlebarContainer.navControl = navControl
        titlebarContainer.capsuleView = capsuleView

        // Create titlebar accessory on left
        titlebarAccessory = NSTitlebarAccessoryViewController()
        titlebarAccessory.view = titlebarContainer
        titlebarAccessory.layoutAttribute = .left

        // Create hosting controller
        hostingController = SettingsHostingViewController(bridge: navigationBridge)

        // Create window
        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.title = "Settings"
        window.setContentSize(NSSize(width: 960, height: 660))
        window.contentMinSize = NSSize(width: 820, height: 580)

        super.init(window: window)

        // Configure nav control
        navControl.target = self
        navControl.action = #selector(handleNavigation(_:))
        navControl.setEnabled(false, forSegment: 0)
        navControl.setEnabled(false, forSegment: 1)

        // Add titlebar accessory
        window.addTitlebarAccessoryViewController(titlebarAccessory)

        // Connect bridge
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

// MARK: - Titlebar Container with intrinsic size

private final class TitlebarContainerView: NSView {
    var navControl: NSSegmentedControl!
    var capsuleView: CapsuleTitleAccessoryView!
    private var stackView: NSStackView!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()

        guard superview != nil, stackView == nil else { return }

        // Create stack view to hold nav control and capsule
        stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(navControl)
        stackView.addArrangedSubview(capsuleView)

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    override var intrinsicContentSize: NSSize {
        guard let stackView = stackView else {
            return NSSize(width: 300, height: 32)
        }
        return stackView.fittingSize
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

// MARK: - Capsule title view

private final class CapsuleTitleAccessoryView: NSVisualEffectView {
    private let titleField: NSTextField

    var title: String = "Appearance" {
        didSet {
            titleField.stringValue = title
            invalidateIntrinsicContentSize()
        }
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
        layer?.cornerRadius = 14
        layer?.masksToBounds = true

        titleField.font = .systemFont(ofSize: 13, weight: .semibold)
        titleField.textColor = .labelColor
        titleField.alignment = .center
        titleField.isBordered = false
        titleField.isEditable = false
        titleField.backgroundColor = .clear
        titleField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleField)

        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        let labelSize = titleField.intrinsicContentSize
        let width = max(160, labelSize.width + 32)
        return NSSize(width: width, height: 28)
    }
}

#endif
