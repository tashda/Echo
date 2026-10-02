import SwiftUI
import AppKit

extension ServerRail {
    // MARK: - Servers

    /// One entry per server. A connection that is being re-established while its old session
    /// is still open shows as that session, so a server never appears twice.
    var entries: [ServerRailEntry] {
        // The first server waits for the welcome's pills to leave (round 48).
        guard appState.welcomeDeparture != .leaving else { return [] }
        let sessions = environmentState.sessionGroup.sessions
        let sessionConnectionIDs = Set(sessions.map(\.connection.id))
        return sessions.map(ServerRailEntry.session)
            + environmentState.pendingConnections
                .filter { !sessionConnectionIDs.contains($0.connection.id) }
                .map(ServerRailEntry.pending)
    }

    /// The selected server: one just clicked, else the one at the top of the tree, else the
    /// selected connection, else the first.
    func highlightedConnectionID(in entries: [ServerRailEntry]) -> UUID? {
        let candidate = clickedConnectionID
            ?? bridge.topVisibleConnectionID
            ?? connectionStore.selectedConnectionID
        if let candidate, entries.contains(where: { $0.connectionID == candidate }) {
            return candidate
        }
        return entries.first?.connectionID
    }

    /// One glass shape. Closed it is the pill that hugs its servers and the +; open (round 52) the
    /// same shape widens into the connection list, the servers lying in a row at its top.
    func serverPill(entries: [ServerRailEntry], highlightedID: UUID?) -> some View {
        let isOpen = appState.isConnectTrailOpen
        let closedRadius = LayoutTokens.Rail.width(itemSize: itemSize) / 2

        return GlassEffectContainer(spacing: SpacingTokens.xs) {
            VStack(spacing: SpacingTokens.none) {
                if isOpen {
                    openTrail(entries: entries, highlightedID: highlightedID)
                } else {
                    closedPill(entries: entries, highlightedID: highlightedID)
                }
            }
            .frame(width: isOpen ? Self.connectTrailWidth : nil, alignment: .topLeading)
            .glassEffect(.regular, in: .rect(cornerRadius: isOpen ? SpacingTokens.lg : closedRadius, style: .continuous))
        }
    }

    func closedPill(entries: [ServerRailEntry], highlightedID: UUID?) -> some View {
        let spacing = LayoutTokens.Rail.itemSpacing
        let padding = LayoutTokens.Rail.pillPadding
        // Servers plus the + button. Every item has the same size, so the pill's natural height
        // is exact without measuring.
        let count = CGFloat(entries.count + 1)
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
                        connectButton
                    }
                }
                .padding(padding)
            }
            .scrollIndicators(.never)
            .scrollBounceBehavior(.basedOnSize)
            // Hugs its servers, and only scrolls once they outgrow the window height.
            .frame(maxHeight: contentHeight)
            .onChange(of: highlightedID) { _, id in
                // Scrolls only as far as needed, so a visible selection never moves the rail.
                guard let id else { return }
                withAnimation(motion.standard) { proxy.scrollTo(id) }
            }
        }
    }

    func selectionDisc(isVisible: Bool) -> some View {
        let inset = LayoutTokens.Rail.selectionInset
        return Capsule()
            .fill(ColorTokens.Workspace.railSelection)
            .shadow(ShadowTokens.railSelection)
            .frame(
                width: itemSize - inset * 2,
                height: max(itemSize, selectionBottom - selectionTop) - inset * 2
            )
            .offset(y: selectionTop + inset)
            .opacity(isVisible ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// A server's item. In the opened trail (`drawsOwnDisc`) each item carries its own selection
    /// disc, as the trail's one disc moves only inside the closed pill, and a click closes the trail.
    func item(
        for entry: ServerRailEntry,
        isSelected: Bool,
        runningQueryCount: Int,
        drawsOwnDisc: Bool = false
    ) -> some View {
        let status = entry.status

        return Button {
            activate(entry)
            if drawsOwnDisc { appState.isConnectTrailOpen = false }
        } label: {
            ServerRailItem(
                monogram: ServerRailMonogram.make(from: entry.displayName),
                glyph: connectionStore.currentGlyph(of: entry.connection),
                color: connectionStore.currentColor(of: entry.connection),
                status: status,
                isSelected: isSelected,
                size: itemSize,
                // Round 30.1, CO1: with the header in the server's colour, the monogram always is.
                isAlwaysColored: projectStore.globalSettings.serverHeaderColorSource == .server
            )
            .background {
                if drawsOwnDisc && isSelected { ownSelectionDisc }
            }
        }
        .buttonStyle(.plain)
        .matchedGeometryEffect(id: entry.connectionID, in: trail)
        .focusable(false)
        // The name bubble (round 51, NM1) replaces the tooltip; VoiceOver reads the label and value.
        .onHover(perform: trackHover(of: entry, isActive: !drawsOwnDisc))
        .anchorPreference(key: ServerRailItemBoundsKey.self, value: .bounds) { [entry.connectionID: $0] }
        .popover(isPresented: customizingBinding(for: entry), arrowEdge: .trailing) { appearancePopover(for: entry) }
        .lazyContextMenu { menu(for: entry) }
        .accessibilityLabel(entry.displayName)
        .accessibilityValue(accessibilityValue(for: entry, runningQueryCount: runningQueryCount))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    func accessibilityValue(for entry: ServerRailEntry, runningQueryCount: Int) -> String {
        let status = entry.status
        guard status == .ready, runningQueryCount > 0 else { return status.accessibilityDescription }
        return runningQueryCount == 1 ? "1 query running" : "\(runningQueryCount) queries running"
    }

    func activate(_ entry: ServerRailEntry) {
        switch entry {
        case .session(let session):
            let connectionID = session.connection.id
            clickedConnectionID = connectionID
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

    func menu(for entry: ServerRailEntry) -> NSMenu {
        switch entry {
        case .session(let session):
            let menu = bridge.sessionMenu?(session) ?? NSMenu()
            addAppearanceItem(to: menu, for: entry)
            return menu
        case .pending(let pending):
            let menu = bridge.pendingMenu?(pending) ?? NSMenu()
            addAppearanceItem(to: menu, for: entry)
            return menu
        }
    }

}
