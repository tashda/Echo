import AppKit
import SwiftUI

/// Vertical rail of connected servers followed by the sidebar's secondary tools.
///
/// `.embedded` sits inside the open sidebar with no background of its own. Servers rest on faint
/// discs, and the active server's monogram carries the rail's only glass; because that glass has
/// one shared identity inside a `GlassEffectContainer`, it flows from bubble to bubble as the
/// active server changes.
///
/// `.floating` is shown over the editor while the sidebar is hidden. Every server is its own
/// interactive glass bubble, spaced closely enough inside one container that neighbours melt
/// into a liquid column. Servers that connect or disconnect morph in and out, and the + bubble
/// sits in the same column, so a new server flows out of it.
struct ServerRail: View {
    enum Style {
        case embedded
        case floating
    }

    let style: Style
    @Binding var selectedSection: SidebarMenu.NavSection
    @Binding var isGlanceOpen: Bool
    var bridge: ServerRailBridge?
    let onSelectSession: (ConnectionSession) -> Void
    let onRetryPending: (PendingConnection) -> Void
    let onConnect: (SavedConnection) -> Void
    /// Called after a tool is picked, so the floating rail can bring the sidebar back.
    var onToolSelected: () -> Void = {}

    // The rail reads the stores itself so that connection, selection and query-state changes
    // redraw only the rail, never the Explorer beside it.
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(TabStore.self) private var tabStore

    @Namespace private var glassNamespace
    /// Keeps the lens on a server the user just clicked while the Explorer scrolls to it.
    @State private var clickedConnectionID: UUID?
    @State private var showsConnectPicker = false

    var body: some View {
        switch style {
        case .embedded:
            embeddedRail
        case .floating:
            floatingRail
        }
    }

    // MARK: - Layouts

    private var embeddedRail: some View {
        VStack(spacing: SpacingTokens.xs) {
            ScrollView(.vertical) {
                VStack(spacing: LayoutTokens.ServerRail.itemSpacing) {
                    GlassEffectContainer(spacing: LayoutTokens.ServerRail.glassMergeDistance) {
                        serverStack(spacing: LayoutTokens.ServerRail.itemSpacing)
                    }
                    connectButton
                    glanceButton
                }
                .padding(.vertical, SpacingTokens.xxs + LayoutTokens.ServerRail.ringOutset)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.never)
            .scrollClipDisabled()

            Divider()
                .frame(width: LayoutTokens.ServerRail.itemSize - SpacingTokens.xs)

            tools
                .padding(.bottom, SpacingTokens.sm)
        }
        .frame(width: LayoutTokens.ServerRail.width)
        .frame(maxHeight: .infinity)
    }

    private var floatingRail: some View {
        GlassEffectContainer(spacing: LayoutTokens.ServerRail.floatingMergeDistance) {
            VStack(spacing: LayoutTokens.ServerRail.floatingGroupSpacing) {
                // Servers and + are spaced inside the merge distance, so they melt together.
                VStack(spacing: LayoutTokens.ServerRail.floatingItemSpacing) {
                    serverStack(spacing: LayoutTokens.ServerRail.floatingItemSpacing)
                    connectButton
                }

                // Tools share one capsule, far enough away to stay a separate piece of glass.
                VStack(spacing: SpacingTokens.xxxs) {
                    glanceButton
                    tools
                }
                .padding(.vertical, SpacingTokens.xxs)
                .glassEffect(.regular, in: .capsule)
                .glassEffectID("server-rail-tools", in: glassNamespace)
            }
        }
    }

    // MARK: - Servers

    /// One entry per server. A connection that is being re-established while its old session
    /// is still open shows as that session, so a server never appears twice.
    private var entries: [ServerRailEntry] {
        let sessions = environmentState.sessionGroup.sessions
        let sessionConnectionIDs = Set(sessions.map(\.connection.id))
        return sessions.map(ServerRailEntry.session)
            + environmentState.pendingConnections
                .filter { !sessionConnectionIDs.contains($0.connection.id) }
                .map(ServerRailEntry.pending)
    }

