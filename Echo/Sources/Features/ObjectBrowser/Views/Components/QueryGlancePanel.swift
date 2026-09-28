import SwiftUI

/// Glass panel listing every open query tab, grouped by server in rail order. Running queries
/// come first with a live timer and a stop button; clicking a row switches to that tab.
///
/// The panel stays in the view hierarchy and is shown by fading and scaling it, so opening it
/// never builds views or loads data. Timers are only read while it is open.
struct QueryGlancePanel: View {
    let sessions: [ConnectionSession]
    let isOpen: Bool
    let onClose: () -> Void

    @Environment(TabStore.self) private var tabStore

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    if sessions.isEmpty {
                        emptyState
                    } else {
                        ForEach(sessions) { session in
                            group(for: session)
                        }
                    }
                }
                .padding(.horizontal, SpacingTokens.xxs)
                .padding(.bottom, SpacingTokens.xs)
            }
            .scrollIndicators(.automatic)
        }
        .frame(maxWidth: LayoutTokens.QueryGlance.width)
        .frame(maxHeight: LayoutTokens.QueryGlance.maxHeight, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
        .glassEffect(.regular, in: .rect(cornerRadius: LayoutTokens.QueryGlance.cornerRadius))
        .opacity(isOpen ? 1 : 0)
        .scaleEffect(isOpen ? 1 : 0.96, anchor: .topLeading)
        .offset(x: isOpen ? 0 : -SpacingTokens.xs)
        .allowsHitTesting(isOpen)
        .accessibilityHidden(!isOpen)
        .animation(.snappy(duration: 0.28, extraBounce: 0.06), value: isOpen)
        .background {
            // Esc closes the panel while it is open.
            if isOpen {
                Button("Close", action: onClose)
                    .keyboardShortcut(.cancelAction)
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            Text("Open Queries")
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.secondary)
            Spacer()
            if !runningTabs.isEmpty {
                Button("Stop All") {
                    for tab in runningTabs { tab.query?.cancelExecution() }
                }
                .buttonStyle(.plain)
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.top, SpacingTokens.sm)
        .padding(.bottom, SpacingTokens.xxs)
    }

    private var emptyState: some View {
        Text("Connect to a server to see its queries here.")
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.tertiary)
            .padding(SpacingTokens.sm)
    }

    private func group(for session: ConnectionSession) -> some View {
        let tabs = queryTabs(for: session.connection.id)
        let isCurrent = session.connection.id == tabStore.activeTab?.connection.id

        return VStack(alignment: .leading, spacing: SpacingTokens.none) {
            HStack(spacing: SpacingTokens.xs) {
                Text(ServerRailMonogram.make(from: displayName(for: session.connection)))
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(ColorTokens.Text.primary)
                    .frame(width: 22, height: 22)
                    .background(ColorTokens.Sidebar.hoverFill, in: Circle())

                Text(displayName(for: session.connection))
                    .font(TypographyTokens.standard.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(1)

                Spacer(minLength: SpacingTokens.xs)

                stateLabel(for: session, runningCount: tabs.filter { $0.query?.isExecuting == true }.count)
            }
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, SpacingTokens.xxs)

            if tabs.isEmpty {
                Text("No open queries")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .padding(.leading, SpacingTokens.xl + SpacingTokens.xxs)
                    .padding(.bottom, SpacingTokens.xxs)
            } else {
                ForEach(tabs) { tab in
                    QueryGlanceRow(tab: tab, isPanelOpen: isOpen) {
                        tabStore.activeTabId = tab.id
                        onClose()
                    }
                }
            }
        }
        .padding(SpacingTokens.xxs)
        .background(
            isCurrent ? ColorTokens.Sidebar.hoverFill : Color.clear,
            in: RoundedRectangle(cornerRadius: LayoutTokens.QueryGlance.groupCornerRadius, style: .continuous)
        )
    }

    @ViewBuilder
    private func stateLabel(for session: ConnectionSession, runningCount: Int) -> some View {
        switch ServerRailStatus(session.connectionState) {
        case .failed:
            Label("Connection lost", systemImage: "exclamationmark.triangle.fill")
                .labelStyle(.titleAndIcon)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Status.error)
        case .connecting:
            Text("Connecting…")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        case .ready:
            Text(runningCount > 0 ? "\(runningCount) running" : "Connected")
                .font(TypographyTokens.detail)
                .foregroundStyle(runningCount > 0 ? Color.accentColor : ColorTokens.Text.secondary)
        }
    }

    // MARK: - Data

    private var runningTabs: [WorkspaceTab] {
        tabStore.tabs.filter { $0.query?.isExecuting == true }
    }

    /// Query tabs for a server, running ones first, otherwise in tab-strip order.
    private func queryTabs(for connectionID: UUID) -> [WorkspaceTab] {
        let tabs = tabStore.tabs.filter { $0.connection.id == connectionID && $0.query != nil }
        return tabs.filter { $0.query?.isExecuting == true } + tabs.filter { $0.query?.isExecuting != true }
    }

    private func displayName(for connection: SavedConnection) -> String {
        let name = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? connection.host : name
    }
}

private struct QueryGlanceRow: View {
    let tab: WorkspaceTab
    let isPanelOpen: Bool
    let onSelect: () -> Void

    @State private var isHovering = false

    private var isRunning: Bool { tab.query?.isExecuting == true }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: SpacingTokens.xs) {
                if isRunning {
                    ProgressView()
                        .controlSize(.mini)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(width: 14, height: 14)
                }

                Text(tab.title)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: SpacingTokens.xs)

                trailing
            }
            .padding(.leading, SpacingTokens.xl - SpacingTokens.xxs)
            .padding(.trailing, SpacingTokens.xs)
            .frame(height: LayoutTokens.QueryGlance.rowHeight)
            .background(
                isHovering ? ColorTokens.Sidebar.hoverFill : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel(tab.title)
        .accessibilityValue(isRunning ? "Running" : "Idle")
    }

    @ViewBuilder
    private var trailing: some View {
        if isRunning, let query = tab.query {
            // Reading the elapsed time only while the panel is open keeps a hidden panel from
            // redrawing every second.
            if isPanelOpen {
                Text(Duration.seconds(query.currentExecutionTime), format: .time(pattern: .minuteSecond))
                    .font(TypographyTokens.detail.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
                    .contentTransition(.numericText())
            }

            Button {
                query.cancelExecution()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(ColorTokens.Status.error)
                    .frame(width: 18, height: 18)
                    .background(ColorTokens.Status.error.opacity(0.14), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Stop Query")
            .accessibilityLabel("Stop Query")
        } else {
            Text("Idle")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
    }
}
