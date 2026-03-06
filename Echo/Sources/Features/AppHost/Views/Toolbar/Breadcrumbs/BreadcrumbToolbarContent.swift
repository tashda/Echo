import SwiftUI

#if os(macOS)
import AppKit

/// Native toolbar content for the breadcrumb pill, placed at `.principal`.
struct BreadcrumbToolbarContent: View {
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore
    @EnvironmentObject private var environmentState: EnvironmentState
    @StateObject private var navigationState = BreadcrumbNavigationState()

    var body: some View {
        HStack(spacing: 0) {
            breadcrumbContent
            Spacer(minLength: SpacingTokens.sm)
            breadcrumbStatus
        }
        .padding(.leading, SpacingTokens.xxs)
        .onAppear { updateBreadcrumbSegments() }
        .onChange(of: connectionStore.selectedConnectionID) { _, _ in updateBreadcrumbSegments() }
        .onChange(of: environmentState.sessionCoordinator.sessions.count) { _, _ in updateBreadcrumbSegments() }
        .onChange(of: environmentState.sessionCoordinator.activeSession?.selectedDatabaseName) { _, _ in updateBreadcrumbSegments() }
    }

    // MARK: - Breadcrumb Content

    @ViewBuilder
    private var breadcrumbContent: some View {
        if navigationState.segments.isEmpty {
            BreadcrumbSegmentView(
                segment: defaultConnectionsSegment,
                isLast: true,
                onTap: {},
                onMenuTap: { navigationStore.breadcrumbPopoverRequest = .connections }
            )
        } else {
            ForEach(Array(navigationState.segments.enumerated()), id: \.element.id) { index, segment in
                segmentView(for: segment, at: index)
            }
        }
    }

    private var defaultConnectionsSegment: BreadcrumbSegment {
        BreadcrumbSegment(title: "Connections", icon: "server.rack", hasMenu: true, isActive: true, isEnabled: true)
    }

    @ViewBuilder
    private func segmentView(for segment: BreadcrumbSegment, at index: Int) -> some View {
        let isLast = index == navigationState.segments.count - 1

        BreadcrumbSegmentView(segment: segment, isLast: isLast, onTap: {
            segment.action?()
        }, onMenuTap: {
            switch index {
            case 0: navigationStore.breadcrumbPopoverRequest = .connections
            case 1: navigationStore.breadcrumbPopoverRequest = .database
            default: break
            }
        })
    }

    // MARK: - Status

    @ViewBuilder
    private var breadcrumbStatus: some View {
        if let status = statusText {
            Text(status)
                .font(TypographyTokens.detail)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var statusText: String? {
        guard let id = connectionStore.selectedConnectionID else { return "No Connection" }
        switch environmentState.connectionStates[id] {
        case .testing: return "Testing\u{2026}"
        case .connecting: return "Connecting\u{2026}"
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .error: return "Error"
        default:
            return environmentState.sessionCoordinator.sessionForConnection(id) != nil ? "Connected" : "Disconnected"
        }
    }

    // MARK: - Segment Updates

    private func updateBreadcrumbSegments() {
        let connTitle = connectionStore.selectedConnection.map {
            $0.connectionName.isEmpty ? $0.host : $0.connectionName
        } ?? "Connections"

        let dbTitle = (connectionStore.selectedConnectionID.flatMap {
            environmentState.sessionCoordinator.sessionForConnection($0)
        }?.selectedDatabaseName).map {
            $0.isEmpty ? "Databases" : $0
        } ?? "Databases"

        navigationState.updateSegments([
            BreadcrumbSegment(title: connTitle, icon: "server.rack", hasMenu: true),
            BreadcrumbSegment(
                title: dbTitle, icon: "cylinder.fill", hasMenu: true,
                isActive: connectionStore.selectedConnectionID != nil,
                isEnabled: connectionStore.selectedConnectionID != nil
            )
        ])
    }
}
#endif
