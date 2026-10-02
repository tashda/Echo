import AppKit
import SwiftUI

/// What makes a trail item recognisable (round 51): the name bubble that opens at once beside a
/// hovered item (NM1), and Customize Appearance in the item's menu, which opens a popover at the
/// item with the colour and the symbol or emoji (WH2).
extension ServerRail {
    // MARK: - Name bubble

    /// Tells the rail which item the pointer is on. The bubble is for the closed trail only: the
    /// opened trail names its servers in its own list.
    func trackHover(of entry: ServerRailEntry, isActive: Bool) -> (Bool) -> Void {
        trackHover(of: entry.connectionID, isActive: isActive)
    }

    func trackHover(of connectionID: UUID, isActive: Bool) -> (Bool) -> Void {
        { isHovering in
            guard isActive else { return }
            if isHovering {
                hoveredServerID = connectionID
            } else if hoveredServerID == connectionID {
                hoveredServerID = nil
            }
        }
    }

    /// The bubble, drawn over the rail (not inside the pill's scroll view, which would cut it
    /// off) at the right of the hovered item, over the tree, taking no clicks.
    func nameBubble(for bounds: [UUID: Anchor<CGRect>], entries: [ServerRailEntry], recentIDs: [UUID]) -> some View {
        GeometryReader { proxy in
            if let id = hoveredServerID,
               customizingServerID == nil,
               !appState.isConnectTrailOpen,
               let anchor = bounds[id],
               let caption = bubbleCaption(for: id, entries: entries, recentIDs: recentIDs) {
                let rect = proxy[anchor]
                Color.clear
                    .frame(width: rect.width, height: rect.height)
                    .overlay(alignment: .leading) {
                        ServerRailNameBubble(name: caption.name, product: caption.product, status: caption.status)
                        .offset(x: rect.width + LayoutTokens.Rail.nameBubbleGap)
                        .transition(.opacity.combined(with: .scale(scale: LayoutTokens.Rail.nameBubbleEntryScale, anchor: .leading)))
                    }
                    .offset(x: rect.minX, y: rect.minY)
            }
        }
        .animation(motion.hover, value: hoveredServerID)
        .allowsHitTesting(false)
    }

    /// What the bubble says about the item under the pointer: a connected server (name, product,
    /// what it is doing) or a recent one (not connected, and a click connects it).
    private func bubbleCaption(for id: UUID, entries: [ServerRailEntry], recentIDs: [UUID]) -> ServerRailBubbleCaption? {
        if let entry = entries.first(where: { $0.connectionID == id }) {
            return ServerRailBubbleCaption(
                name: entry.displayName,
                product: entry.productLine,
                status: entry.statusLine(runningQueryCount: tabStore.runningQueryCountsByConnection[id] ?? 0)
            )
        }
        guard recentIDs.contains(id), let connection = connectionStore.connections.first(where: { $0.id == id }) else { return nil }
        return ServerRailBubbleCaption(
            name: connection.connectionName.isEmpty ? connection.host : connection.connectionName,
            product: ServerProductLabel.label(rawVersion: connection.serverVersion, databaseType: connection.databaseType),
            status: ServerRailBubbleCaption.recentStatus(isConnecting: connectingRecentIDs.contains(id))
        )
    }

    // MARK: - Customize Appearance

    func customizingBinding(for entry: ServerRailEntry) -> Binding<Bool> {
        customizingBinding(forID: entry.connectionID)
    }

    func customizingBinding(forID connectionID: UUID) -> Binding<Bool> {
        Binding(
            get: { customizingServerID == connectionID },
            set: { isShown in
                if !isShown, customizingServerID == connectionID { customizingServerID = nil }
            }
        )
    }

    /// The popover's content, reading the connection as saved now.
    func appearancePopover(for entry: ServerRailEntry) -> some View {
        let saved = connectionStore.connections.first { $0.id == entry.connectionID } ?? entry.connection
        return ServerAppearancePopover(connection: saved)
    }

    @ViewBuilder
    func appearancePopover(forID connectionID: UUID) -> some View {
        if let saved = connectionStore.connections.first(where: { $0.id == connectionID }) {
            ServerAppearancePopover(connection: saved)
        }
    }

    /// Adds Customize Appearance to a trail item's menu.
    func addAppearanceItem(to menu: NSMenu, for entry: ServerRailEntry) {
        addAppearanceItem(to: menu, forID: entry.connectionID)
    }

    func addAppearanceItem(to menu: NSMenu, forID connectionID: UUID) {
        if let last = menu.items.last, !last.isSeparatorItem { menu.addDivider() }
        menu.addActionItem("Customize Appearance", systemImage: "paintpalette") {
            // The menu has to be gone before the popover opens, or it dismisses it.
            Task { @MainActor in
                await Task.yield()
                hoveredServerID = nil
                customizingServerID = connectionID
            }
        }
    }
}
