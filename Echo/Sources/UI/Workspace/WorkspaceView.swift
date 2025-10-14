import SwiftUI
#if os(macOS)
import AppKit
import ObjectiveC.runtime
#endif

struct WorkspaceView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var navigationState: NavigationState
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore

    var body: some View {
        NavigationSplitView {
            SidebarColumn()
                .navigationSplitViewColumnWidth(
                    min: WorkspaceLayoutMetrics.sidebarMinWidth,
                    ideal: WorkspaceLayoutMetrics.sidebarIdealWidth
                )
        } detail: {
            WorkspaceMainContent()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(themeManager.windowBackgroundColor)
#if !os(macOS)
                .toolbar {
                    WorkspaceToolbarItems()
                }
#endif
                .inspector(isPresented: $appState.showInfoSidebar) {
                    InfoSidebarView()
                        .environmentObject(appModel)
                        .frame(
                            minWidth: WorkspaceLayoutMetrics.inspectorMinWidth,
                            idealWidth: WorkspaceLayoutMetrics.inspectorIdealWidth,
                            maxWidth: WorkspaceLayoutMetrics.inspectorMaxWidth,
                            maxHeight: .infinity,
                            alignment: .topLeading
                        )
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                }
        }
        .navigationSplitViewStyle(.balanced)
        .background(WorkspaceWindowConfigurator())
        .sheet(
            isPresented: Binding(
                get: { appState.activeSheet == .connectionEditor },
                set: { isPresented in
                    if !isPresented {
                        appState.dismissSheet()
                    }
                }
            )
        ) {
            ConnectionEditorView(
                connection: appModel.selectedConnection,
                onSave: { connection, password, action in
                    Task {
                        await appModel.upsertConnection(connection, password: password)
                        if action == .saveAndConnect {
                            await appModel.connect(to: connection)
                        }
                        await MainActor.run {
                            appState.dismissSheet()
                        }
                    }
                }
            )
            .environmentObject(appModel)
            .environmentObject(appState)
        }
        .sheet(isPresented: $appModel.showManageProjectsSheet) {
            ManageProjectsSheet()
                .environmentObject(appModel)
                .environmentObject(clipboardHistory)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $appModel.showNewProjectSheet) {
            NewProjectSheet()
                .environmentObject(appModel)
        }
        .task {
            if !AppCoordinator.shared.isInitialized {
                await AppCoordinator.shared.initialize()
            }
        }
        .preferredColorScheme(themeManager.effectiveColorScheme)
        .accentColor(themeManager.accentColor)
    }
}

private struct SidebarColumn: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        SidebarView(
            selectedConnectionID: Binding(
                get: { appModel.selectedConnectionID },
                set: { appModel.selectedConnectionID = $0 }
            ),
            selectedIdentityID: Binding(
                get: { appModel.selectedIdentityID },
                set: { appModel.selectedIdentityID = $0 }
            ),
            onAddConnection: { appState.showSheet(.connectionEditor) }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct WorkspaceMainContent: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        QueryTabsView(
            showsTabStrip: true,
            tabBarLeadingPadding: 8,
            tabBarTrailingPadding: 8
        )
        .environment(\.useNativeTabBar, false)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.windowBackgroundColor)
    }
}

private enum WorkspaceLayoutMetrics {
    static let sidebarMinWidth: CGFloat = 260
    static let sidebarIdealWidth: CGFloat = 320

    static let inspectorMinWidth: CGFloat = 220
    static let inspectorIdealWidth: CGFloat = 260
    static let inspectorMaxWidth: CGFloat = 360
}

#if os(macOS)
private struct WorkspaceWindowConfigurator: NSViewRepresentable {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var navigationState: NavigationState
    @EnvironmentObject private var themeManager: ThemeManager

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            configure(window: window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            configure(window: window)
        }
    }

    private func configure(window: NSWindow) {
        if window.titleVisibility != .visible {
            window.titleVisibility = .visible
        }
        if window.titlebarAppearsTransparent == false {
            window.titlebarAppearsTransparent = true
        }
        if window.title != " " {
            window.title = " "
        }

        WorkspaceToolbarInstaller.installIfNeeded(
            for: window,
            appModel: appModel,
            appState: appState,
            navigationState: navigationState,
            themeManager: themeManager
        )
    }
}

