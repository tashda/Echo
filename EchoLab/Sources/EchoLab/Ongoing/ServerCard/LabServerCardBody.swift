import SwiftUI

/// The rows under a server's header: the section the dock shows, with its open folders.
/// Every row has a fixed slot, so the card's height is known without measuring and animates
/// in one piece when the section changes (as Echo's `ExplorerTreeLayout` does).
struct LabSCCardBody: View {
    let server: LabSCServer
    let state: LabSCState
    let options: LabSCOptions
    let animation: Animation
    /// Where rows start to pass under the pinned header, for the blur and fade.
    var headerOpaqueHeight: CGFloat = 0
    var edgeZone: CGFloat = 0

    var body: some View {
        let shownID = state.shownSection(of: server)
        let rows = flatRows(shownID)
        ZStack(alignment: .top) {
            if options.switchMotion == .today {
                content(rows)
            } else {
                content(rows)
                    .id(shownID)
                    .transition(sectionTransition)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height(of: rows), alignment: .top)
        .clipped()
    }

    // MARK: - Rows

    enum FlatRow: Identifiable {
        case node(LabSCNode, depth: Int)
        case loading(id: String, depth: Int)

        var id: String {
            switch self {
            case .node(let node, _): node.id
            case .loading(let id, _): "loading|\(id)"
            }
        }
    }

    private func flatRows(_ sectionID: String) -> [FlatRow] {
        guard let section = server.section(sectionID) else { return [] }
        let key = state.sectionKey(server, sectionID)
        if state.loading.contains(key) && options.loading != .keep {
            return [.loading(id: key, depth: 0)]
        }
        let expanded = state.expandedIDs(server, section)
        var rows: [FlatRow] = []
        func walk(_ nodes: [LabSCNode], depth: Int) {
            for node in nodes {
                rows.append(.node(node, depth: depth))
                guard node.isFolder, expanded.contains(node.id) else { continue }
                if state.loading.contains(node.id) && options.loading != .keep {
                    rows.append(.loading(id: node.id, depth: depth + 1))
                } else {
                    walk(node.children, depth: depth + 1)
                }
            }
        }
        walk(section.nodes, depth: 0)
        return rows
    }

    private func height(of rows: [FlatRow]) -> CGFloat {
        rows.reduce(SpacingTokens.none) { total, row in
            switch row {
            case .node: total + options.density.rowSlot
            case .loading: total + options.density.rowSlot * 3
            }
        }
    }

    private func content(_ rows: [FlatRow]) -> some View {
        VStack(spacing: SpacingTokens.none) {
            ForEach(rows) { row in
                rowView(row)
                    .modifier(LabSCEdgeEffect(edge: options.edge, top: headerOpaqueHeight, zone: edgeZone))
                    .transition(rowTransition)
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: FlatRow) -> some View {
        switch row {
        case .loading(_, let depth):
            LabSCLoadingRows(style: options.loading, depth: depth, options: options)
        case .node(let node, let depth):
            let section = server.section(state.shownSection(of: server))
            LabSCRow(
                node: node, depth: depth,
                isExpanded: section.map { state.expandedIDs(server, $0).contains(node.id) } ?? false,
                isSelected: state.selectedRowID == node.id,
                isLoading: state.loading.contains(node.id),
                options: options
            ) {
                if node.isFolder, let section {
                    state.toggleFolder(node, server: server, section: section, options: options, animation: animation)
                } else {
                    state.selectedRowID = node.id
                }
            }
        }
    }

    // MARK: - Motion

    /// Today, rows arriving on a switch drop in from above one by one; expanding keeps the
    /// decided slide-down with a fade.
    private var rowTransition: AnyTransition {
        options.switchMotion == .today ? .opacity.combined(with: .move(edge: .top)) : .opacity
    }

    private var sectionTransition: AnyTransition {
        switch options.switchMotion {
        case .crossfade:
            return .opacity
        case .slide:
            let forward = state.movedForward[server.id] ?? true
            return .asymmetric(
                insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
            )
        case .today, .instant:
            return .identity
        }
    }
}

/// Blur rows, Fade rows: a row blurs and fades as it slides into the soft zone under the pinned
/// header, and is fully gone by the time it reaches the header's opaque part.
struct LabSCEdgeEffect: ViewModifier {
    let edge: LabSCEdge
    let top: CGFloat
    let zone: CGFloat

    func body(content: Content) -> some View {
        if (edge == .blurRows || edge == .fadeRows) && zone > 0 {
            content.visualEffect { [edge, top, zone] effect, proxy in
                let minY = proxy.frame(in: .scrollView).minY
                let progress = min(max((top + zone - minY) / zone, 0), 1)
                return effect
                    .blur(radius: edge == .blurRows ? progress * SpacingTokens.xxs : 0)
                    .opacity(1 - progress * 0.9)
            }
        } else {
            content
        }
    }
}
