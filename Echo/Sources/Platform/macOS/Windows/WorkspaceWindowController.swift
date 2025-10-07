//
//  WorkspaceWindowController.swift
//  Echo
//
//  Created by Codex on 07/10/2025.
//

import AppKit
import SwiftUI
import Combine

final class WorkspaceWindowController: NSWindowController, NSWindowDelegate {
    private enum Constants {
        static let windowWidth: CGFloat = 1200
        static let windowHeight: CGFloat = 800
        static let minWindowWidth: CGFloat = 960
        static let minWindowHeight: CGFloat = 600
    }

    private unowned let coordinator: AppCoordinator
    private let splitViewController: WorkspaceSplitViewController
    private var navigatorToolbarItem: NavigatorToolbarItem?
    private var titleCancellable: AnyCancellable?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator

        let splitViewController = WorkspaceSplitViewController(
            tabID: nil,
            appModel: coordinator.appModel,
            appState: coordinator.appState,
            clipboardHistory: coordinator.clipboardHistory
        )
        self.splitViewController = splitViewController

        let contentRect = NSRect(
            x: 0,
            y: 0,
            width: Constants.windowWidth,
            height: Constants.windowHeight
        )
        let style: NSWindow.StyleMask = [
            .titled,
            .closable,
            .miniaturizable,
            .resizable,
            .fullSizeContentView
        ]
        let window = TitlebarTabsWindow(
            contentRect: contentRect,
            styleMask: style,
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        configure(window: window)
        installToolbar(into: window)
        window.contentViewController = splitViewController
        splitViewController.layoutDelegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(makeKey: Bool) {
        guard let window else { return }
        if makeKey {
            window.makeKeyAndOrderFront(nil)
        } else {
            window.orderFrontRegardless()
        }
    }

    // MARK: - Window Configuration

    private func configure(window: NSWindow) {
        window.title = "Echo"
        window.delegate = self
        window.minSize = NSSize(width: Constants.minWindowWidth, height: Constants.minWindowHeight)
        window.tabbingMode = .disallowed
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .line
    }

    private func installToolbar(into window: NSWindow) {
        let toolbar = NSToolbar(identifier: .workspaceToolbar)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.sizeMode = .regular
        toolbar.allowsUserCustomization = false
        if #unavailable(macOS 15.0) {
            toolbar.showsBaselineSeparator = false
        }
        if #available(macOS 13.0, *) {
            toolbar.centeredItemIdentifier = .navigator
        }
        window.toolbar = toolbar
        if #available(macOS 15.0, *) {
            window.toolbarStyle = .unified
        } else {
            window.toolbarStyle = .unifiedCompact
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        titleCancellable?.cancel()
        coordinator.workspaceWindowWillClose(self)
    }

    func windowDidBecomeMain(_ notification: Notification) {
        coordinator.workspaceWindowDidBecomeMain(self)
    }

    // MARK: - Title Binding

    func bind(to tab: WorkspaceTab?) {
        titleCancellable?.cancel()

        guard let window else { return }

        guard let tab else {
            window.title = "Echo"
            return
        }

        window.title = tab.title
        titleCancellable = tab.$title
            .receive(on: RunLoop.main)
            .sink { [weak window] newTitle in
                window?.title = newTitle
            }
    }
}

// MARK: - Toolbar Delegate

extension WorkspaceWindowController: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .flexibleSpace,
            .navigator,
            .flexibleSpace,
            .toggleInspector,
            .inspectorTrackingSeparator
        ]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .navigator,
            .flexibleSpace,
            .toggleInspector,
            .inspectorTrackingSeparator
        ]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .toggleInspector:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Inspector"
            item.paletteLabel = "Toggle Inspector"
            item.toolTip = "Show or hide the inspector"
            item.target = self
            item.action = #selector(toggleInspector(_:))
            return item

        case .navigator:
            let item = NavigatorToolbarItem(
                identifier: itemIdentifier,
                appModel: coordinator.appModel,
                themeManager: ThemeManager.shared
            )
            navigatorToolbarItem = item
            return item

        case .sidebarTrackingSeparator:
            guard let splitView = splitViewController.splitViewIfLoaded else { return nil }
            return NSTrackingSeparatorToolbarItem(
                identifier: itemIdentifier,
                splitView: splitView,
                dividerIndex: 0
            )

        case .inspectorTrackingSeparator:
            guard let splitView = splitViewController.splitViewIfLoaded else { return nil }
            return NSTrackingSeparatorToolbarItem(
                identifier: itemIdentifier,
                splitView: splitView,
                dividerIndex: 1
            )

        case .flexibleSpace:
            return NSToolbarItem(itemIdentifier: .flexibleSpace)

        default:
            return nil
        }
    }
}





