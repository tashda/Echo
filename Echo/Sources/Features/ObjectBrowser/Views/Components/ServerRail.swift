import AppKit
import SwiftUI

/// Vertical rail of connected servers followed by the sidebar's secondary tools.
///
/// `.embedded` sits inside the open sidebar with no background of its own; a single glass lens
/// slides behind the active server. `.floating` is shown over the editor while the sidebar is
/// hidden and becomes its own glass capsule.
struct ServerRail: View {
    enum Style {
        case embedded
        case floating
    }

    let style: Style
    let sessions: [ConnectionSession]
    let pendingConnections: [PendingConnection]
    let savedConnections: [SavedConnection]
    let selectedConnectionID: UUID?
    @Binding var selectedSection: SidebarMenu.NavSection
    var bridge: ServerRailBridge?
    let onSelectSession: (ConnectionSession) -> Void
    let onRetryPending: (PendingConnection) -> Void
    let onConnect: (SavedConnection) -> Void
    /// Called after a tool is picked, so the floating rail can bring the sidebar back.
    var onToolSelected: () -> Void = {}

    @Namespace private var railNamespace
    /// Keeps the lens on a server the user just clicked while the Explorer scrolls to it.
    @State private var clickedConnectionID: UUID?
    @State private var showsConnectPicker = false

    var body: some View {
        let content = VStack(spacing: LayoutTokens.ServerRail.itemSpacing) {
            servers
            connectButton
            if style == .floating {
                Divider().frame(width: LayoutTokens.ServerRail.itemSize - SpacingTokens.xs)
                tools
            }
        }

        switch style {
        case .embedded:
            VStack(spacing: SpacingTokens.xs) {
                ScrollView(.vertical) {
                    content
                        .padding(.vertical, SpacingTokens.xxs)
                        .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.never)

                Divider().frame(width: LayoutTokens.ServerRail.itemSize - SpacingTokens.xs)
                tools.padding(.bottom, SpacingTokens.sm)
            }
            .frame(width: LayoutTokens.ServerRail.width)
            .frame(maxHeight: .infinity)
        case .floating:
            content
                .padding(.vertical, LayoutTokens.ServerRail.floatingPadding)
                .padding(.horizontal, LayoutTokens.ServerRail.floatingPadding)
                .glassEffect(.regular, in: .capsule)
        }
    }

    // MARK: - Servers

    private var entries: [ServerRailEntry] {
        sessions.map(ServerRailEntry.session) + pendingConnections.map(ServerRailEntry.pending)
    }

    private var highlightedConnectionID: UUID? {
        let candidate = clickedConnectionID
            ?? bridge?.topVisibleConnectionID
            ?? selectedConnectionID
        if let candidate, entries.contains(where: { $0.connectionID == candidate }) {
            return candidate
        }
        return entries.first?.connectionID
    }

    private var servers: some View {
        ZStack(alignment: .top) {
            if let highlightedConnectionID {
                lens
                    .matchedGeometryEffect(
                        id: highlightedConnectionID,
                        in: railNamespace,
                        properties: .position,
                        isSource: false
                    )
            }

            VStack(spacing: LayoutTokens.ServerRail.itemSpacing) {
                ForEach(entries) { entry in
                    item(for: entry)
                        .matchedGeometryEffect(
                            id: entry.connectionID,
                            in: railNamespace,
                            properties: .position,
                            isSource: true
                        )
                }
            }
        }
        .animation(.bouncy(duration: 0.45, extraBounce: 0.1), value: highlightedConnectionID)
        .animation(.snappy(duration: 0.3), value: entries.map(\.id))
    }

    /// The only glass in the embedded rail. Drawn behind the monograms so they stay crisp.
    @ViewBuilder
    private var lens: some View {
        let size = LayoutTokens.ServerRail.itemSize
        switch style {
        case .embedded:
            Circle()
                .fill(Color.clear)
                .frame(width: size, height: size)
                .glassEffect(.regular, in: .circle)
                .allowsHitTesting(false)
        case .floating:
            // Already on glass, so the selection is a soft fill like the macOS tab bar's.
            Circle()
                .fill(ColorTokens.Sidebar.selectedFill)
                .frame(width: size, height: size)
                .allowsHitTesting(false)
        }
    }

