#if DEBUG
import SwiftUI

/// Round 9, section 1: the tree's scroll bar, which today runs across every server card.
enum LabTreeScroller: String, CaseIterable, Identifiable {
    case today = "Today"
    case gutter = "SB1 In the gutter"
    case none = "SB3 None"
    var id: String { rawValue }
}

struct LabScrollerStage: View {
    @State private var scroller: LabTreeScroller = .gutter
    @State private var metrics = ScrollMetrics()
    @State private var isScrolling = false

    struct ScrollMetrics: Equatable {
        var offset: CGFloat = 0
        var content: CGFloat = 1
        var container: CGFloat = 1
    }

    private let gutter: CGFloat = 6

    var body: some View {
        LabStage(title: "Tree scroll bar: scroll the tree") {
            LabPicker(title: "Scroll bar", selection: $scroller, options: LabTreeScroller.allCases)
        } content: {
            HStack(spacing: 0) {
                tree
                    .frame(width: 270)
                gutterBar
                    .frame(width: gutter)
                LabCard { LabEditorText() }
            }
            .padding(gutter)
            .frame(width: 760, height: 420)
            .background(Color(nsColor: .windowBackgroundColor))
            .padding(24)
        }
    }

    private var tree: some View {
        ScrollView {
            VStack(spacing: gutter) {
                ForEach(LabServer.samples.prefix(3)) { server in
                    serverCard(server)
                }
            }
            .padding(.bottom, gutter)
        }
        .scrollIndicators(scroller == .today ? .visible : .never)
        .onScrollGeometryChange(for: ScrollMetrics.self) { geometry in
            ScrollMetrics(offset: geometry.contentOffset.y, content: geometry.contentSize.height, container: geometry.containerSize.height)
        } action: { _, new in
            metrics = new
        }
        .onScrollPhaseChange { _, phase in
            isScrolling = phase.isScrolling
        }
    }

    /// SB1: a thin bar in the gap between the tree and the editor, outside every card, shown only
    /// while scrolling, like an overlay scroller.
    private var gutterBar: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let visible = min(metrics.container / max(metrics.content, 1), 1)
            let thumb = max(height * visible, 24)
            let travel = max(metrics.content - metrics.container, 1)
            let y = (height - thumb) * min(max(metrics.offset / travel, 0), 1)
            Capsule()
                .fill(Color.primary.opacity(0.35))
                .frame(width: 3, height: thumb)
                .offset(x: (gutter - 3) / 2, y: y)
                .opacity(scroller == .gutter && isScrolling && visible < 1 ? 1 : 0)
                .animation(.easeOut(duration: isScrolling ? 0.1 : 0.6), value: isScrolling)
        }
    }

    private func serverCard(_ server: LabServer) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(server.name)
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 12)
                .frame(height: 30)
            LabTreeRow(depth: 0, icon: "cylinder.split.1x2", title: "Databases", detail: "\(LabTree.databases[server.id]?.count ?? 0)", isExpanded: true, iconColor: .green)
            ForEach(LabTree.databases[server.id] ?? []) { database in
                LabTreeRow(depth: 1, icon: "cylinder", title: database.name, isExpanded: true, iconColor: .blue)
                LabTreeRow(depth: 2, icon: "tablecells", title: "Tables", detail: "\(database.tables.count)", isExpanded: true, iconColor: .cyan)
                ForEach(database.tables, id: \.self) { table in
                    LabTreeRow(depth: 3, icon: "tablecells", title: table, isExpanded: false)
                }
            }
        }
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}
#endif
