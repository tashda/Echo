import AppKit
import SwiftUI

@MainActor
final class SettingsSplitContainerController: NSSplitViewController {
    private let selectionModel: SettingsSelectionModel
    private let toolbarBridge: SettingsNavigationBridge

    private let sidebarVC: AppKitSettingsSidebarViewController
    private let detailHost: NSHostingController<AnyView>

    init(selectionModel: SettingsSelectionModel, bridge: SettingsNavigationBridge) {
        self.selectionModel = selectionModel
        self.toolbarBridge = bridge

        self.sidebarVC = AppKitSettingsSidebarViewController(selectionModel: selectionModel)

        let detail = SettingsDetailView(toolbarBridge: bridge)
            .environmentObject(AppCoordinator.shared.appModel)
            .environmentObject(AppCoordinator.shared.appState)
            .environmentObject(AppCoordinator.shared.clipboardHistory)
            .environmentObject(ThemeManager.shared)
            .environmentObject(selectionModel)
        self.detailHost = NSHostingController(rootView: AnyView(detail))
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.isVertical = true
        splitView.dividerStyle = .thin

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebarItem.canCollapse = false
        sidebarItem.minimumThickness = 280
        sidebarItem.maximumThickness = 280

        let contentItem = NSSplitViewItem(viewController: detailHost)

        addSplitViewItem(sidebarItem)
        addSplitViewItem(contentItem)
    }
}