private final class WorkspaceToolbarInstaller {
    private static var coordinatorKey: UInt8 = 0

    static func installIfNeeded(
        for window: NSWindow,
        appModel: AppModel,
        appState: AppState,
        navigationState: NavigationState,
        themeManager: ThemeManager
    ) {
        if let existing = objc_getAssociatedObject(window, &coordinatorKey) as? WorkspaceToolbarCoordinator {
            existing.updateReferences(
                appModel: appModel,
                appState: appState,
                navigationState: navigationState,
                themeManager: themeManager
            )
            existing.refreshToolbar()
        } else {
            let coordinator = WorkspaceToolbarCoordinator(
                window: window,
                appModel: appModel,
                appState: appState,
                navigationState: navigationState,
                themeManager: themeManager
            )
            coordinator.install()
            objc_setAssociatedObject(window, &coordinatorKey, coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

private final class WorkspaceToolbarCoordinator: NSObject, NSToolbarDelegate {
    private weak var window: NSWindow?

    private var appModel: AppModel
    private var appState: AppState
    private var navigationState: NavigationState
    private var themeManager: ThemeManager

    private lazy var toolbar: NSToolbar = {
        let toolbar = NSToolbar(identifier: .workspace)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.allowsExtensionItems = false
        toolbar.sizeMode = .regular
        toolbar.centeredItemIdentifier = nil
        return toolbar
    }()

    init(
        window: NSWindow,
        appModel: AppModel,
        appState: AppState,
        navigationState: NavigationState,
        themeManager: ThemeManager
    ) {
        self.window = window
        self.appModel = appModel
        self.appState = appState
        self.navigationState = navigationState
        self.themeManager = themeManager
        super.init()
    }

    func install() {
        guard let window else { return }
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        window.toolbar?.showsBaselineSeparator = false
        refreshToolbar()
    }

    func updateReferences(
        appModel: AppModel,
        appState: AppState,
        navigationState: NavigationState,
        themeManager: ThemeManager
    ) {
        self.appModel = appModel
        self.appState = appState
        self.navigationState = navigationState
        self.themeManager = themeManager
    }

    func refreshToolbar() {
        toolbar.validateVisibleItems()
    }

    // MARK: - NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .toggleSidebar,
            .sidebarTrackingSeparator,
            .workspaceProject,
            .workspaceNavigatorGap,
            .workspaceServerDatabase,
            .flexibleSpace,
            .workspaceRefresh,
            .workspaceNewTab,
            .workspaceTabOverview,
            .workspaceInspector
        ]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .toggleSidebar,
            .sidebarTrackingSeparator,
            .workspaceProject,
            .workspaceNavigatorGap,
            .workspaceServerDatabase,
            .workspaceRefresh,
            .workspaceNewTab,
            .workspaceTabOverview,
            .workspaceInspector,
            .flexibleSpace,
            .space,
            .separator
        ]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case .toggleSidebar:
            return nil
        case .workspaceProject:
            return makeProjectItem()
        case .workspaceNavigatorGap:
            return makeNavigatorGapItem()
        case .workspaceServerDatabase:
            return makeServerDatabaseItem()
        case .workspaceRefresh:
            return makeRefreshItem()
        case .workspaceNewTab:
            return makeNewTabItem()
        case .workspaceTabOverview:
            return makeTabOverviewItem()
        case .workspaceInspector:
            return makeInspectorItem()
        default:
            return nil
        }
    }

    // MARK: Toolbar Items

    private func makeProjectItem() -> NSToolbarItem {
        hostingToolbarItem(
            identifier: .workspaceProject,
            label: "Project",
            view: ProjectToolbarHost(
                appModel: appModel,
                navigationState: navigationState
            )
        )
    }

