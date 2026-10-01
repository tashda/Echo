import SwiftUI

/// Round 26: a small Echo window (rail, tree, one tool card holding a real SwiftUI `Table` like the
/// Activity Monitor's sessions) whose tree slides away and back, so the content's behaviour during
/// the slide is felt with real table cells, as heavy as Echo's. The slide uses Echo's curves:
/// hiding settles without overshoot, showing uses the house spring (WIN-3.2).
struct LabCDSWindow: View {
    let mode: LabCDSMode
    let rows: Int
    let speed: LabSpeed
    let toggleToken: String

    @State private var isTreeShown = true
    /// The content's width while the slide runs; nil lets it follow the card.
    @State private var heldWidth: CGFloat?
    @State private var windowWidth: CGFloat = 0

    private let railWidth = SpacingTokens.xl2
    private let treeWidth = LayoutTokens.Workspace.treeMinWidth
    private let gutter = SpacingTokens.xs

    /// The card's width with the tree shown and hidden.
    private var narrowCard: CGFloat { windowWidth - railWidth - treeWidth - gutter * 4 }
    private var wideCard: CGFloat { windowWidth - railWidth - gutter * 3 }

    var body: some View {
        HStack(spacing: SpacingTokens.none) {
            rail.padding(.trailing, gutter)
            tree
                .frame(width: isTreeShown ? treeWidth : 0, alignment: .trailing)
                .clipped()
                .opacity(isTreeShown ? 1 : 0)
                .padding(.trailing, isTreeShown ? gutter : 0)
            card
        }
        .padding(gutter)
        .background(ColorTokens.Workspace.canvas)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { windowWidth = $0 }
        .onChange(of: toggleToken) { _, _ in slide() }
    }

    private func slide() {
        let motion = speed.motion()
        let start = isTreeShown ? narrowCard : wideCard
        let end = isTreeShown ? wideCard : narrowCard
        switch mode {
        case .live: heldWidth = nil
        case .holdThenSettle: heldWidth = start
        case .settleFirst: heldWidth = end
        }
        withAnimation(isTreeShown ? motion.settle : motion.standard) {
            isTreeShown.toggle()
        } completion: {
            heldWidth = nil
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack {
                Text("Activity Monitor").font(TypographyTokens.headline)
                Spacer()
                Button(isTreeShown ? "Hide Tree" : "Show Tree", action: slide)
            }
            .padding([.horizontal, .top], SpacingTokens.sm)
            sessions
        }
        .frame(width: heldWidth, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .workspaceCard()
    }

    private var sessions: some View {
        Table(LabCDSSession.samples(rows)) {
            TableColumn("SPID") { Text("\($0.id)").font(TypographyTokens.Table.numeric) }.width(min: 40, ideal: 50)
            TableColumn("Login") { Text($0.login) }
            TableColumn("Database") { Text($0.database) }
            TableColumn("Status") { Text($0.status).font(TypographyTokens.Table.category) }
            TableColumn("Command") { Text($0.command).font(TypographyTokens.Table.category) }
            TableColumn("CPU") { Text("\($0.cpu)").font(TypographyTokens.Table.numeric) }
            TableColumn("Reads") { Text("\($0.reads)").font(TypographyTokens.Table.numeric) }
            TableColumn("Wait") { Text($0.wait).font(TypographyTokens.Table.category) }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }

    private var rail: some View {
        VStack(spacing: SpacingTokens.xs) {
            ForEach(["TM", "TP"], id: \.self) { name in
                Text(name).font(TypographyTokens.detail.weight(.semibold))
                    .frame(width: SpacingTokens.lg2, height: SpacingTokens.lg2)
                    .background(ColorTokens.Background.primary, in: .circle)
            }
            Spacer()
        }
        .frame(width: railWidth)
    }

    private var tree: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Test MSSQL").font(TypographyTokens.headline)
            ForEach(["AdventureWorks2022", "master", "model", "msdb", "tempdb", "WideWorldImporters"], id: \.self) { name in
                Label(name, systemImage: "cylinder").font(TypographyTokens.standard)
            }
            Spacer()
        }
        .padding(SpacingTokens.sm)
        .frame(width: treeWidth, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .workspaceCard()
    }
}