    /// Running queries per connection ID, from the open tabs.
    private var runningQueryCounts: [UUID: Int] {
        tabStore.runningQueryCountsByConnection
    }

    private var highlightedConnectionID: UUID? {
        let candidate = clickedConnectionID
            ?? bridge?.topVisibleConnectionID
            ?? connectionStore.selectedConnectionID
        if let candidate, entries.contains(where: { $0.connectionID == candidate }) {
            return candidate
        }
        return entries.first?.connectionID
    }

    private func serverStack(spacing: CGFloat) -> some View {
        // Keyed by connection rather than entry, so a server keeps its place, its glass and its
        // state as it goes from connecting to connected.
        VStack(spacing: spacing) {
            ForEach(entries, id: \.connectionID) { entry in
                item(for: entry)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(.bouncy(duration: 0.45, extraBounce: 0.1), value: highlightedConnectionID)
        .animation(.bouncy(duration: 0.4), value: entries.map(\.connectionID))
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
                isActive: isActive,
                style: style,
                glassID: entry.connectionID,
                glassNamespace: glassNamespace
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

    // MARK: - Actions

    private var connectButton: some View {
        Button {
            showsConnectPicker.toggle()
        } label: {
            connectLabel
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel("Connect to a Server")
        .popover(isPresented: $showsConnectPicker, arrowEdge: .trailing) {
            ServerRailConnectPicker(
                connections: connectionStore.connections,
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

    @ViewBuilder
    private var connectLabel: some View {
        switch style {
        case .embedded:
            ServerRailButtonLabel(shape: .disc, isSelected: showsConnectPicker) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
            }
        case .floating:
            ServerRailButtonLabel(shape: .bare, isSelected: showsConnectPicker) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
            }
            .glassEffect(.regular.interactive(), in: .circle)
            .glassEffectID("server-rail-connect", in: glassNamespace)
        }
    }

    private var totalRunningQueries: Int {
        runningQueryCounts.values.reduce(0, +)
    }

    private var glanceButton: some View {
        Button {
            isGlanceOpen.toggle()
        } label: {
            ServerRailButtonLabel(shape: .roundedSquare, isSelected: isGlanceOpen) {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 13, weight: .regular))
            }
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
        VStack(spacing: SpacingTokens.xxxs) {
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
            ServerRailButtonLabel(
                shape: .roundedSquare,
                isSelected: isSelected,
                height: LayoutTokens.ServerRail.toolHeight
            ) {
                Image(systemName: section.icon)
                    .font(.system(size: 13, weight: .regular))
            }
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(section.displayName)
        .accessibilityLabel(section.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Label for the rail's non-server buttons (+, open queries, tools) with a hover state that
/// matches the server items.
struct ServerRailButtonLabel<Content: View>: View {
    enum Appearance {
        /// A resting disc like a server item, for actions that sit among the servers.
        case disc
        /// No resting fill; a rounded square appears on hover or selection.
        case roundedSquare
        /// No fill at all, for labels that sit on their own glass.
        case bare
    }

    let shape: Appearance
    var isSelected: Bool = false
    var height: CGFloat = LayoutTokens.ServerRail.itemSize
    @ViewBuilder let content: () -> Content

    @State private var isHovering = false

    var body: some View {
        content()
            .foregroundStyle(isSelected ? Color.accentColor : ColorTokens.Text.secondary)
            .frame(width: LayoutTokens.ServerRail.itemSize, height: height)
            .background { background }
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.snappy(duration: 0.2), value: isSelected)
    }

    @ViewBuilder
    private var background: some View {
        switch shape {
        case .disc:
            Circle().fill(fill(resting: ColorTokens.Sidebar.hoverFill))
        case .roundedSquare:
            RoundedRectangle(cornerRadius: LayoutTokens.ServerRail.toolCornerRadius, style: .continuous)
                .fill(fill(resting: .clear))
        case .bare:
            Color.clear
        }
    }

    private func fill(resting: Color) -> Color {
        if isSelected { return Color.accentColor.opacity(0.14) }
        return isHovering ? ColorTokens.Sidebar.selectedFill : resting
    }
}

extension SidebarMenu.NavSection {
    /// Tools reachable from the bottom of the server rail. Explorer is the sidebar itself;
    /// connecting happens through the rail's + button.
    static let railTools: [SidebarMenu.NavSection] = [.search, .bookmark, .snippets, .history, .clipboard]
}

/// A server's monogram in the rail, with its status ring.
///
/// In the open sidebar, servers rest on a faint disc that deepens on hover. The active server's
/// monogram turns the accent color and becomes the content of the rail's single glass lens,
/// like the selected item in a Finder sidebar. In the floating rail every server is a glass
/// bubble, and the active one is tinted with the accent color.
///
/// Healthy and idle servers show nothing else. Connecting servers are dimmed while the ring draws
/// around them, and give a small spring pop once connected. Running queries orbit as a comet.
/// Lost connections are dimmed with a dashed red ring and a red badge.
struct ServerRailItem: View {
    let monogram: String
    let status: ServerRailStatus
    let runningQueryCount: Int
    let isActive: Bool
    var style: ServerRail.Style = .embedded
    var glassID: UUID? = nil
    var glassNamespace: Namespace.ID? = nil

    @State private var isHovering = false
    @State private var connectedPulse = 0

    var body: some View {
        Text(monogram)
            .font(.system(size: 12.5, weight: isActive ? .bold : .semibold, design: .rounded))
            .foregroundStyle(isActive ? Color.accentColor : ColorTokens.Text.secondary)
            .opacity(monogramOpacity)
            .frame(width: LayoutTokens.ServerRail.itemSize, height: LayoutTokens.ServerRail.itemSize)
            .background {
                if style == .embedded && !isActive {
                    Circle()
                        .fill(isHovering ? ColorTokens.Sidebar.selectedFill : ColorTokens.Sidebar.hoverFill)
                        .transition(.opacity)
                }
            }
            .modifier(ServerRailItemGlass(
                style: style,
                isActive: isActive,
                glassID: glassID,
                namespace: glassNamespace
            ))
            .contentShape(Circle())
            .onHover { isHovering = $0 }
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
            .animation(.easeOut(duration: 0.12), value: isHovering)
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

/// Puts the monogram on glass: the single sliding lens in the open sidebar, or a bubble per
/// server in the floating rail. The monogram is the glass's content, so it renders crisply on top.
private struct ServerRailItemGlass: ViewModifier {
    private static let lensID = "server-rail-lens"

    let style: ServerRail.Style
    let isActive: Bool
    let glassID: UUID?
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            switch style {
            case .embedded:
                // One identity for the lens: when the active server changes, the glass leaves
                // one bubble and flows into the next instead of cross-fading.
                content
                    .glassEffect(isActive ? .regular.interactive() : .identity, in: .circle)
                    .glassEffectID(isActive ? Self.lensID : nil, in: namespace)
            case .floating:
                content
                    .glassEffect(
                        isActive
                            ? .regular.tint(Color.accentColor.opacity(0.22)).interactive()
                            : .regular.interactive(),
                        in: .circle
                    )
                    .glassEffectID(glassID, in: namespace)
            }
        } else {
            content
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
private struct ServerRailStatesPreview: View {
    @Namespace private var namespace

    var body: some View {
        GlassEffectContainer {
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
                        ServerRailItem(
                            monogram: "18",
                            status: sample.1,
                            runningQueryCount: sample.2,
                            isActive: true,
                            style: .floating,
                            glassID: UUID(),
                            glassNamespace: namespace
                        )
                        Text(sample.0)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
            }
        }
        .padding(SpacingTokens.xl)
        .background(ColorTokens.Background.primary)
    }
}

#Preview("Server Rail States") {
    ServerRailStatesPreview()
}
#endif