    private func makeNavigatorGapItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: .workspaceNavigatorGap)
        let spacer = NSView(frame: NSRect(x: 0, y: 0, width: 14, height: 10))
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.widthAnchor.constraint(equalToConstant: 14).isActive = true
        spacer.heightAnchor.constraint(equalToConstant: 10).isActive = true
        item.label = ""
        item.paletteLabel = ""
        item.view = spacer
        item.minSize = spacer.frame.size
        item.maxSize = spacer.frame.size
        item.isEnabled = false
        item.visibilityPriority = .standard
        return item
    }

    private func makeServerDatabaseItem() -> NSToolbarItem {
        hostingToolbarItem(
            identifier: .workspaceServerDatabase,
            label: "Server & Database",
            view: ServerDatabaseToolbarHost(
                appModel: appModel,
                navigationState: navigationState
            )
        )
    }

    private func makeRefreshItem() -> NSToolbarItem {
        hostingToolbarItem(
            identifier: .workspaceRefresh,
            label: "Refresh",
            view: RefreshToolbarHost(
                appModel: appModel,
                navigationState: navigationState,
                themeManager: themeManager
            )
        )
    }

    private func makeNewTabItem() -> NSToolbarItem {
        hostingToolbarItem(
            identifier: .workspaceNewTab,
            label: "New Tab",
            view: NewTabToolbarHost(
                appModel: appModel,
                navigationState: navigationState
            )
        )
    }

    private func makeTabOverviewItem() -> NSToolbarItem {
        hostingToolbarItem(
            identifier: .workspaceTabOverview,
            label: "Tab Overview",
            view: TabOverviewToolbarHost(
                appModel: appModel,
                appState: appState
            )
        )
    }

    private func makeInspectorItem() -> NSToolbarItem {
        hostingToolbarItem(
            identifier: .workspaceInspector,
            label: "Inspector",
            view: InspectorToolbarHost(
                appState: appState
            )
        )
    }

    private func hostingToolbarItem<V: View>(
        identifier: NSToolbarItem.Identifier,
        label: String,
        view: V
    ) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = ""
        item.paletteLabel = label
        item.toolTip = label

        let hosting = NSHostingView(rootView: view)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        hosting.setContentHuggingPriority(.required, for: .horizontal)
        hosting.setContentHuggingPriority(.required, for: .vertical)
        hosting.setContentCompressionResistancePriority(.required, for: .horizontal)
        hosting.setContentCompressionResistancePriority(.required, for: .vertical)

        var size = hosting.fittingSize
        if size == .zero {
            size = NSSize(width: 140, height: 32)
        }
        hosting.frame = NSRect(origin: .zero, size: size)

        item.view = hosting
        item.minSize = size
        item.maxSize = NSSize(width: max(size.width, 260), height: size.height)
        item.visibilityPriority = .high
        return item
    }
}

// MARK: - Toolbar SwiftUI Hosts

private struct ProjectToolbarHost: View {
    @ObservedObject private var appModel: AppModel
    @ObservedObject private var navigationState: NavigationState

    init(appModel: AppModel, navigationState: NavigationState) {
        self._appModel = ObservedObject(wrappedValue: appModel)
        self._navigationState = ObservedObject(wrappedValue: navigationState)
    }

    var body: some View {
        ProjectToolbarMenuButton(
            appModel: appModel,
            navigationState: navigationState
        )
    }
}

private struct ServerDatabaseToolbarHost: View {
    @ObservedObject private var appModel: AppModel
    @ObservedObject private var navigationState: NavigationState

    init(appModel: AppModel, navigationState: NavigationState) {
        self._appModel = ObservedObject(wrappedValue: appModel)
        self._navigationState = ObservedObject(wrappedValue: navigationState)
    }

    var body: some View {
        ServerDatabaseToolbarButton(
            appModel: appModel,
            navigationState: navigationState
        )
    }
}

