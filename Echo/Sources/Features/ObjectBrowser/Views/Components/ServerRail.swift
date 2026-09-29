import AppKit
import SwiftUI

/// How a server in the rail was clicked. With the tree hidden, a plain click peeks and a
/// ⌘-click or double-click shows the tree (Design/05-components.md › Server rail).
enum ServerRailClick {
    case plain
    case command
    case double

    /// The click that triggered the current button action.
    @MainActor static var current: ServerRailClick {
        guard let event = NSApp.currentEvent else { return .plain }
        if event.clickCount >= 2 { return .double }
        if event.modifierFlags.contains(.command) { return .command }
        return .plain
    }
}

/// The server rail (Design/02-layout.md › Rail): two glass pills on the canvas at the window's
/// leading edge. Servers are on top, in a pill that hugs them, grows with a spring as they
/// connect and scrolls once it reaches the tools. The tools pill sits at the bottom.
///
/// The selected server rests on a white disc that moves with a liquid stretch. It follows the
/// server at the top of the tree while scrolling, and holds on a clicked server while the tree
/// glides to it. Connecting servers breathe and lost ones are dimmed; nothing else is drawn.
struct ServerRail: View {
    let bridge: ServerRailBridge
    let itemSize: CGFloat
    /// The tool page showing in place of the tree, if any.
    let selectedTool: SidebarMenu.NavSection?
    let onSelectSession: (ConnectionSession, ServerRailClick) -> Void
    let onRetryPending: (PendingConnection) -> Void
    let onSelectTool: (SidebarMenu.NavSection) -> Void

    // The rail reads the stores itself so that connection, selection and query-state changes
    // redraw only the rail, never the tree beside it.
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(TabStore.self) private var tabStore
    @Environment(\.echoMotion) private var motion

    /// Keeps the selection on a server the user just clicked while the tree scrolls to it.
    @State private var clickedConnectionID: UUID?
    /// Top and bottom edges of the selection disc, animated separately for the liquid stretch.
    @State private var selectionTop: CGFloat = 0
    @State private var selectionBottom: CGFloat = 0

