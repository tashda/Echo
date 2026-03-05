import SwiftUI
#if os(macOS)
import AppKit
#endif

struct BreadcrumbNavigator: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @EnvironmentObject private var environmentState: EnvironmentState
    @EnvironmentObject private var appearanceStore: AppearanceStore
    @EnvironmentObject private var layoutState: TopBarNavigatorLayoutState
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var navigationState = BreadcrumbNavigationState()
#if os(macOS)
    @State private var activePopoverController: NSViewController?
#endif

    var body: some View {
        GeometryReader { proxy in
            let available = max(layoutState.availableWidth > 0 ? layoutState.availableWidth : proxy.size.width, 0)
            let controlHeight = max(WorkspaceChromeMetrics.chromeBackgroundHeight, proxy.size.height)
            let target = min(clamp(available * (layoutState.availableWidth > 0 ? 0.9 : 0.65), minWidth: 420, idealWidth: 540, maxWidth: 880), available)

            ZStack {
                let shape = RoundedRectangle(cornerRadius: controlHeight / 2, style: .continuous)
#if os(macOS)
                if #available(macOS 15, *) { shape.fill(.clear).glassEffect().frame(width: target, height: controlHeight) }
                else { shape.fill(.clear).background(.regularMaterial, in: shape).overlay(shape.stroke(capsuleBorder, lineWidth: 1)).frame(width: target, height: controlHeight) }
#else
                shape.fill(.clear).background(.regularMaterial, in: shape).overlay(shape.stroke(capsuleBorder, lineWidth: 1)).frame(width: target, height: controlHeight)
#endif
                HStack(spacing: 0) {
                    breadcrumbContent; Spacer(minLength: 0); breadcrumbStatus
                }
                .padding(.horizontal, SpacingTokens.md).frame(width: target, height: controlHeight, alignment: .leading).clipShape(shape)
            }
            .frame(width: target, height: controlHeight)
            .position(x: layoutState.centerX > 0 ? layoutState.centerX : proxy.size.width / 2, y: proxy.size.height / 2)
            .backgroundPreferenceValue(BreadcrumbAnchorKey.self) { breadcrumbPopover(anchors: $0) }
            .onAppear { updateBreadcrumbSegments() }
            .onChange(of: connectionStore.selectedConnectionID) { _, _ in updateBreadcrumbSegments() }
            .onChange(of: environmentState.sessionCoordinator.sessions.count) { _, _ in updateBreadcrumbSegments() }
            .onChange(of: environmentState.sessionCoordinator.activeSession?.selectedDatabaseName) { _, _ in updateBreadcrumbSegments() }
            .onChange(of: navigationState.isMenuPresented) { _, isP in if !isP { navigationState.presentedMenuIndex = nil; activePopoverController = nil } }
        }
        .accessibilityIdentifier("breadcrumb-navigator")
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var breadcrumbContent: some View {
        if navigationState.segments.isEmpty { connectionsSegment }
        else { ForEach(Array(navigationState.segments.enumerated()), id: \.element.id) { breadcrumbSegmentView(for: $1, at: $0) } }
    }

    private var connectionsSegment: some View {
        BreadcrumbSegmentView(segment: defaultConnectionsSegment, isLast: true, onTap: { defaultConnectionsSegment.action?() }, onMenuTap: { presentMenu(for: 0, segment: defaultConnectionsSegment) })
            .anchorPreference(key: BreadcrumbAnchorKey.self, value: .bounds) { [BreadcrumbAnchorInfo(index: 0, anchor: $0)] }
    }

    private var defaultConnectionsSegment: BreadcrumbSegment {
        BreadcrumbSegment(title: "Connections", icon: "server.rack", hasMenu: true, isActive: true, isEnabled: true, action: nil, menuContent: { AnyView(ConnectionsBreadcrumbMenu()) })
    }

    private func breadcrumbSegmentView(for segment: BreadcrumbSegment, at index: Int) -> some View {
        BreadcrumbSegmentView(segment: segment, isLast: index == navigationState.segments.count - 1, onTap: { segment.action?() }, onMenuTap: { presentMenu(for: index, segment: segment) })
            .anchorPreference(key: BreadcrumbAnchorKey.self, value: .bounds) { [BreadcrumbAnchorInfo(index: index, anchor: $0)] }
    }

    @ViewBuilder
    private var breadcrumbStatus: some View {
        if let status = statusText { Text(status).font(TypographyTokens.detail).foregroundStyle(.secondary).lineLimit(1) }
    }

    @ViewBuilder
    private func breadcrumbPopover(anchors: [BreadcrumbAnchorInfo]) -> some View {
#if os(macOS)
        if navigationState.isMenuPresented, let index = navigationState.presentedMenuIndex, let controller = activePopoverController, let info = anchors.first(where: { $0.index == index }) {
            GeometryReader { proxy in Color.clear.background(NativePopoverController(controller: controller, isPresented: $navigationState.isMenuPresented, anchorRect: proxy[info.anchor])) }.allowsHitTesting(false)
        }
#endif
    }

    private var statusText: String? {
        guard let id = connectionStore.selectedConnectionID else { return "No Connection" }
        switch environmentState.connectionStates[id] {
        case .testing: return "Testing…"; case .connecting: return "Connecting…"; case .connected: return "Connected"; case .disconnected: return "Disconnected"; case .error: return "Error"; default: return environmentState.sessionCoordinator.sessionForConnection(id) != nil ? "Connected" : "Disconnected"
        }
    }

    private func presentMenu(for index: Int, segment: BreadcrumbSegment) {
        guard segment.hasMenu, segment.isEnabled else { return }
#if os(macOS)
        guard let controller = menuController(for: index) else { return }
        if navigationState.isMenuPresented {
            let same = navigationState.presentedMenuIndex == index; navigationState.isMenuPresented = false
            if !same { DispatchQueue.main.async { self.activePopoverController = controller; self.navigationState.presentMenu(for: index) } }
        } else { activePopoverController = controller; navigationState.presentMenu(for: index) }
#else
        navigationState.presentMenu(for: index)
#endif
    }

#if os(macOS)
    private func menuController(for index: Int) -> NSViewController? {
        switch index {
        case 0: return ConnectionsPopoverController(connectionStore: connectionStore, environmentState: environmentState)
        case 1: return connectionStore.selectedConnectionID.map { DatabasePopoverController(environmentState: environmentState, connectionID: $0) }
        default: return nil
        }
    }
#endif

    private func updateBreadcrumbSegments() {
        let connTitle = connectionStore.selectedConnection.map { $0.connectionName.isEmpty ? $0.host : $0.connectionName } ?? "Connections"
        let dbTitle = (connectionStore.selectedConnectionID.flatMap { environmentState.sessionCoordinator.sessionForConnection($0) }?.selectedDatabaseName).map { $0.isEmpty ? "Databases" : $0 } ?? "Databases"
        navigationState.updateSegments([
            BreadcrumbSegment(title: connTitle, icon: "server.rack", hasMenu: true),
            BreadcrumbSegment(title: dbTitle, icon: "cylinder.fill", hasMenu: true, isActive: connectionStore.selectedConnectionID != nil, isEnabled: connectionStore.selectedConnectionID != nil)
        ])
    }

    private var capsuleBorder: Color { #if os(macOS)
        Color(nsColor: .separatorColor)
#else
        Color.black.opacity(0.09)
#endif
    }
    private func clamp(_ v: CGFloat, minWidth: CGFloat, idealWidth: CGFloat, maxWidth: CGFloat) -> CGFloat { let c = max(minWidth, min(maxWidth, v)); return (c >= idealWidth && c <= maxWidth) ? max(idealWidth, c) : c }
}
