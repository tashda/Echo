import SwiftUI

#if os(macOS)
import AppKit

/// Native toolbar content for the breadcrumb pill, placed at `.principal`.
///
/// Each segment uses a native SwiftUI `.popover()` anchored to the segment view.
/// On macOS 26, `.popover()` inside `ToolbarItem` positions correctly
/// (fixed in rdar://147954025).
struct BreadcrumbToolbarContent: View {
    @Environment(ConnectionStore.self) private var connectionStore
    @EnvironmentObject private var environmentState: EnvironmentState

    @State private var showConnectionsPopover = false
    @State private var showDatabasePopover = false

    var body: some View {
        HStack(spacing: 0) {
            connectionSegment
            separator
            databaseSegment

            Spacer(minLength: SpacingTokens.sm)

            statusLabel
        }
        .padding(.leading, SpacingTokens.xxs)
    }

    // MARK: - Segments

    private var connectionSegment: some View {
        BreadcrumbSegmentLabel(
            icon: "server.rack",
            title: connectionsTitle
        ) {
            showConnectionsPopover = true
        }
        .popover(isPresented: $showConnectionsPopover, arrowEdge: .bottom) {
            ConnectionsPopoverContent(
                connectionStore: connectionStore,
                environmentState: environmentState,
                dismiss: { showConnectionsPopover = false }
            )
            .environment(connectionStore)
            .environmentObject(environmentState)
        }
    }

    private var databaseSegment: some View {
        BreadcrumbSegmentLabel(
            icon: "cylinder.fill",
            title: databaseTitle,
            isEnabled: connectionStore.selectedConnectionID != nil
        ) {
            showDatabasePopover = true
        }
        .popover(isPresented: $showDatabasePopover, arrowEdge: .bottom) {
            DatabaseBreadcrumbMenu()
                .environment(connectionStore)
                .environmentObject(environmentState)
        }
        .disabled(connectionStore.selectedConnectionID == nil)
    }

    // MARK: - Separator

    private var separator: some View {
        Image(systemName: "chevron.compact.right")
            .font(.system(size: 14, weight: .ultraLight))
            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            .padding(.horizontal, 2)
    }

    // MARK: - Status

    @ViewBuilder
    private var statusLabel: some View {
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

    // MARK: - Titles

    private var connectionsTitle: String {
        connectionStore.selectedConnection.map {
            $0.connectionName.isEmpty ? $0.host : $0.connectionName
        } ?? "Connections"
    }

    private var databaseTitle: String {
        (connectionStore.selectedConnectionID.flatMap {
            environmentState.sessionCoordinator.sessionForConnection($0)
        }?.selectedDatabaseName).map {
            $0.isEmpty ? "Databases" : $0
        } ?? "Databases"
    }
}

// MARK: - Breadcrumb Segment Label

/// Individual breadcrumb segment with icon, title, hover glass highlight,
/// and dropdown chevron that appears on hover.
private struct BreadcrumbSegmentLabel: View {
    let icon: String
    let title: String
    var isEnabled: Bool = true
    let onTap: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    private var textColor: Color {
        if !isEnabled { return Color(nsColor: .tertiaryLabelColor) }
        if isPressed { return .primary.opacity(0.7) }
        return .primary
    }

    var body: some View {
        HStack(spacing: SpacingTokens.xxxs) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(textColor)

            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(textColor)

            Image(systemName: "chevron.down")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                .opacity(isHovered && isEnabled ? 1 : 0)
        }
        .padding(.horizontal, SpacingTokens.xxs)
        .padding(.vertical, SpacingTokens.xxxs)
        .contentShape(Capsule())
        .background {
            if isHovered && isEnabled {
                Capsule()
                    .fill(.clear)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
        }
        .onTapGesture {
            guard isEnabled else { return }
            onTap()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard isEnabled else { return }
                    if !isPressed { withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                }
                .onEnded { _ in
                    guard isEnabled else { return }
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
                }
        )
        .onHover { hovering in
            guard isEnabled else { return }
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
}

#endif
