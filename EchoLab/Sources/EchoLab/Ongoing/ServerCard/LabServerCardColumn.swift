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

    /// The soft zone under the header where rows blur or fade before they pass under it.
    private let edgeZone = SpacingTokens.sm

    private var animation: Animation { options.speed.spring(reduceMotion: reduceMotion) }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: LayoutTokens.Workspace.cardCornerRadius, style: .continuous) }

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
            Button("Reset loading", systemImage: "arrow.counterclockwise") { state.reset() }
                .controlSize(.small)
                .help("Forget what has loaded, to see loading again")
        }
        .sheet(item: $customizing) { server in
            LabSCCustomizeSheet(server: server, state: state, dockIcons: $dockIcons, treeIcons: $treeIcons)
        }
    }

    // MARK: - Stacked cards

    private var stacked: some View {
        ScrollView {
            LazyVStack(spacing: SpacingTokens.none, pinnedViews: [.sectionHeaders]) {
                ForEach(servers) { server in
                    Section {
                        cardBody(for: server)
                    } header: {
                        pinnedHeader(for: server)
                    }
                }
            }
        }
        .scrollIndicators(.never)
        // A card cut by the column's top edge ends rounded (round 7).
        .clipShape(shape)
    }

    private func cardBody(for server: LabSCServer) -> some View {
        let total = headerHeights[server.id] ?? 0
        return LabSCCardBody(server: server, state: state, options: options, animation: animation,
                             headerOpaqueHeight: max(total - edgeZone, 0), edgeZone: edgeZone)
            .padding(.bottom, LayoutTokens.Workspace.treeCardBottomPadding)
            .background(ColorTokens.Workspace.card, in: UnevenRoundedRectangle(
                bottomLeadingRadius: LayoutTokens.Workspace.cardCornerRadius,
                bottomTrailingRadius: LayoutTokens.Workspace.cardCornerRadius, style: .continuous))
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.frame(in: .scrollView).minY < total - SpacingTokens.micro
            } action: { isPinned in
                if isPinned { pinned.insert(server.id) } else { pinned.remove(server.id) }
            }
            .padding(.bottom, SpacingTokens.xs)
    }

    private func pinnedHeader(for server: LabSCServer) -> some View {
        let isPinned = pinned.contains(server.id)
        return VStack(spacing: SpacingTokens.none) {
            header(for: server)
                .padding(.bottom, SpacingTokens.xxs)
                .background { headerBackground(isPinned: isPinned) }
                .overlay(alignment: .bottom) {
                    if isPinned && options.edge == .hairline { Divider() }
                }
            // The soft zone: card-coloured at rest, see-through while rows pass under it.
            Rectangle()
                .fill(isPinned ? Color.clear : ColorTokens.Workspace.card)
                .frame(height: edgeZone)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeights[server.id] = $0 }
    }

    @ViewBuilder
    private func headerBackground(isPinned: Bool) -> some View {
        let top = UnevenRoundedRectangle(topLeadingRadius: LayoutTokens.Workspace.cardCornerRadius,
                                         topTrailingRadius: LayoutTokens.Workspace.cardCornerRadius, style: .continuous)
        if isPinned && options.edge == .material {
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
        } else {
            top.fill(ColorTokens.Workspace.card)
        }
    }

    // MARK: - One server, system edge

    private var oneServer: some View {
        let server = servers.first { $0.id == focusedServerID } ?? servers[0]
        return ScrollView {
            LabSCCardBody(server: server, state: state, options: options, animation: animation)
                .padding(.bottom, LayoutTokens.Workspace.treeCardBottomPadding)
        }
        .scrollIndicators(.never)
        .safeAreaBar(edge: .top) {
            header(for: server).padding(.bottom, SpacingTokens.xxs2)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background(ColorTokens.Workspace.card, in: shape)
        .clipShape(shape)
    }

    private func header(for server: LabSCServer) -> some View {
        LabSCHeaderView(server: server, state: state, options: options) { sectionID in
            state.choose(sectionID, in: server, options: options, animation: animation)
        } onCustomize: {
            customizing = server
        }
    }
}