// MARK: - Inspector Handling

extension WorkspaceWindowController: NSUserInterfaceValidations {
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        guard let action = item.action else { return true }
        switch action {
        case #selector(toggleInspector(_:)):
            return true
        default:
            return true
        }
    }

    @objc private func toggleInspector(_ sender: Any?) {
        splitViewController.toggleInspector()
    }
}

// MARK: - Split View Layout Delegate

extension WorkspaceWindowController: WorkspaceSplitViewControllerLayoutDelegate {
    func workspaceSplitViewController(
        _ controller: WorkspaceSplitViewController,
        didUpdateNavigatorLayout layout: WorkspaceNavigatorLayout
    ) {
        let measuredWidth = max(layout.width, 0)
        let targetWidth: CGFloat
        if measuredWidth >= NavigatorToolbarLayoutModel.defaultWidth {
            targetWidth = min(measuredWidth, NavigatorToolbarLayoutModel.maximumWidth)
        } else {
            targetWidth = max(measuredWidth, NavigatorToolbarLayoutModel.minimumAllowedWidth)
        }

        navigatorToolbarItem?.updateWidth(targetWidth)
    }
}

// MARK: - Toolbar Identifiers

private extension NSToolbar.Identifier {
    static let workspaceToolbar = NSToolbar.Identifier("io.echo.workspace.toolbar")
}

private extension NSToolbarItem.Identifier {
    static let navigator = NSToolbarItem.Identifier("io.echo.workspace.toolbar.navigator")
}

// MARK: - Split View Accessor

private extension WorkspaceSplitViewController {
    var splitViewIfLoaded: NSSplitView? {
        isViewLoaded ? splitView : nil
    }
}

// MARK: - Navigator Toolbar Item

private final class NavigatorToolbarItem: NSToolbarItem {
    private let layoutModel = NavigatorToolbarLayoutModel()
    private let hostingView: NSHostingView<NavigatorToolbarContentView>
    private let containerView: NSView
    private let widthConstraint: NSLayoutConstraint

    init(identifier: NSToolbarItem.Identifier, appModel: AppModel, themeManager: ThemeManager) {
        hostingView = NSHostingView(rootView: NavigatorToolbarContentView(
            layoutModel: layoutModel,
            appModel: appModel,
            themeManager: themeManager
        ))
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            containerView.heightAnchor.constraint(equalToConstant: NavigatorToolbarLayoutModel.toolbarHeight)
        ])

        widthConstraint = containerView.widthAnchor.constraint(equalToConstant: NavigatorToolbarLayoutModel.defaultWidth)
        widthConstraint.isActive = true

        super.init(itemIdentifier: identifier)

        view = containerView
        visibilityPriority = .high
        updateWidth(NavigatorToolbarLayoutModel.defaultWidth)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateWidth(_ width: CGFloat) {
        let boundedWidth = max(width, NavigatorToolbarLayoutModel.minimumAllowedWidth)
        let clampedWidth = min(boundedWidth, NavigatorToolbarLayoutModel.maximumWidth)
        layoutModel.width = clampedWidth

        widthConstraint.constant = clampedWidth
        containerView.invalidateIntrinsicContentSize()
    }
}

private final class NavigatorToolbarLayoutModel: ObservableObject {
    static let defaultWidth: CGFloat = 520
    static let maximumWidth: CGFloat = 700
    static let minimumAllowedWidth: CGFloat = 120
    static let toolbarHeight: CGFloat = 44

    @Published var width: CGFloat

    init(width: CGFloat = NavigatorToolbarLayoutModel.defaultWidth) {
        self.width = width
    }
}

private struct NavigatorToolbarContentView: View {
    @ObservedObject var layoutModel: NavigatorToolbarLayoutModel
    let appModel: AppModel
    let themeManager: ThemeManager

    var body: some View {
        TopBarNavigator(width: layoutModel.width)
            .environmentObject(appModel)
            .environmentObject(appModel.navigationState)
            .environmentObject(themeManager)
            .frame(height: 32)
            .padding(.vertical, 6)
    }
}