    private func item(for entry: ServerRailEntry) -> some View {
        let isActive = entry.connectionID == highlightedConnectionID
        let status = entry.status

        return Button {
            activate(entry)
        } label: {
            ServerRailItem(
                monogram: ServerRailMonogram.make(from: entry.displayName),
                status: status,
                isActive: isActive
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .lazyContextMenu { menu(for: entry) }
        .accessibilityLabel(entry.displayName)
        .accessibilityValue(status.accessibilityDescription)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func activate(_ entry: ServerRailEntry) {
        switch entry {
        case .session(let session):
            let connectionID = session.connection.id
            clickedConnectionID = connectionID
            selectedSection = .folder
            onSelectSession(session)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(700))
                if clickedConnectionID == connectionID {
                    clickedConnectionID = nil
                }
            }
        case .pending(let pending):
            if case .failed = pending.phase {
                onRetryPending(pending)
            }
        }
    }

    private func menu(for entry: ServerRailEntry) -> NSMenu {
        switch entry {
        case .session(let session):
            return bridge?.sessionMenu?(session) ?? NSMenu()
        case .pending(let pending):
            return bridge?.pendingMenu?(pending) ?? NSMenu()
        }
    }

    private var connectButton: some View {
        Button {
            showsConnectPicker.toggle()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: LayoutTokens.ServerRail.itemSize, height: LayoutTokens.ServerRail.itemSize)
                .background(Circle().strokeBorder(ColorTokens.Text.quaternary, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel("Connect to a Server")
        .popover(isPresented: $showsConnectPicker, arrowEdge: .trailing) {
            ServerRailConnectPicker(
                connections: savedConnections,
                connectedIDs: Set(entries.map(\.connectionID)),
                onConnect: { connection in
                    showsConnectPicker = false
                    onConnect(connection)
                },
                onManage: {
                    showsConnectPicker = false
                    ManageConnectionsWindowController.shared.present()
                }
            )
        }
    }

    // MARK: - Tools

    private var tools: some View {
        VStack(spacing: SpacingTokens.xxs) {
            ForEach(SidebarMenu.NavSection.railTools, id: \.self) { section in
                toolButton(section)
            }
        }
    }

    private func toolButton(_ section: SidebarMenu.NavSection) -> some View {
        let isSelected = selectedSection == section && style == .embedded

        return Button {
            selectedSection = isSelected ? .folder : section
            onToolSelected()
        } label: {
            Image(systemName: section.icon)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(isSelected ? Color.accentColor : ColorTokens.Text.secondary)
                .frame(width: LayoutTokens.ServerRail.itemSize, height: LayoutTokens.ServerRail.toolHeight)
                .background(
                    isSelected ? Color.accentColor.opacity(0.12) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(section.displayName)
        .accessibilityLabel(section.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension SidebarMenu.NavSection {
    /// Tools reachable from the bottom of the server rail. Explorer is the sidebar itself;
    /// connecting happens through the rail's + button.
    static let railTools: [SidebarMenu.NavSection] = [.search, .bookmark, .snippets, .history, .clipboard]
}

/// A server's monogram in the rail. Healthy servers show only the monogram; connecting servers
/// are dimmed and lost connections get a red badge.
struct ServerRailItem: View {
    let monogram: String
    let status: ServerRailStatus
    let isActive: Bool

    var body: some View {
        Text(monogram)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(isActive ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
            .opacity(monogramOpacity)
            .frame(width: LayoutTokens.ServerRail.itemSize, height: LayoutTokens.ServerRail.itemSize)
            .contentShape(Circle())
            .overlay(alignment: .topTrailing) {
                if status == .failed {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, ColorTokens.Status.error)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.25), value: status)
    }

    private var monogramOpacity: Double {
        switch status {
        case .ready: return 1
        case .connecting: return 0.45
        case .failed: return 0.4
        }
    }
}
