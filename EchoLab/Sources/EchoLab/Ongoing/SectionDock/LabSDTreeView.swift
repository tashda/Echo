import SwiftUI

/// The Explorer tree built the way Echo builds it (ObjectBrowserOutlineView): every server's rows
/// in one flat lazy list, the name and dock pinned per server, one card per server drawn behind
/// the list and cut to the visible part, rows blurring under the pinned header. The switching
/// and neighbour options change only what the round asks about.
struct LabSDTreeView: View {
    let servers: [LabSDServer]
    let options: LabSDOptions
    /// Changing these (from the round's actions) resets the tree or scrolls to Test MSSQL.
    var resetToken = ""
    var scrollToken = ""

    @State private var state = LabSDTreeState()
    @State private var scroll = LabSDScroll()
    @State private var position = ScrollPosition(edge: .top)
    @Environment(\.echoMotion) private var motion
    @Environment(\.workspaceCardCornerRadius) private var cornerRadius

    var body: some View {
        let layout = LabSDLayout(servers: servers, state: state, options: options)
        let rowIDs = layout.rows.map(\.id)
        let selections = servers.map { state.chosenSection($0) }

        ScrollView {
            LazyVStack(spacing: SpacingTokens.none, pinnedViews: [.sectionHeaders]) {
                ForEach(layout.groups) { group in
                    if group.header.isEmpty {
                        ForEach(group.rows) { rowView($0, layout: layout) }
                    } else {
                        Section {
                            groupBody(group, layout: layout)
                        } header: {
                            VStack(spacing: SpacingTokens.none) {
                                ForEach(group.header) { rowView($0, layout: layout) }
                            }
                            .background { LabSDHeaderWash(restingMinY: group.header[0].minY, scroll: scroll) }
                        }
                    }
                }
            }
            .frame(minHeight: state.heldHeight, alignment: .top)
            .modifier(LabSDTodayAnimation(isOn: options.switchMotion == .today, motion: motion, selections: selections, rowIDs: rowIDs))
        }
        .scrollPosition($position)
        .scrollIndicators(.never)
        .onScrollGeometryChange(for: CGSize.self) { geometry in
            CGSize(width: geometry.contentOffset.y + geometry.contentInsets.top, height: geometry.containerSize.height)
        } action: { _, value in
            scroll.offset = value.width
            scroll.viewport = value.height
            state.scrolled(to: value.width, viewport: value.height)
        }
        .background(alignment: .top) {
            LabSDCardsLayer(cards: layout.cards, scroll: scroll, neighbours: options.neighbours, motion: motion,
                            selections: selections, rowIDs: rowIDs)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onChange(of: state.scrollRequestID) { _, _ in
            guard let request = state.scrollRequest else { return }
            withAnimation(request.animation) { position.scrollTo(y: request.y) }
        }
        .onChange(of: resetToken) { _, _ in
            state.reset()
            position.scrollTo(edge: .top)
        }
        .onChange(of: scrollToken) { _, _ in
            withAnimation(motion.reveal) { position.scrollTo(y: layout.serverTop("ms")) }
        }
    }

    // MARK: - Body

    @ViewBuilder
    private func groupBody(_ group: LabSDLayout.Group, layout: LabSDLayout) -> some View {
        switch options.switchMotion {
        case .cardCrossfade, .slide:
            // The card's rows as one piece, so the whole set changes at once.
            ZStack(alignment: .top) {
                VStack(spacing: SpacingTokens.none) {
                    ForEach(group.rows) { rowView($0, layout: layout, headerHeight: group.headerHeight) }
                }
                .id(group.sectionID)
                .transition(blockTransition(group.serverID))
            }
            .frame(height: group.bodyHeight, alignment: .top)
            .clipped()
        default:
            ForEach(group.rows) { row in
                rowView(row, layout: layout, headerHeight: group.headerHeight)
                    .opacity(options.switchMotion == .fadeThrough ? (state.bodyOpacity[row.serverID ?? ""] ?? 1) : 1)
                    .transition(options.switchMotion == .today ? .opacity : .identity)
            }
        }
    }

    private func blockTransition(_ serverID: String?) -> AnyTransition {
        guard options.switchMotion == .slide else { return .opacity }
        let forward = state.movedForward[serverID ?? ""] ?? true
        return .asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                           removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity))
    }

    // MARK: - Rows

    @ViewBuilder
    private func rowView(_ row: LabSDLayout.Row, layout: LabSDLayout, headerHeight: CGFloat = 0) -> some View {
        Group {
            switch row.kind {
            case .gap:
                Color.clear
            case .server(let server):
                LabSDServerRow(server: server, sectionTitle: sectionTitle(server), isCollapsed: state.collapsed.contains(server.id),
                               density: options.density) {
                    state.toggleServer(server, motion: motion, scroll: scroll, neighbours: options.neighbours)
                }
            case .dock(let server):
                LabSDCapsule(server: server, chosen: state.chosenSection(server), options: options) { sectionID in
                    state.choose(sectionID, in: server, options: options, motion: motion, scroll: scroll, serverTop: layout.serverTop(server.id))
                }
            case .heading(let title):
                LabSDHeadingRow(title: title)
            case .node(let node, let isLoading):
                LabSDNodeRow(node: node, depth: row.depth, isExpanded: state.expanded.contains(node.id),
                             isSelected: state.selectedRowID == node.id, isLoading: isLoading, density: options.density) {
                    if node.isFolder { state.toggleFolder(node, motion: motion) } else { state.selectedRowID = node.id }
                }
            case .spinner(let title):
                LabSDSpinnerRow(title: title, depth: row.depth, density: options.density)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: row.height)
        .modifier(LabSDRowEdgeBlur(headerHeight: headerHeight))
    }

    private func sectionTitle(_ server: LabSDServer) -> String? {
        guard options.sectionName == .underName, server.sections.count >= 2 else { return nil }
        let chosen = state.chosenSection(server)
        return chosen == LabSDTreeState.moreID ? "More" : server.section(chosen)?.title
    }
}

/// Echo today (S0): the list animates on its own whenever rows change, with `settle` for a dock
/// switch and `expand` otherwise (ObjectBrowserOutlineView).
struct LabSDTodayAnimation: ViewModifier {
    let isOn: Bool
    let motion: EchoMotion
    let selections: [String]
    let rowIDs: [String]

    func body(content: Content) -> some View {
        if isOn {
            content.animation(motion.settle, value: selections).animation(motion.expand, value: rowIDs)
        } else {
            content
        }
    }
}
