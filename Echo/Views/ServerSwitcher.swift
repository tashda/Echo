import SwiftUI

// MARK: - Server Switcher (Cmd+Tab style)

struct ServerSwitcherView: View {
    @ObservedObject var sessionManager: ConnectionSessionManager
    @Environment(\.dismiss) private var dismiss

    private var switcherItems: [ServerSwitcherItem] {
        sessionManager.sortedSessions.map { session in
            ServerSwitcherItem(
                id: session.id,
                session: session,
                isActive: session.id == sessionManager.activeSessionID
            )
        }
    }

    var body: some View {
        ZStack {
            // Background blur
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissSwitcher()
                }

            VStack(spacing: 0) {
                // Title
                Text("Switch Server")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // Server list
                VStack(spacing: 4) {
                    ForEach(switcherItems) { item in
                        ServerSwitcherRow(
                            item: item,
                            onSelect: {
                                sessionManager.setActiveSession(item.id)
                                dismissSwitcher()
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)

                // Instructions
                HStack(spacing: 16) {
                    Text("⌘⇥ Next")
                    Text("⌘⇧⇥ Previous")
                    Text("↩ Select")
                    Text("⎋ Cancel")
                }
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 12)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(maxWidth: 400)
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
    }

    private func dismissSwitcher() {
        sessionManager.hideServerSwitcher()
    }
}

// MARK: - Server Switcher Row

private struct ServerSwitcherRow: View {
    let item: ServerSwitcherItem
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Connection icon with status
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.thinMaterial)
                        .frame(width: 32, height: 32)

                    Image(item.session.connection.databaseType.iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(item.connectionColor)

                    // Active indicator
                    if item.isActive {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(.background, lineWidth: 1.5)
                            )
                            .offset(x: 10, y: -10)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if item.queryTabCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 9))
                                Text("\(item.queryTabCount)")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(.secondary)
                        }

                        Text(timeAgoString(from: item.lastActivity))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Quick actions
                if isHovering || item.isActive {
                    HStack(spacing: 6) {
                        Button {
                            // Add new query tab
                            item.session.addQueryTab()
                            onSelect()
                        } label: {
                            Image(systemName: "plus.square")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .help("New Query Tab")

                        if item.queryTabCount > 0 {
                            Button {
                                // TODO: Show query tabs overview
                            } label: {
                                Image(systemName: "square.stack")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                            .help("Show Query Tabs")
                        }
                    }
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(item.isActive ? Color.accentColor.opacity(0.2) : (isHovering ? Color.accentColor.opacity(0.1) : .clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Server Switcher Overlay

struct ServerSwitcherOverlay: ViewModifier {
    @ObservedObject var sessionManager: ConnectionSessionManager

    func body(content: Content) -> some View {
        content
            .overlay {
                if sessionManager.isServerSwitcherVisible {
                    ServerSwitcherView(sessionManager: sessionManager)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .zIndex(1000)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: sessionManager.isServerSwitcherVisible)
    }
}

extension View {
    func serverSwitcherOverlay(sessionManager: ConnectionSessionManager) -> some View {
        modifier(ServerSwitcherOverlay(sessionManager: sessionManager))
    }
}