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
    private let hostingController: NSHostingController<WorkspaceHostView>
    private let themeManager: ThemeManager

    private var titleCancellable: AnyCancellable?
    private var themeCancellable: AnyCancellable?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        self.themeManager = ThemeManager.shared

        hostingController = NSHostingController(
            rootView: WorkspaceHostView(
                appModel: coordinator.appModel,
                appState: coordinator.appState,
                themeManager: ThemeManager.shared,
                clipboardHistory: coordinator.clipboardHistory,
                navigationState: coordinator.appModel.navigationState
            )
        )

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
        window.contentViewController = hostingController

        applyTheme(themeManager.activeTheme)
        observeThemeChanges()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        titleCancellable?.cancel()
        themeCancellable?.cancel()
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

    private func observeThemeChanges() {
        themeCancellable = themeManager.$activeTheme
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] theme in
                self?.applyTheme(theme)
            }
    }

    private func applyTheme(_ theme: AppColorTheme) {
        guard let window else { return }

        if let titlebarWindow = window as? TransparentTitlebarWindow {
            titlebarWindow.preferredBackgroundColor = theme.windowBackground.nsColor
        }

        window.appearance = NSAppearance(named: theme.tone == .dark ? .darkAqua : .aqua)
        window.invalidateShadow()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        titleCancellable?.cancel()
        coordinator.workspaceWindowWillClose(self)
    }

    func windowDidBecomeMain(_ notification: Notification) {
        coordinator.workspaceWindowDidBecomeMain(self)
        applyTheme(themeManager.activeTheme)
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

// MARK: - Inspector Handling

extension WorkspaceWindowController: NSUserInterfaceValidations {
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        guard let action = item.action else { return true }
        switch action {
        default:
            return true
        }
    }
}

private struct WorkspaceHostView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var appState: AppState
    let themeManager: ThemeManager
    @ObservedObject var clipboardHistory: ClipboardHistoryStore
    @ObservedObject var navigationState: NavigationState

    var body: some View {
        WorkspaceView()
            .environmentObject(appModel)
            .environmentObject(appState)
            .environmentObject(themeManager)
            .environmentObject(clipboardHistory)
            .environmentObject(navigationState)
    }
}
