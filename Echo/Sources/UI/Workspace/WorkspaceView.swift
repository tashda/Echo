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

                    ResizableInspectorContainer(
                        width: widthBinding,
                        minWidth: WorkspaceLayoutMetrics.inspectorMinWidth,
                        maxWidth: WorkspaceLayoutMetrics.inspectorMaxWidth
                    ) {
                        InfoSidebarView()
                            .environmentObject(appModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(.top, WorkspaceChromeMetrics.chromeTopInset)
                            .padding(.bottom, 12)
                            .padding(.horizontal, 18)
                    }
                    .navigationSplitViewColumnWidth(
                        min: WorkspaceLayoutMetrics.inspectorMinWidth,
                        ideal: max(WorkspaceLayoutMetrics.inspectorMinWidth, widthBinding.wrappedValue),
                        max: WorkspaceLayoutMetrics.inspectorMaxWidth
                    )
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

private struct ResizableInspectorContainer<Content: View>: View {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    @ViewBuilder var content: Content

    @State private var dragStartWidth: CGFloat?
    @State private var isHoveringHandle = false

    private let handleWidth: CGFloat = 6
    private let dividerWidth: CGFloat = 1

    private func clamped(_ value: CGFloat) -> CGFloat {
        let upper = maxWidth.isFinite ? min(maxWidth, value) : value
        return max(minWidth, upper)
    }

    var body: some View {
        let contentWidth = clamped(width)
        let totalWidth = contentWidth + handleWidth + dividerWidth

        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.primary.opacity(isHoveringHandle ? 0.18 : 0.08))
                .frame(width: handleWidth)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if dragStartWidth == nil {
                                dragStartWidth = width
                            }
                            let proposed = (dragStartWidth ?? width) - value.translation.width
                            width = clamped(proposed)
                        }
                        .onEnded { _ in
                            width = clamped(width)
                            dragStartWidth = nil
                        }
                )
#if os(macOS)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHoveringHandle = hovering
                    }
                }
#endif

            Divider()
                .frame(width: dividerWidth)

            content
                .frame(width: contentWidth, alignment: .topLeading)
        }
        .frame(width: totalWidth)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color.clear)
        .onAppear {
            width = contentWidth
        }
    }
}

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