private struct RefreshToolbarHost: View {
    @ObservedObject private var appModel: AppModel
    @ObservedObject private var navigationState: NavigationState
    @ObservedObject private var themeManager: ThemeManager

    init(appModel: AppModel, navigationState: NavigationState, themeManager: ThemeManager) {
        self._appModel = ObservedObject(wrappedValue: appModel)
        self._navigationState = ObservedObject(wrappedValue: navigationState)
        self._themeManager = ObservedObject(wrappedValue: themeManager)
    }

    var body: some View {
        RefreshToolbarButton()
            .environmentObject(appModel)
            .environmentObject(navigationState)
            .environmentObject(themeManager)
            .labelStyle(.iconOnly)
    }
}

private struct NewTabToolbarHost: View {
    @ObservedObject private var appModel: AppModel
    @ObservedObject private var navigationState: NavigationState

    init(appModel: AppModel, navigationState: NavigationState) {
        self._appModel = ObservedObject(wrappedValue: appModel)
        self._navigationState = ObservedObject(wrappedValue: navigationState)
    }

    private var activeSession: ConnectionSession? {
        if let connection = navigationState.selectedConnection,
           let session = appModel.sessionManager.sessionForConnection(connection.id) {
            return session
        }
        return appModel.sessionManager.activeSession ?? appModel.sessionManager.activeSessions.first
    }

    var body: some View {
        Button {
            appModel.openQueryTab()
        } label: {
            Image(systemName: "plus")
        }
        .help("Open a new query tab")
        .disabled(activeSession == nil)
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .accessibilityLabel("New Tab")
    }
}

private struct TabOverviewToolbarHost: View {
    @ObservedObject private var appModel: AppModel
    @ObservedObject private var appState: AppState

    init(appModel: AppModel, appState: AppState) {
        self._appModel = ObservedObject(wrappedValue: appModel)
        self._appState = ObservedObject(wrappedValue: appState)
    }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.showTabOverview.toggle()
            }
        } label: {
            Image(systemName: appState.showTabOverview ? "rectangle.grid.2x2.fill" : "rectangle.grid.2x2")
        }
        .help(appState.showTabOverview ? "Hide Tab Overview" : "Show all tabs")
        .disabled(appModel.tabManager.tabs.isEmpty)
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .accessibilityLabel(appState.showTabOverview ? "Hide Tab Overview" : "Show Tab Overview")
    }
}

private struct InspectorToolbarHost: View {
    @ObservedObject private var appState: AppState

    init(appState: AppState) {
        self._appState = ObservedObject(wrappedValue: appState)
    }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.showInfoSidebar.toggle()
            }
        } label: {
            Image(systemName: appState.showInfoSidebar ? "sidebar.trailing" : "sidebar.right")
        }
        .help(appState.showInfoSidebar ? "Hide Inspector" : "Show Inspector")
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .accessibilityLabel(appState.showInfoSidebar ? "Hide Inspector" : "Show Inspector")
    }
}

private extension NSToolbar.Identifier {
    static let workspace = NSToolbar.Identifier("com.fuzee.workspace.toolbar")
}

private extension NSToolbarItem.Identifier {
    static let workspaceProject = NSToolbarItem.Identifier("com.fuzee.workspace.toolbar.project")
    static let workspaceNavigatorGap = NSToolbarItem.Identifier("com.fuzee.workspace.toolbar.navigatorGap")
    static let workspaceServerDatabase = NSToolbarItem.Identifier("com.fuzee.workspace.toolbar.serverDatabase")
    static let workspaceRefresh = NSToolbarItem.Identifier("com.fuzee.workspace.toolbar.refresh")
    static let workspaceNewTab = NSToolbarItem.Identifier("com.fuzee.workspace.toolbar.newTab")
    static let workspaceTabOverview = NSToolbarItem.Identifier("com.fuzee.workspace.toolbar.tabOverview")
    static let workspaceInspector = NSToolbarItem.Identifier("com.fuzee.workspace.toolbar.inspector")
}

#else
private struct WorkspaceWindowConfigurator: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { UIView() }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
#endif
