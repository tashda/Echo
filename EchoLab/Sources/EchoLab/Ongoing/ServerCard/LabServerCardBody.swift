import SwiftUI

/// The rows under a server's header: the section the dock shows, with its open folders.
/// Every row has a fixed slot, so the card's height is known without measuring and animates
/// in one piece when the section changes (as Echo's `ExplorerTreeLayout` does).
struct LabSCCardBody: View {
    let server: LabSCServer
    let state: LabSCState
    let options: LabSCOptions
    /// Folders opening and closing: Echo's `expand` (rows slide and fade, no bounce).
    let animation: Animation
    /// The pinned header's height: rows blur and fade as they pass under it.
    var headerHeight: CGFloat = 0

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
        case node(LabSCNode, depth: Int, isLoading: Bool)
        /// Skeleton or shimmer placeholders, three rows tall.
        case placeholder(id: String, depth: Int, style: LabSCLoading)
        /// I2 and Folders first: one row with a spinner in the icon slot.
        case spinnerRow(id: String, depth: Int, title: String)
        /// I3: a spinner centred in a three-row space.
        case centred(id: String, title: String)

        var id: String {
            switch self {
            case .node(let node, _, _): node.id
            case .placeholder(let id, _, _): "placeholder|\(id)"
            case .spinnerRow(let id, _, _): "spinner|\(id)"
            case .centred(let id, _): "centred|\(id)"
            }
        }

        var slots: CGFloat {
            switch self {
            case .node, .spinnerRow: 1
            case .placeholder, .centred: 3
            }
        }
    }

    private func flatRows(_ sectionID: String) -> [FlatRow] {
        guard let section = server.section(sectionID) else { return [] }
        let key = state.sectionKey(server, sectionID)
        let sectionLoading = state.loading.contains(key)
        if sectionLoading {
            switch options.initialLoad {
            case .today: return [.placeholder(id: key, depth: 0, style: .shimmer)]
            case .skeleton: return [.placeholder(id: key, depth: 0, style: .skeleton)]
            case .iconOnly, .headerSpinner: return []
            case .spinnerRow: return [.spinnerRow(id: key, depth: 0, title: "Loading \(section.title)")]
            case .centred: return [.centred(id: key, title: section.title)]
            case .foldersFirst: break
            }
        }
        let expanded = state.expandedIDs(server, section)
        var rows: [FlatRow] = []
        // While a section loads (Folders first), only what the blueprint knows is drawn: folders
        // and tools. The items a level lists wait behind one spinner row.
        func walk(_ nodes: [LabSCNode], depth: Int, title: String) {
            var waitsForItems = false
            for node in nodes {
                if sectionLoading && node.isItem {
                    waitsForItems = true
                    continue
                }
                let folderLoading = state.loading.contains(node.id) || (sectionLoading && node.isFolder)
                rows.append(.node(node, depth: depth, isLoading: folderLoading))
                guard node.isFolder, expanded.contains(node.id) else { continue }
                if sectionLoading {
                    rows.append(.spinnerRow(id: node.id, depth: depth + 1, title: "Loading \(node.title)"))
                } else if state.loading.contains(node.id) && options.loading != .keep {
                    rows.append(.placeholder(id: node.id, depth: depth + 1, style: options.loading))
                } else {
                    walk(node.children, depth: depth + 1, title: node.title)
                }
            }
            if waitsForItems {
                rows.append(.spinnerRow(id: "\(key)|\(title)", depth: depth, title: "Loading \(title)"))
            }
        }
        walk(section.nodes, depth: 0, title: section.title)
        return rows
    }

    private func height(of rows: [FlatRow]) -> CGFloat {
        rows.reduce(SpacingTokens.none) { $0 + options.density.rowSlot * $1.slots }
    }

    private func content(_ rows: [FlatRow]) -> some View {
        VStack(spacing: SpacingTokens.none) {
            ForEach(rows) { row in
                rowView(row)
                    .modifier(LabSCEdgeEffect(edge: options.edge, headerHeight: headerHeight))
                    .transition(rowTransition)
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: FlatRow) -> some View {
        switch row {
        case .placeholder(_, let depth, let style):
            LabSCLoadingRows(style: style, depth: depth, options: options)
        case .spinnerRow(_, let depth, let title):
            LabSCSpinnerRow(title: title, depth: depth, options: options)
        case .centred(_, let title):
            LabSCCentredSpinner(title: title, height: options.density.rowSlot * 3)
        case .node(let node, let depth, let isLoading):
            let section = server.section(state.shownSection(of: server))
            LabSCRow(
                node: node, depth: depth,
                isExpanded: section.map { state.expandedIDs(server, $0).contains(node.id) } ?? false,
                isSelected: state.selectedRowID == node.id,
                isLoading: isLoading,
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

/// Blur rows, Fade rows, modelled on macOS 26's soft scroll edge: a row stays visible under the
/// pinned header, and blurs and fades more the higher it goes, so it is a soft haze behind the
/// name and a readable blur behind the icons. The header adds a light wash of the card colour.
struct LabSCEdgeEffect: ViewModifier {
    let edge: LabSCEdge
    let headerHeight: CGFloat

    /// The strongest blur, at the card's top edge.
    static let maxBlur = SpacingTokens.xs2

    func body(content: Content) -> some View {
        if (edge == .blurRows || edge == .fadeRows) && headerHeight > 0 {
            content.visualEffect { [edge, headerHeight, maxBlur = Self.maxBlur] effect, proxy in
                let midY = proxy.frame(in: .scrollView).midY
                let progress = min(max((headerHeight - midY) / headerHeight, 0), 1)
                return effect
                    .blur(radius: edge == .blurRows ? progress * maxBlur : 0)
                    .opacity(1 - pow(progress, 0.8) * 0.92)
            }
        } else {
            content
        }
    }
}
