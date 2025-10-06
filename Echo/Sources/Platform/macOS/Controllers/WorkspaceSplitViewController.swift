//
//  WorkspaceSplitViewController.swift
//  Echo
//
//  Created by Codex on 07/10/2025.
//

import AppKit
import SwiftUI
import Combine

final class WorkspaceSplitViewController: NSSplitViewController {
    private let appModel: AppModel
    private let appState: AppState
    private let clipboardHistory: ClipboardHistoryStore
    private let tabID: UUID?

    private var sidebarItem: NSSplitViewItem!
    private var contentItem: NSSplitViewItem!
    private var inspectorItem: NSSplitViewItem!
    private var cancellables = Set<AnyCancellable>()

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
        super.viewDidLoad()

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
        sidebarItem.minimumThickness = 200
        sidebarItem.maximumThickness = 400
        sidebarItem.holdingPriority = .init(251)
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
        contentItem.holdingPriority = .init(252)
        addSplitViewItem(contentItem)

        // Create inspector (right pane)
        let inspectorVC = InspectorViewController(appModel: appModel)
        inspectorItem = NSSplitViewItem(viewController: inspectorVC)
        inspectorItem.canCollapse = true
        inspectorItem.minimumThickness = 250
        inspectorItem.maximumThickness = 400
        inspectorItem.holdingPriority = .init(250)
        inspectorItem.isCollapsed = !appState.showInfoSidebar
        addSplitViewItem(inspectorItem)

        // Set default positions
        sidebarItem.viewController.view.widthAnchor.constraint(equalToConstant: 320).isActive = true
        inspectorItem.viewController.view.widthAnchor.constraint(equalToConstant: 300).isActive = true

        appState.$showInfoSidebar
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] show in
                guard let self else { return }
                let shouldCollapse = !show
                if self.inspectorItem.isCollapsed != shouldCollapse {
                    self.inspectorItem.animator().isCollapsed = shouldCollapse
                }
            }
            .store(in: &cancellables)
    }

    func toggleSidebar() {
        sidebarItem.isCollapsed.toggle()
    }

    func toggleInspector() {
        appState.showInfoSidebar.toggle()
    }
}

extension WorkspaceSplitViewController {
    func splitView(_ splitView: NSSplitView, didCollapseSubview subview: NSView) {
        guard subview === inspectorItem.viewController.view else { return }
        if appState.showInfoSidebar {
            appState.showInfoSidebar = false
        }
    }

    func splitView(_ splitView: NSSplitView, didExpandSubview subview: NSView) {
        guard subview === inspectorItem.viewController.view else { return }
        if !appState.showInfoSidebar {
            appState.showInfoSidebar = true
        }
    }
}
