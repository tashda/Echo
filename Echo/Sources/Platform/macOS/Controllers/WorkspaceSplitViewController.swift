//
//  WorkspaceSplitViewController.swift
//  Echo
//
//  Created by Codex on 07/10/2025.
//

import AppKit
import SwiftUI
import Combine

protocol WorkspaceSplitViewControllerLayoutDelegate: AnyObject {
    func workspaceSplitViewController(
        _ controller: WorkspaceSplitViewController,
        didUpdateNavigatorLayout layout: WorkspaceNavigatorLayout
    )
}

struct WorkspaceNavigatorLayout: Equatable {
    let leading: CGFloat
    let width: CGFloat
}

final class WorkspaceSplitViewController: NSSplitViewController {
    private let appModel: AppModel
    private let appState: AppState
    private let clipboardHistory: ClipboardHistoryStore
    private let tabID: UUID?

    private var sidebarItem: NSSplitViewItem!
    private var contentItem: NSSplitViewItem!
    private var inspectorItem: NSSplitViewItem!
    private var cancellables = Set<AnyCancellable>()
    private var pendingLayoutUpdate = false

    weak var layoutDelegate: WorkspaceSplitViewControllerLayoutDelegate?

    init(
        tabID: UUID?,
        appModel: AppModel,
        appState: AppState,
        clipboardHistory: ClipboardHistoryStore
    ) {
        self.tabID = tabID
        self.appModel = appModel
        self.appState = appState
        self.clipboardHistory = clipboardHistory
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {

        
        // Configure split view
        splitView.dividerStyle = .thin
        splitView.autosaveName = "WorkspaceSplitView"
        splitView.delegate = self

        // Create sidebar (left pane)
        let sidebarVC = SidebarViewController(
            appModel: appModel,
            appState: appState
        )
        sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebarItem.canCollapse = true
        sidebarItem.minimumThickness = 220
        sidebarItem.maximumThickness = 420
        sidebarItem.holdingPriority = .defaultHigh
        addSplitViewItem(sidebarItem)

        // Create main content (center pane)
        let contentVC = MainContentViewController(
            tabID: tabID,
            appModel: appModel,
            appState: appState,
            clipboardHistory: clipboardHistory
        )
        contentItem = NSSplitViewItem(viewController: contentVC)
        contentItem.minimumThickness = 600
        contentItem.holdingPriority = .defaultLow
        addSplitViewItem(contentItem)

        // Create inspector (right pane)
        let inspectorVC = InspectorViewController(appModel: appModel, appState: appState)
        inspectorItem = NSSplitViewItem(viewController: inspectorVC)
        inspectorItem.canCollapse = true
        inspectorItem.minimumThickness = 240
        inspectorItem.maximumThickness = 420
        inspectorItem.holdingPriority = .defaultHigh
        inspectorItem.isCollapsed = !appState.showInfoSidebar
        addSplitViewItem(inspectorItem)

        sidebarItem.preferredThicknessFraction = 0.23
        inspectorItem.preferredThicknessFraction = 0.22

        appState.$showInfoSidebar
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] show in
                guard let self else { return }
                let shouldCollapse = !show
                if self.inspectorItem.isCollapsed != shouldCollapse {
                    self.inspectorItem.animator().isCollapsed = shouldCollapse
                }
                self.requestNavigatorLayoutUpdate()
            }
            .store(in: &cancellables)

        requestNavigatorLayoutUpdate()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        requestNavigatorLayoutUpdate()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        requestNavigatorLayoutUpdate()
    }

    override func toggleSidebar(_ sender: Any?) {
        super.toggleSidebar(sender)
        requestNavigatorLayoutUpdate()
    }

    func toggleInspector() {
        appState.showInfoSidebar.toggle()
    }
}

extension WorkspaceSplitViewController {
    override func splitViewDidResizeSubviews(_ notification: Notification) {
        super.splitViewDidResizeSubviews(notification)
        requestNavigatorLayoutUpdate()
    }

    func splitView(_ splitView: NSSplitView, didCollapseSubview subview: NSView) {
        guard subview === inspectorItem.viewController.view else { return }
        if appState.showInfoSidebar {
            appState.showInfoSidebar = false
        }
        requestNavigatorLayoutUpdate()
    }

    func splitView(_ splitView: NSSplitView, didExpandSubview subview: NSView) {
        guard subview === inspectorItem.viewController.view else { return }
        if !appState.showInfoSidebar {
            appState.showInfoSidebar = true
        }
        requestNavigatorLayoutUpdate()
    }
}

private extension WorkspaceSplitViewController {
    func requestNavigatorLayoutUpdate() {
        guard !pendingLayoutUpdate else { return }
        pendingLayoutUpdate = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingLayoutUpdate = false
            guard let layout = self.currentNavigatorLayout() else { return }
            self.layoutDelegate?.workspaceSplitViewController(self, didUpdateNavigatorLayout: layout)
        }
    }

    func currentNavigatorLayout() -> WorkspaceNavigatorLayout? {
        guard isViewLoaded else { return nil }
        guard let contentView = contentItem?.viewController.view else { return nil }

        let frameInSplitView = contentView.convert(contentView.bounds, to: splitView)

        if let window = view.window, let contentSuperview = window.contentView {
            let frameInWindow = splitView.convert(frameInSplitView, to: contentSuperview)
            return WorkspaceNavigatorLayout(
                leading: frameInWindow.minX,
                width: frameInWindow.width
            )
        }

        return WorkspaceNavigatorLayout(
            leading: frameInSplitView.minX,
            width: frameInSplitView.width
        )
    }
}
