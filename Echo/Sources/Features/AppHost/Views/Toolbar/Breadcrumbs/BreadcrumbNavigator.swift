import SwiftUI
#if os(macOS)
import AppKit
#endif

struct BreadcrumbNavigator: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @EnvironmentObject private var environmentState: EnvironmentState
    @EnvironmentObject private var appearanceStore: AppearanceStore
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var navigationState = BreadcrumbNavigationState()
    @State private var showConnectionsPopover = false
    @State private var showDatabasePopover = false

    var body: some View {
        GeometryReader { proxy in
            let hostingWidth = proxy.size.width
            let controlHeight = max(WorkspaceChromeMetrics.chromeBackgroundHeight, proxy.size.height)
            let target = max(hostingWidth * 0.82, 0)

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
            .position(x: hostingWidth / 2, y: proxy.size.height / 2)
            .onAppear { updateBreadcrumbSegments() }
            .onChange(of: connectionStore.selectedConnectionID) { _, _ in updateBreadcrumbSegments() }
            .onChange(of: environmentState.sessionCoordinator.sessions.count) { _, _ in updateBreadcrumbSegments() }
            .onChange(of: environmentState.sessionCoordinator.activeSession?.selectedDatabaseName) { _, _ in updateBreadcrumbSegments() }
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
        BreadcrumbSegmentView(segment: defaultConnectionsSegment, isLast: true, onTap: { defaultConnectionsSegment.action?() }, onMenuTap: { showConnectionsPopover = true })
            .popover(isPresented: $showConnectionsPopover, arrowEdge: .bottom) { connectionsPopoverContent }
    }

    private var defaultConnectionsSegment: BreadcrumbSegment {
        BreadcrumbSegment(title: "Connections", icon: "server.rack", hasMenu: true, isActive: true, isEnabled: true)
    }

    private func breadcrumbSegmentView(for segment: BreadcrumbSegment, at index: Int) -> some View {
        BreadcrumbSegmentView(segment: segment, isLast: index == navigationState.segments.count - 1, onTap: { segment.action?() }, onMenuTap: {
            if index == 0 { showConnectionsPopover = true }
            else if index == 1 { showDatabasePopover = true }
        })
        .popover(isPresented: index == 0 ? $showConnectionsPopover : $showDatabasePopover, arrowEdge: .bottom) {
            if index == 0 { connectionsPopoverContent }
            else { databasePopoverContent }
        }
    }

    @ViewBuilder
    private var connectionsPopoverContent: some View {
        ConnectionsPopoverContent(
            connectionStore: connectionStore,
            environmentState: environmentState,
            dismiss: { showConnectionsPopover = false }
        )
        .presentationBackground(.clear)
    }

    @ViewBuilder
    private var databasePopoverContent: some View {
        if connectionStore.selectedConnectionID != nil {
            DatabaseBreadcrumbMenu()
                .presentationBackground(.clear)
        }
    }

    @ViewBuilder
    private var breadcrumbStatus: some View {
        if let status = statusText { Text(status).font(TypographyTokens.detail).foregroundStyle(.secondary).lineLimit(1) }
    }

    private var statusText: String? {
        guard let id = connectionStore.selectedConnectionID else { return "No Connection" }
        switch environmentState.connectionStates[id] {
        case .testing: return "Testing…"; case .connecting: return "Connecting…"; case .connected: return "Connected"; case .disconnected: return "Disconnected"; case .error: return "Error"; default: return environmentState.sessionCoordinator.sessionForConnection(id) != nil ? "Connected" : "Disconnected"
        }
    }

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
}
