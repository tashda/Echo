import SwiftUI

// MARK: - Server Overview Interface

struct ServerOverviewView: View {
    @ObservedObject var sessionManager: ConnectionSessionManager
    let onSwitchToSession: (UUID) -> Void
    let onNewQueryTab: (UUID) -> Void
    let onDisconnectSession: (UUID) -> Void

    @State private var hoveredSessionID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Connected Servers")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(sessionManager.activeSessions.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.3), in: Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            if sessionManager.activeSessions.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)

                    Text("No Active Connections")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("Connect to a server from the sidebar to get started")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // Server list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sessionManager.sortedSessions) { session in
                            ServerOverviewCard(
                                session: session,
                                isActive: session.id == sessionManager.activeSessionID,
                                isHovered: hoveredSessionID == session.id,
                                onSelect: { onSwitchToSession(session.id) },
                                onNewQueryTab: { onNewQueryTab(session.id) },
                                onDisconnect: { onDisconnectSession(session.id) }
                            )
                            .platformHover { hovering in
                                hoveredSessionID = hovering ? session.id : nil
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(PlatformCompatibility.regularMaterial, in: RoundedRectangle(cornerRadius: PlatformCompatibility.largeCornerRadius, style: .continuous))
    }
}

// MARK: - Server Overview Card

private struct ServerOverviewCard: View {
    let session: ConnectionSession
    let isActive: Bool
    let isHovered: Bool
    let onSelect: () -> Void
    let onNewQueryTab: () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Main server info
            HStack(spacing: 12) {
                // Server icon with status indicator
                ZStack {
                    RoundedRectangle(cornerRadius: PlatformCompatibility.defaultCornerRadius, style: .continuous)
                        .fill(PlatformCompatibility.thinMaterial)
                        .frame(width: 48, height: 48)

                    Image(session.connection.databaseType.iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(session.connection.color)
                        .symbolRenderingMode(.hierarchical)

                    // Active indicator
                    Circle()
                        .fill(isActive ? .green : .blue)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(.background, lineWidth: 2)
                        )
                        .offset(x: 18, y: -18)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.connection.connectionName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        Text(session.connection.host)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        if let database = session.selectedDatabaseName {
                            Text("•")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)

                            Text(database)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.blue)
                        }
                    }

                    // Status info
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)

                            Text("Connected")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.green)
                        }

                        if session.queryTabs.count > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 9))
                                Text("\(session.queryTabs.count)")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(.secondary)
                        }

                        Text(timeAgoString(from: session.lastActivity))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Quick actions
                if isHovered || isActive {
                    HStack(spacing: 8) {
                        Button {
                            onNewQueryTab()
                        } label: {
                            Image(systemName: "plus.square")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                        .background(Color.secondary.opacity(0.3), in: Circle())
                        .help("New Query Tab")

                        Button {
                            onDisconnect()
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                        .background(Color.secondary.opacity(0.3), in: Circle())
                        .help("Disconnect")
                    }
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? Color.accentColor.opacity(0.1) : (isHovered ? Color.secondary.opacity(0.05) : .clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isActive ? Color.accentColor.opacity(0.3) : .clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }

            // Query tabs (if any)
            if !session.queryTabs.isEmpty && (isHovered || isActive) {
                VStack(spacing: 6) {
                    Divider()
                        .padding(.horizontal, 16)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 6) {
                        ForEach(session.queryTabs.prefix(4)) { tab in
                            QueryTabPreview(
                                tab: tab,
                                isActive: tab.id == session.activeQueryTabID,
                                onSelect: {
                                    // Switch to this session and tab
                                    onSelect()
                                    session.activeQueryTabID = tab.id
                                }
                            )
                        }

                        if session.queryTabs.count > 4 {
                            HStack(spacing: 4) {
                                Text("+\(session.queryTabs.count - 4)")
                                    .font(.system(size: 11, weight: .medium))
                                Text("more")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .transition(.opacity.combined(with: .offset(y: -8)))
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

// MARK: - Query Tab Preview

private struct QueryTabPreview: View {
    let tab: QueryTab
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10))
                    .foregroundStyle(isActive ? .white : .secondary)

                Text(tab.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isActive ? .white : .primary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Server Overview (for smaller spaces)

struct CompactServerOverview: View {
    @ObservedObject var sessionManager: ConnectionSessionManager
    let onShowFullOverview: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Connected servers count
            HStack(spacing: 6) {
                Image(systemName: "server.rack")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("\(sessionManager.activeSessions.count) Connected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Quick server icons
            HStack(spacing: 4) {
                ForEach(sessionManager.activeSessions.prefix(3)) { session in
                    Button {
                        sessionManager.setActiveSession(session.id)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.thinMaterial)
                                .frame(width: 24, height: 24)

                            Image(session.connection.databaseType.iconName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(session.connection.color)

                            if session.id == sessionManager.activeSessionID {
                                Circle()
                                    .stroke(Color.accentColor, lineWidth: 2)
                                    .frame(width: 24, height: 24)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help(session.displayName)
                }

                if sessionManager.activeSessions.count > 3 {
                    Button(action: onShowFullOverview) {
                        Text("+\(sessionManager.activeSessions.count - 3)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .background(Color.secondary.opacity(0.3), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}