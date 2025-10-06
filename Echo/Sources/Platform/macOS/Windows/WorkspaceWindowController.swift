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
    private unowned let coordinator: AppCoordinator
    private var hostingController: NSHostingController<WorkspaceRootView>?
    private var titleCancellable: AnyCancellable?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator

        let contentRect = NSRect(x: 0, y: 0, width: 1200, height: 800)
        let style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        let window = TitlebarTabsWindow(
            contentRect: contentRect,
            styleMask: style,
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        window.title = "Echo"
        window.delegate = self
        window.minSize = NSSize(width: 960, height: 600)
        window.tabbingMode = .disallowed
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbar = nil
        window.titlebarSeparatorStyle = .none
        window.preferredBackgroundColor = nil

        let rootView = WorkspaceRootView(
            appModel: coordinator.appModel,
            appState: coordinator.appState,
            clipboardHistory: coordinator.clipboardHistory,
            themeManager: ThemeManager.shared
        )

        let hosting = NSHostingController(rootView: rootView)
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        window.contentViewController = hosting
        self.hostingController = hosting
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

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        titleCancellable?.cancel()
        coordinator.workspaceWindowWillClose(self)
    }

    func windowDidBecomeMain(_ notification: Notification) {
        coordinator.workspaceWindowDidBecomeMain(self)
    }

    // MARK: - Title Handling

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

// MARK: - Root View Wrapper

private struct WorkspaceRootView: View {
    let appModel: AppModel
    let appState: AppState
    let clipboardHistory: ClipboardHistoryStore
    let themeManager: ThemeManager

    var body: some View {
        ContentView()
            .environmentObject(appModel)
            .environmentObject(appState)
            .environmentObject(themeManager)
            .environmentObject(clipboardHistory)
            .environment(\.useNativeTabBar, false)
            .ignoresSafeArea(.container, edges: .top)
    }
}
