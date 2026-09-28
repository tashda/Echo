import AppKit
import SwiftUI

/// Vertical rail along the sidebar's leading edge.
///
/// Top: one monogram per connected server, with a single Liquid Glass lens on the server
/// the Explorer is scrolled into. Bottom: the sidebar's secondary tools. Replaces both the
/// connection dock and the navigator tab bar.
///
/// While the sidebar is open the rail draws no background of its own, so it reads as part of
/// the sidebar; the lens is its only glass.
struct ServerRail: View {
    let sessions: [ConnectionSession]
    let pendingConnections: [PendingConnection]
    let selectedConnectionID: UUID?
    @Binding var selectedSection: SidebarMenu.NavSection
    let bridge: ServerRailBridge
    let onSelectSession: (ConnectionSession) -> Void
    let onRetryPending: (PendingConnection) -> Void

    @Namespace private var lensNamespace
    /// Keeps the lens on a server the user just clicked while the Explorer scrolls to it.
    @State private var clickedConnectionID: UUID?

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            ScrollView(.vertical) {
                VStack(spacing: LayoutTokens.ServerRail.itemSpacing) {
                    GlassEffectContainer(spacing: LayoutTokens.ServerRail.itemSpacing) {
                        VStack(spacing: LayoutTokens.ServerRail.itemSpacing) {
                            ForEach(entries) { entry in
                                item(for: entry)
                            }
                        }
                    }

                    connectButton
                }
                .padding(.vertical, SpacingTokens.xxs)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.never)

            Divider()
                .frame(width: LayoutTokens.ServerRail.utilitySize)

            utilities
                .padding(.bottom, SpacingTokens.xs)
        }
        .frame(width: LayoutTokens.ServerRail.width)
        .frame(maxHeight: .infinity)
        .animation(.bouncy(duration: 0.45, extraBounce: 0.08), value: highlightedConnectionID)
        .animation(.snappy(duration: 0.3), value: entries.map(\.id))
    }

    // MARK: - Servers

    private var entries: [ServerRailEntry] {
        sessions.map(ServerRailEntry.session) + pendingConnections.map(ServerRailEntry.pending)
    }

    private var highlightedConnectionID: UUID? {
        clickedConnectionID
            ?? bridge.topVisibleConnectionID
            ?? selectedConnectionID
            ?? entries.first?.connectionID
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
        .background {
            if isActive {
                Color.clear
                    .glassEffect(.regular.interactive(), in: .circle)
                    .glassEffectID("server-rail-lens", in: lensNamespace)
            }
        }
        .lazyContextMenu { menu(for: entry) }
        .accessibilityLabel(entry.displayName)
        .accessibilityValue(status.accessibilityDescription)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func activate(_ entry: ServerRailEntry) {
        switch entry {
        case .session(let session):
            clickedConnectionID = session.connection.id
            selectedSection = .folder
            onSelectSession(session)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(700))
                if clickedConnectionID == session.connection.id {
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

    private var connectButton: some View {
        Button {
            selectedSection = selectedSection == .connections ? .folder : .connections
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(
                    width: LayoutTokens.ServerRail.utilitySize,
                    height: LayoutTokens.ServerRail.utilitySize
                )
                .overlay(Circle().strokeBorder(ColorTokens.Text.quaternary, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("Connect to a Server")
        .accessibilityLabel("Connect to a Server")
    }

    // MARK: - Tools

    private var utilities: some View {
        VStack(spacing: SpacingTokens.xxs) {
            ForEach(SidebarMenu.NavSection.railTools, id: \.self) { section in
                utilityButton(section)
            }
        }
    }

    private func utilityButton(_ section: SidebarMenu.NavSection) -> some View {
        let isSelected = selectedSection == section

        return Button {
            selectedSection = isSelected ? .folder : section
        } label: {
            Image(systemName: section.icon)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(isSelected ? Color.accentColor : ColorTokens.Text.secondary)
                .frame(
                    width: LayoutTokens.ServerRail.utilitySize,
                    height: LayoutTokens.ServerRail.utilitySize
                )
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
    /// Connections is opened from the rail's + button.
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
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(isActive ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
            .opacity(monogramOpacity)
            .frame(width: LayoutTokens.ServerRail.itemSize, height: LayoutTokens.ServerRail.itemSize)
            .contentShape(Circle())
            .overlay(alignment: .topTrailing) {
                if status == .failed {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, ColorTokens.Status.error)
                        .offset(x: SpacingTokens.xxxs, y: -SpacingTokens.xxxs)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.25), value: status)
    }

    private var monogramOpacity: Double {
        switch status {
        case .ready: return 1
        case .connecting: return 0.5
        case .failed: return 0.4
        }
    }
}
