import SwiftUI

/// Single-line alternatives to the glass bar from rounds 9, 11 and 12.
enum LabNewTabDesign: String, CaseIterable, Identifiable {
    case tonal = "N1 · Tonal control"
    case attached = "N2 · Attached tabs"
    case quiet = "N3 · Quiet row"

    var id: String { rawValue }

    var summary: String {
        switch self {
        case .tonal:
            "One low-contrast opaque track; the active tab is a stronger neutral shade. It keeps the familiar grouped shape without glass or a white selected pill."
        case .attached:
            "The selected tab becomes the editor card's header. Other tabs sit on the canvas as small neutral tabs. The white surface has a structural reason."
        case .quiet:
            "No plate. One-line labels rest on the canvas; a small neutral selection and a short accent rule identify the active tab. The editor card stays visually separate."
        }
    }
}

/// Keeps selection stable when a preview tab is closed, including the final tab in a row.
enum LabRound13TabSelection {
    static func activeID(
        afterClosing closedID: UUID,
        previousActiveID: UUID?,
        closedIndex: Int,
        remainingIDs: [UUID]
    ) -> UUID? {
        guard previousActiveID == closedID else { return previousActiveID }
        guard !remainingIDs.isEmpty else { return nil }
        return remainingIDs[min(closedIndex, remainingIDs.count - 1)]
    }
}

struct LabRound13Playground: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            ForEach(LabNewTabDesign.allCases) { design in
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text(design.rawValue)
                        .font(TypographyTokens.headline)
                    Text(design.summary)
                        .font(TypographyTokens.callout)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(width: LayoutTokens.TabProposals.previewWidth, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    LabRound13Window(design: design)
                }
                .padding(SpacingTokens.sm)
                .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: LayoutTokens.Workspace.cardCornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: LayoutTokens.Workspace.cardCornerRadius)
                        .strokeBorder(ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity), lineWidth: LayoutTokens.Workspace.cardEdgeWidth)
                }
            }
        }
    }
}

private struct LabRound13Window: View {
    let design: LabNewTabDesign

    @State private var tabs: [LabTabItem] = [
        LabTabItem(title: "Jobs", database: "Microsoft SQL Server", symbol: "gearshape", serverColor: .orange),
        LabTabItem(title: "Query 2", database: "employees", symbol: "tablecells", serverColor: .blue, isRunning: true),
        LabTabItem(title: "Query 3", database: "employees", symbol: "tablecells", serverColor: .blue),
        LabTabItem(title: "Query 4", database: "warehouse", symbol: "tablecells", serverColor: .purple),
    ]
    @State private var activeID: UUID?

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.xs) {
            treeCard
                .frame(width: LayoutTokens.TabProposals.treeWidth)
            VStack(spacing: design == .attached ? SpacingTokens.none : SpacingTokens.xs) {
                LabRound13TabBar(design: design, tabs: $tabs, activeID: $activeID)
                LabCard {
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text("1    SELECT *")
                        Text("2    FROM employees")
                        Text("3    WHERE active = true;")
                    }
                    .font(TypographyTokens.detailMono)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .padding(SpacingTokens.md)
                }
                .frame(height: LayoutTokens.TabProposals.editorHeight)
            }
        }
        .padding(SpacingTokens.sm)
        .frame(width: LayoutTokens.TabProposals.previewWidth)
        .background(ColorTokens.Workspace.canvas, in: .rect(cornerRadius: LayoutTokens.Workspace.cardCornerRadius))
        .onAppear { activeID = activeID ?? tabs.first?.id }
    }

    private var treeCard: some View {
        LabCard {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Text("Microsoft SQL Server")
                    .font(TypographyTokens.standard.weight(.semibold))
                Text("Databases  252")
                Text("Security")
                Text("Agent Jobs  113")
                Text("   Agent Jobs Overview")
                    .foregroundStyle(ColorTokens.Text.primary)
                    .padding(SpacingTokens.xxs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ColorTokens.Sidebar.selectedFill, in: .rect(cornerRadius: LayoutTokens.Workspace.treeRowCornerRadius))
            }
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.secondary)
            .padding(SpacingTokens.sm)
        }
        .frame(height: LayoutTokens.TabProposals.editorHeight + LayoutTokens.TabProposals.barHeight + SpacingTokens.xs)
    }
}
