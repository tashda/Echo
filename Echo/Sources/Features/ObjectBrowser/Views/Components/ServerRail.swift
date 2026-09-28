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
    /// Running queries per connection ID, from the open tabs.
    let runningQueryCounts: [UUID: Int]
    @Binding var selectedSection: SidebarMenu.NavSection
    @Binding var isGlanceOpen: Bool
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
            glanceButton
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
                runningQueryCount: runningQueryCounts[entry.connectionID] ?? 0,
                isActive: isActive
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .lazyContextMenu { menu(for: entry) }
        .accessibilityLabel(entry.displayName)
        .accessibilityValue(accessibilityValue(status: status, entry: entry))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func accessibilityValue(status: ServerRailStatus, entry: ServerRailEntry) -> String {
        let running = runningQueryCounts[entry.connectionID] ?? 0
        guard status == .ready, running > 0 else { return status.accessibilityDescription }
        return running == 1 ? "1 query running" : "\(running) queries running"
    }

    private func activate(_ entry: ServerRailEntry) {
        switch entry {
        case .session(let session):
            let connectionID = session.connection.id
            clickedConnectionID = connectionID
            selectedSection = .folder
            isGlanceOpen = false
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

    private var totalRunningQueries: Int {
        runningQueryCounts.values.reduce(0, +)
    }

    private var glanceButton: some View {
        Button {
            isGlanceOpen.toggle()
        } label: {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(isGlanceOpen ? Color.accentColor : ColorTokens.Text.secondary)
                .frame(width: LayoutTokens.ServerRail.itemSize, height: LayoutTokens.ServerRail.itemSize)
                .background(
                    isGlanceOpen ? Color.accentColor.opacity(0.12) : Color.clear,
                    in: Circle()
                )
                .overlay(alignment: .topTrailing) {
                    if totalRunningQueries > 0 {
                        Text("\(totalRunningQueries)")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 15, minHeight: 15)
                            .background(Color.accentColor, in: Capsule())
                            .contentTransition(.numericText())
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("Open Queries (⌥⌘G)")
        .accessibilityLabel("Open Queries")
        .accessibilityValue(totalRunningQueries > 0 ? "\(totalRunningQueries) running" : "")
        .animation(.snappy(duration: 0.25), value: totalRunningQueries)
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

/// A server's monogram in the rail, with its status ring.
///
/// Healthy and idle servers show only the monogram. Connecting servers are dimmed while the ring
/// draws around them, and give a small spring pop once connected. Running queries orbit as a
/// comet. Lost connections are dimmed with a dashed red ring and a red badge.
struct ServerRailItem: View {
    let monogram: String
    let status: ServerRailStatus
    let runningQueryCount: Int
    let isActive: Bool

    @State private var connectedPulse = 0

    var body: some View {
        Text(monogram)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(isActive ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
            .opacity(monogramOpacity)
            .frame(width: LayoutTokens.ServerRail.itemSize, height: LayoutTokens.ServerRail.itemSize)
            .contentShape(Circle())
            .overlay {
                ServerRailStatusRing(status: status, isBusy: runningQueryCount > 0)
            }
            .overlay(alignment: .topTrailing) {
                if status == .failed {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, ColorTokens.Status.error)
                        .offset(x: LayoutTokens.ServerRail.ringOutset, y: -LayoutTokens.ServerRail.ringOutset)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .phaseAnimator([1.0, 1.14, 1.0], trigger: connectedPulse) { content, scale in
                content.scaleEffect(scale)
            } animation: { _ in
                .spring(duration: 0.24, bounce: 0.45)
            }
            .animation(.snappy(duration: 0.25), value: status)
            .animation(.snappy(duration: 0.25), value: isActive)
            .onChange(of: status) { oldStatus, newStatus in
                if oldStatus == .connecting && newStatus == .ready {
                    connectedPulse &+= 1
                }
            }
    }

    private var monogramOpacity: Double {
        switch status {
        case .ready: return 1
        case .connecting: return 0.45
        case .failed: return 0.4
        }
    }
}

extension TabStore {
    /// Number of query tabs currently executing, keyed by connection ID.
    var runningQueryCountsByConnection: [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for tab in tabs where tab.query?.isExecuting == true {
            counts[tab.connection.id, default: 0] += 1
        }
        return counts
    }
}

#if DEBUG
#Preview("Server Rail States") {
    HStack(spacing: SpacingTokens.lg) {
        ForEach(
            [
                ("Connected", ServerRailStatus.ready, 0),
                ("Connecting", ServerRailStatus.connecting, 0),
                ("Running", ServerRailStatus.ready, 1),
                ("Lost", ServerRailStatus.failed, 0),
            ],
            id: \.0
        ) { sample in
            VStack(spacing: SpacingTokens.xs) {
                ServerRailItem(monogram: "18", status: sample.1, runningQueryCount: sample.2, isActive: true)
                    .background {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: LayoutTokens.ServerRail.itemSize, height: LayoutTokens.ServerRail.itemSize)
                            .glassEffect(.regular, in: .circle)
                    }
                Text(sample.0)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }
    .padding(SpacingTokens.xl)
    .background(ColorTokens.Background.sidebar)
}
#endif