    var body: some View {
        let entries = self.entries
        let highlightedID = highlightedConnectionID(in: entries)
        let entryIDs = entries.map(\.connectionID)

        VStack(spacing: SpacingTokens.none) {
            if !entries.isEmpty {
                serverPill(entries: entries, highlightedID: highlightedID)
                    // Takes all the height it needs before the gap above the tools.
                    .layoutPriority(1)
                    .transition(.scale(scale: 0.6, anchor: .top).combined(with: .opacity))
            }
            Spacer(minLength: LayoutTokens.Rail.minimumPillGap)
            toolPill
        }
        .frame(width: LayoutTokens.Rail.width(itemSize: itemSize))
        .frame(maxHeight: .infinity)
        .animation(motion.standard, value: entryIDs)
        .onAppear { placeSelection(on: highlightedID, in: entryIDs, animated: false) }
        .onChange(of: highlightedID) { oldID, newID in
            moveSelection(from: oldID, to: newID, in: entryIDs)
        }
        .onChange(of: entryIDs) { _, ids in
            placeSelection(on: highlightedID, in: ids, animated: true)
        }
        .onChange(of: itemSize) { _, _ in
            placeSelection(on: highlightedID, in: entryIDs, animated: false)
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

    /// The selected server: one just clicked, else the one at the top of the tree, else the
    /// selected connection, else the first.
    private func highlightedConnectionID(in entries: [ServerRailEntry]) -> UUID? {
        let candidate = clickedConnectionID
            ?? bridge.topVisibleConnectionID
            ?? connectionStore.selectedConnectionID
        if let candidate, entries.contains(where: { $0.connectionID == candidate }) {
            return candidate
        }
        return entries.first?.connectionID
    }

    private func serverPill(entries: [ServerRailEntry], highlightedID: UUID?) -> some View {
        let spacing = LayoutTokens.Rail.itemSpacing
        let padding = LayoutTokens.Rail.pillPadding
        let count = CGFloat(entries.count)
        // Every item has the same size, so the pill's natural height is exact without measuring.
        let contentHeight = count * itemSize + max(0, count - 1) * spacing + padding * 2
        let runningCounts = tabStore.runningQueryCountsByConnection

        return ScrollViewReader { proxy in
            ScrollView(.vertical) {
                ZStack(alignment: .top) {
                    selectionDisc(isVisible: highlightedID != nil)

                    // Keyed by connection rather than entry, so a server keeps its place and its
                    // state as it goes from connecting to connected.
                    VStack(spacing: spacing) {
                        ForEach(entries, id: \.connectionID) { entry in
                            item(
                                for: entry,
                                isSelected: entry.connectionID == highlightedID,
                                runningQueryCount: runningCounts[entry.connectionID] ?? 0
                            )
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                        }
                    }
                }
                .padding(padding)
            }
            .scrollIndicators(.never)
            .scrollBounceBehavior(.basedOnSize)
            // Hugs its servers, and only scrolls once they outgrow the space above the tools.
            .frame(maxHeight: contentHeight)
            .glassEffect(.regular, in: .capsule)
            .onChange(of: highlightedID) { _, id in
                // Scrolls only as far as needed, so a visible selection never moves the rail.
                guard let id else { return }
                withAnimation(motion.standard) { proxy.scrollTo(id) }
            }
        }
    }

    private func selectionDisc(isVisible: Bool) -> some View {
        Capsule()
            .fill(ColorTokens.Workspace.railSelection)
            .shadow(ShadowTokens.railSelection)
            .frame(width: itemSize, height: max(itemSize, selectionBottom - selectionTop))
            .offset(y: selectionTop)
            .opacity(isVisible ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func item(for entry: ServerRailEntry, isSelected: Bool, runningQueryCount: Int) -> some View {
        let status = entry.status

        return Button {
            activate(entry)
        } label: {
            ServerRailItem(
                monogram: ServerRailMonogram.make(from: entry.displayName),
                color: entry.connection.color,
                status: status,
                isSelected: isSelected,
                size: itemSize
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(entry.tooltip(runningQueryCount: runningQueryCount))
        .lazyContextMenu { menu(for: entry) }
        .accessibilityLabel(entry.displayName)
        .accessibilityValue(accessibilityValue(for: entry, runningQueryCount: runningQueryCount))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func accessibilityValue(for entry: ServerRailEntry, runningQueryCount: Int) -> String {
        let status = entry.status
        guard status == .ready, runningQueryCount > 0 else { return status.accessibilityDescription }
        return runningQueryCount == 1 ? "1 query running" : "\(runningQueryCount) queries running"
    }

    private func activate(_ entry: ServerRailEntry) {
        let click = ServerRailClick.current
        switch entry {
        case .session(let session):
            let connectionID = session.connection.id
            clickedConnectionID = connectionID
            onSelectSession(session, click)
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
            return bridge.sessionMenu?(session) ?? NSMenu()
        case .pending(let pending):
            return bridge.pendingMenu?(pending) ?? NSMenu()
        }
    }

    // MARK: - Selection motion

    private func offset(of id: UUID?, in ids: [UUID]) -> CGFloat? {
        guard let id, let index = ids.firstIndex(of: id) else { return nil }
        return CGFloat(index) * (itemSize + LayoutTokens.Rail.itemSpacing)
    }

    private func placeSelection(on id: UUID?, in ids: [UUID], animated: Bool) {
        guard let top = offset(of: id, in: ids) else { return }
        let place = {
            selectionTop = top
            selectionBottom = top + itemSize
        }
        if animated {
            withAnimation(motion.standard, place)
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, place)
        }
    }

    /// The leading edge races to the target and the trailing edge follows, so the disc stretches
    /// toward it like a drop of liquid and settles back (Design/04-motion.md).
    private func moveSelection(from oldID: UUID?, to newID: UUID?, in ids: [UUID]) {
        guard let target = offset(of: newID, in: ids) else { return }
        guard !motion.reduceMotion, let origin = offset(of: oldID, in: ids), origin != target else {
            placeSelection(on: newID, in: ids, animated: true)
            return
        }
        if target > origin {
            withAnimation(motion.liquidLead) { selectionBottom = target + itemSize }
            withAnimation(motion.liquidTrail) { selectionTop = target }
        } else {
            withAnimation(motion.liquidLead) { selectionTop = target }
            withAnimation(motion.liquidTrail) { selectionBottom = target + itemSize }
        }
    }

    // MARK: - Tools

    private var toolPill: some View {
        VStack(spacing: LayoutTokens.Rail.toolSpacing) {
            ForEach(SidebarMenu.NavSection.railTools, id: \.self) { section in
                toolButton(section)
            }
        }
        .padding(.vertical, LayoutTokens.Rail.pillPadding)
        .glassEffect(.regular, in: .capsule)
    }

    private func toolButton(_ section: SidebarMenu.NavSection) -> some View {
        let isSelected = selectedTool == section

        return Button {
            onSelectTool(section)
        } label: {
            ServerRailToolLabel(symbol: section.icon, isSelected: isSelected, width: itemSize)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(section.displayName)
        .accessibilityLabel(section.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension SidebarMenu.NavSection {
    /// Tools in the rail's bottom pill. Search lives in the toolbar and connecting in the
    /// toolbar's connection menus (Design/02-layout.md › Rail).
    static let railTools: [SidebarMenu.NavSection] = [.bookmark, .snippets, .history, .clipboard]
}

/// A server's monogram in the rail: secondary grey, or bold in the server's own colour when
/// selected. A connecting server breathes; a lost one is dimmed.
struct ServerRailItem: View {
    let monogram: String
    let color: Color
    let status: ServerRailStatus
    let isSelected: Bool
    let size: CGFloat

    @Environment(\.echoMotion) private var motion
    @State private var isHovering = false

    var body: some View {
        Text(monogram)
            .font(.system(
                size: size * LayoutTokens.Rail.monogramFontRatio,
                weight: isSelected ? .bold : .semibold,
                design: .rounded
            ))
            .foregroundStyle(foreground)
            .opacity(status == .failed ? LayoutTokens.Rail.lostOpacity : 1)
            .modifier(ServerRailBreathing(isActive: status == .connecting))
            .frame(width: size, height: size)
            .contentShape(Circle())
            .onHover { isHovering = $0 }
            .animation(motion.hover, value: isHovering)
            .animation(motion.press, value: isSelected)
            .animation(motion.standard, value: status)
    }

    private var foreground: Color {
        if isSelected { return color }
        return isHovering ? ColorTokens.Text.primary : ColorTokens.Text.secondary
    }
}

/// Fades a connecting server in and out, dipping slightly in size, until it connects
/// (Design/06-tokens.md). With Reduce Motion it is shown still and dimmed instead.
struct ServerRailBreathing: ViewModifier {
    let isActive: Bool

    @Environment(\.echoMotion) private var motion

    func body(content: Content) -> some View {
        if !isActive {
            content
        } else if !motion.allowsLoopingEffects {
            content.opacity(LayoutTokens.Rail.lostOpacity)
        } else {
            let halfPeriod = motion.pulseHalfPeriod
            content.phaseAnimator([false, true]) { view, isDimmed in
                view
                    .opacity(isDimmed ? EchoMotion.pulseMinimumOpacity : 1)
                    .scaleEffect(isDimmed ? EchoMotion.pulseMinimumScale : 1)
            } animation: { _ in
                .easeInOut(duration: halfPeriod)
            }
        }
    }
}

/// A tool button's symbol in the rail's bottom pill.
struct ServerRailToolLabel: View {
    let symbol: String
    let isSelected: Bool
    let width: CGFloat

    @Environment(\.echoMotion) private var motion
    @State private var isHovering = false

    var body: some View {
        Image(systemName: symbol)
            .symbolVariant(isSelected ? .fill : .none)
            .font(.system(size: LayoutTokens.Rail.toolSymbolSize))
            .foregroundStyle(foreground)
            .frame(width: width, height: LayoutTokens.Rail.toolHeight)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .animation(motion.hover, value: isHovering)
            .animation(motion.press, value: isSelected)
    }

    private var foreground: Color {
        if isSelected { return .accentColor }
        return isHovering ? ColorTokens.Text.primary : ColorTokens.Text.secondary
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
#Preview("Server rail items") {
    HStack(spacing: SpacingTokens.lg) {
        ServerRailItem(monogram: "18", color: .blue, status: .ready, isSelected: true, size: 34)
        ServerRailItem(monogram: "TI", color: .green, status: .ready, isSelected: false, size: 34)
        ServerRailItem(monogram: "16", color: .orange, status: .connecting, isSelected: false, size: 34)
        ServerRailItem(monogram: "WH", color: .purple, status: .failed, isSelected: false, size: 34)
    }
    .padding(SpacingTokens.xl)
    .glassEffect(.regular, in: .capsule)
    .padding(SpacingTokens.xl)
    .background(ColorTokens.Workspace.canvas)
}
#endif
