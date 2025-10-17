import SwiftUI
#if os(macOS)
import AppKit
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
                .toolbar {
                    WorkspaceToolbarItems()
                }
                .inspector(isPresented: $appState.showInfoSidebar) {
                    let widthBinding = Binding<CGFloat>(
                        get: { appModel.inspectorWidth },
                        set: { newValue in
                            appModel.updateInspectorWidth(
                                newValue,
                                min: WorkspaceLayoutMetrics.inspectorMinWidth,
                                max: WorkspaceLayoutMetrics.inspectorMaxWidth
                            )
                        }
                    )

                    InfoSidebarView()
                        .environmentObject(appModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.top, WorkspaceChromeMetrics.chromeTopInset)
                        .padding(.bottom, 12)
                        .padding(.horizontal, 18)
#if os(macOS)
                        .background(
                            InspectorSplitViewConfigurator(
                                width: widthBinding,
                                minWidth: WorkspaceLayoutMetrics.inspectorMinWidth,
                                maxWidth: WorkspaceLayoutMetrics.inspectorMaxWidth
                            )
                        )
#endif
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

    static let inspectorMinWidth: CGFloat = 300
    static let inspectorIdealWidth: CGFloat = 400
    static let inspectorMaxWidth: CGFloat = 1600
}

#if os(macOS)
private struct InspectorSplitViewConfigurator: NSViewRepresentable {
    var width: Binding<CGFloat>
    let minWidth: CGFloat
    let maxWidth: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(width: width, minWidth: minWidth, maxWidth: maxWidth)
    }

    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.coordinator = context.coordinator
        context.coordinator.register(observedView: view)
        return view
    }

    func updateNSView(_ nsView: ObserverView, context: Context) {
        context.coordinator.width = width
        context.coordinator.minWidth = minWidth
        context.coordinator.maxWidth = maxWidth
        context.coordinator.register(observedView: nsView)
    }

    final class Coordinator {
        var width: Binding<CGFloat>
        var minWidth: CGFloat
        var maxWidth: CGFloat
        private weak var observedView: NSView?
        private var pendingUpdate = false
        private var lastAppliedWidth: CGFloat?

        init(width: Binding<CGFloat>, minWidth: CGFloat, maxWidth: CGFloat) {
            self.width = width
            self.minWidth = minWidth
            self.maxWidth = maxWidth
        }

        func register(observedView view: NSView) {
            if observedView !== view {
                observedView = view
            }
            scheduleUpdate()
        }

        private func scheduleUpdate() {
            guard !pendingUpdate else { return }
            pendingUpdate = true
            DispatchQueue.main.async { [weak self] in
                guard let self, let view = self.observedView else {
                    self?.pendingUpdate = false
                    return
                }
                self.pendingUpdate = false
                self.performUpdate(using: view)
            }
        }

        private func performUpdate(using nsView: NSView) {
            guard let (controller, splitView, index) = locateSplitViewInfo(from: nsView) else { return }

            let item = controller.splitViewItems[index]
            if item.minimumThickness != minWidth {
                item.minimumThickness = minWidth
            }
            if item.maximumThickness != maxWidth {
                item.maximumThickness = maxWidth
            }
            if item.holdingPriority != .defaultLow {
                item.holdingPriority = .defaultLow
            }

            guard let inspectorView = splitView.safeSubview(at: index) else { return }

            let desiredWidth = clamp(width.wrappedValue)
            let inspectorWidth = clamp(inspectorView.frame.width)

            let previouslyApplied = lastAppliedWidth ?? inspectorWidth

            if abs(desiredWidth - previouslyApplied) > 0.5 {
                // Programmatic width change; drive split view to desired width.
                if abs(inspectorWidth - desiredWidth) > 0.5 {
                    adjustDividerPosition(splitView: splitView, itemIndex: index, targetWidth: desiredWidth)
                }
                lastAppliedWidth = desiredWidth
            } else {
                // User-driven change; capture the new inspector width.
                if abs(inspectorWidth - desiredWidth) > 0.5 {
                    let clampedInspector = clamp(inspectorWidth)
                    if abs(width.wrappedValue - clampedInspector) > 0.1 {
                        width.wrappedValue = clampedInspector
                    }
                    lastAppliedWidth = clampedInspector
                } else {
                    lastAppliedWidth = desiredWidth
                }
            }
        }

        private func adjustDividerPosition(splitView: NSSplitView, itemIndex: Int, targetWidth: CGFloat) {
            guard itemIndex > 0 else { return }
            let dividerIndex = itemIndex - 1
            let totalWidth = splitView.bounds.width
            guard totalWidth > 0 else { return }
            let dividerPosition = max(0, min(totalWidth - targetWidth, totalWidth))
            let currentWidth = splitView.safeSubview(at: itemIndex)?.frame.width ?? 0

            if abs(currentWidth - targetWidth) > 0.5 {
                NSAnimationContext.beginGrouping()
                NSAnimationContext.current.duration = 0
                splitView.setPosition(dividerPosition, ofDividerAt: dividerIndex)
                NSAnimationContext.endGrouping()
            }
        }

        private func clamp(_ value: CGFloat) -> CGFloat {
            max(minWidth, min(maxWidth, value))
        }

        private func locateSplitViewInfo(from view: NSView) -> (NSSplitViewController, NSSplitView, Int)? {
            var responder: NSResponder? = view
            while let current = responder {
                if let controller = current as? NSSplitViewController {
                    let splitView = controller.splitView
                    for (index, item) in controller.splitViewItems.enumerated() {
                        if item.viewController.view.isDescendant(of: view) || view.isDescendant(of: item.viewController.view) {
                            return (controller, splitView, index)
                        }
                    }
                }
                responder = current.nextResponder
            }
            return nil
        }
    }

    final class ObserverView: NSView {
        weak var coordinator: Coordinator?

        override func layout() {
            super.layout()
            coordinator?.register(observedView: self)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            coordinator?.register(observedView: self)
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}

private extension NSSplitView {
    func safeSubview(at index: Int) -> NSView? {
        guard index >= 0 && index < subviews.count else { return nil }
        return subviews[index]
    }
}
#endif

#if os(macOS)
private struct WorkspaceWindowConfigurator: NSViewRepresentable {
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
        if window.identifier != AppWindowIdentifier.workspace {
            window.identifier = AppWindowIdentifier.workspace
        }

        if window.titleVisibility != .visible {
            window.titleVisibility = .visible
        }
        if window.titlebarAppearsTransparent == false {
            window.titlebarAppearsTransparent = true
        }
        if window.title != " " {
            window.title = " "
        }
        window.toolbarStyle = .unified
        if #unavailable(macOS 15) {
            window.toolbar?.showsBaselineSeparator = false
        }

        AppCoordinator.shared.appModel.isWorkspaceWindowKey =
            window.identifier == AppWindowIdentifier.workspace && window.isKeyWindow
    }
}

#else
private struct WorkspaceWindowConfigurator: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { UIView() }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
#endif
