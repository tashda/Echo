import SwiftUI

/// The Explorer column: server cards stacked in one scroll view with their headers pinned (as
/// in Echo), or, for the system edge, one server's card filling the column.
struct LabSCTreeColumn: View {
    let servers: [LabSCServer]
    let options: LabSCOptions
    @Binding var dockIcons: LabSCIconStyle
    @Binding var treeIcons: LabSCIconStyle

    @State private var state = LabSCState()
    @State private var headerHeights: [String: CGFloat] = [:]
    @State private var pinned: Set<String> = []
    @State private var focusedServerID = LabSCServer.mssql.id
    @State private var customizing: LabSCServer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.workspaceCardCornerRadius) private var cornerRadius

    private var motion: EchoMotion { options.speed.motion(reduceMotion: reduceMotion) }
    /// Switching sections and rows arriving after a load: no overshoot, so the card's bottom
    /// edge glides to its new height instead of bouncing past it (owner, round 16).
    private var animation: Animation { motion.settle }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }
    /// Pinned › Icons only: the name scrolls away and only the dock stays.
    private var pinsIconsOnly: Bool { options.pinning == .iconsOnly && LabSCHeaderView.canSplit(options.header) }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            if options.showsOneServer {
                Picker("Server", selection: $focusedServerID) {
                    ForEach(servers) { Text($0.name).tag($0.id) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .help("Stands in for the rail: with the system edge, the column shows one server at a time.")
                oneServer
            } else {
                stacked
            }
            Button("Reset and connect again", systemImage: "arrow.counterclockwise") {
                state.reset(servers, options: options, animation: animation)
            }
            .controlSize(.small)
            .help("Forget what has loaded and connect again, to see the initial load")
        }
        .onAppear { state.connect(servers, options: options, animation: animation) }
        .sheet(item: $customizing) { server in
            LabSCCustomizeSheet(server: server, state: state, dockIcons: $dockIcons, treeIcons: $treeIcons)
        }
    }

    // MARK: - Stacked cards

    private var stacked: some View {
        ScrollView {
            LazyVStack(spacing: SpacingTokens.none, pinnedViews: [.sectionHeaders]) {
                ForEach(servers) { server in
                    if pinsIconsOnly {
                        header(for: server, part: .name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ColorTokens.Workspace.card, in: topShape)
                        Section { cardBody(for: server) } header: { pinnedHeader(for: server, part: .dock) }
                    } else {
                        Section { cardBody(for: server) } header: { pinnedHeader(for: server, part: .all) }
                    }
                }
            }
        }
        .scrollIndicators(.never)
        // A card cut by the column's top edge ends rounded (round 7).
        .clipShape(shape)
    }

    private var topShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: cornerRadius, topTrailingRadius: cornerRadius, style: .continuous)
    }

    private func cardBody(for server: LabSCServer) -> some View {
        let headerHeight = headerHeights[server.id] ?? 0
        return LabSCCardBody(server: server, state: state, options: options, animation: motion.expand, headerHeight: headerHeight)
            .padding(.bottom, LayoutTokens.Workspace.treeCardBottomPadding)
            .background(ColorTokens.Workspace.card, in: UnevenRoundedRectangle(
                bottomLeadingRadius: cornerRadius, bottomTrailingRadius: cornerRadius, style: .continuous))
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.frame(in: .scrollView).minY < headerHeight - SpacingTokens.micro
            } action: { isPinned in
                if isPinned { pinned.insert(server.id) } else { pinned.remove(server.id) }
            }
            .padding(.bottom, SpacingTokens.xs)
    }

    private func pinnedHeader(for server: LabSCServer, part: LabSCHeaderView.Part) -> some View {
        let isPinned = pinned.contains(server.id)
        return header(for: server, part: part)
            .padding(.bottom, SpacingTokens.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { headerBackground(isPinned: isPinned, roundedTop: part == .all) }
            .overlay(alignment: .bottom) {
                if isPinned && options.edge == .hairline { Divider() }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeights[server.id] = $0 }
    }

    @ViewBuilder
    private func headerBackground(isPinned: Bool, roundedTop: Bool) -> some View {
        switch (isPinned, options.edge) {
        case (true, .material):
            // Echo today: a thin material over the rows, fading out over its last 12pt.
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask {
                    VStack(spacing: SpacingTokens.none) {
                        Color.black
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: SpacingTokens.sm)
                    }
                }
                .padding(.bottom, -SpacingTokens.sm)
        case (true, .blurRows), (true, .fadeRows):
            // The soft edge's light wash: the rows blur and fade themselves (LabSCEdgeEffect).
            LinearGradient(stops: [
                .init(color: ColorTokens.Workspace.card.opacity(0.85), location: 0),
                .init(color: ColorTokens.Workspace.card.opacity(0.45), location: 0.55),
                .init(color: ColorTokens.Workspace.card.opacity(0), location: 1),
            ], startPoint: .top, endPoint: .bottom)
        case (true, _):
            Rectangle().fill(ColorTokens.Workspace.card)
        case (false, _):
            if roundedTop { topShape.fill(ColorTokens.Workspace.card) } else { Rectangle().fill(ColorTokens.Workspace.card) }
        }
    }

    // MARK: - One server, system edge

    private var oneServer: some View {
        let server = servers.first { $0.id == focusedServerID } ?? servers[0]
        return ScrollView {
            LabSCCardBody(server: server, state: state, options: options, animation: motion.expand)
                .padding(.bottom, LayoutTokens.Workspace.treeCardBottomPadding)
        }
        .scrollIndicators(.never)
        .safeAreaBar(edge: .top) {
            header(for: server, part: .all).padding(.bottom, SpacingTokens.xs)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background(ColorTokens.Workspace.card, in: shape)
        .clipShape(shape)
    }

    private func header(for server: LabSCServer, part: LabSCHeaderView.Part) -> some View {
        LabSCHeaderView(server: server, state: state, options: options, part: part) { sectionID in
            state.choose(sectionID, in: server, options: options, animation: animation)
        } onCustomize: {
            customizing = server
        }
    }
}
