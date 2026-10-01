import SwiftUI

/// Round 32.1 · Panels: is the inspector whiter? Measured from the owner's screenshots (light mode):
/// the tree, editor, results, inspector and both Agent Jobs panes are all 255 (every card is
/// `ColorTokens.Workspace.card`, textBackgroundColor, through `workspaceCard()`); the canvas is 234.
/// Inside the panes, zebra rows and the steps list's placeholder rows are 245. So the inspector isn't
/// whiter: it is the only card with no grey on it. Changes WIN (cards) and the tool tabs' tables.
@MainActor
enum PanelFillsLightRound {
    enum Zebra: String, CaseIterable {
        case today = "ZB0 · Zebra rows in grids and tool-tab tables (today)"
        case gridOnly = "ZB1 · Zebra only in the results grid; tool-tab lists plain"
        case none = "ZB2 · No zebra anywhere; hover and selection only"

        var summary: String {
            switch self {
            case .today: "Every second row is 245 (black at 4%), in the results and in Agent Jobs' lists."
            case .gridOnly: "The results grid keeps its stripes (many columns, long rows); short lists in tool tabs don't need them."
            case .none: "Every pane is plain white like the inspector; long rows rely on the hover fill."
            }
        }
    }

    enum SideCards: String, CaseIterable {
        case white = "SC0 · Every card white (today)"
        case softer = "SC1 · The tree and inspector a step softer (98.5%)"
        var summary: String {
            switch self {
            case .white: "One fill for every card."
            case .softer: "The cards you work in stay white; the ones beside them are 251, which you notice as calmer rather than grey."
            }
        }
    }

    enum EmptyInspector: String, CaseIterable {
        case today = "EI0 · “No Selection” at the top (today)"
        case box = "EI1 · The same text in a grouped box"
        case centred = "EI2 · Centred, with a symbol, like the system's empty views"
    }

    static let spec = RoundSpec(
        controls: [
            .of("zebra", "Zebra rows", Zebra.self, default: .gridOnly,
                question: "Compare the Agent Jobs exhibits. Is it the stripes that make Details and the jobs list look greyer than the inspector?",
                recommend: .gridOnly,
                why: "The stripes are what you are seeing: half the rows are 245. They earn their place in a wide results grid where the eye follows a row across many columns, not in lists of a few short columns. ZB2 also removes them from results, which SSMS and DataGrip users rely on.",
                summary: \.summary),
            .of("sideCards", "Side cards", SideCards.self, default: .white,
                question: "Look at the Proposal window. Should the tree and inspector be a step softer than the cards you work in?",
                recommend: .white,
                why: "Close call. One white for every card is the rule you set in round 3–8 and keeps the window calm; SC1 is the option if, after the stripes go, the inspector still stands out.",
                summary: \.summary),
            .of("emptyInspector", "Empty inspector", EmptyInspector.self, default: .centred,
                question: "Look at the inspector with nothing selected.",
                recommend: .centred,
                why: "A tall white card with two lines at the top is what reads as glare. Centred with a quiet symbol it reads as a deliberate empty state, the way Xcode's inspector and Finder's preview do."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Every card 255; zebra rows 245; the inspector empty.",
                  isEchoToday: true, isWide: true, designWidth: 760, designHeight: 440) { _ in
                LabPFWindow(zebra: .today, sideCards: .white, empty: .today, jobs: false)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls.",
                  isWide: true, designWidth: 760, designHeight: 440) { values in
                LabPFWindow(values, jobs: false)
            },
            .init(id: "jobsToday", title: "Agent Jobs, today", summary: "The jobs list and Details stripe every second row; the inspector has nothing on it.",
                  isEchoToday: true, isWide: true, designWidth: 760, designHeight: 440) { _ in
                LabPFWindow(zebra: .today, sideCards: .white, empty: .today, jobs: true)
            },
            .init(id: "jobsProposal", title: "Agent Jobs, proposal", summary: "Built from the controls.",
                  isWide: true, designWidth: 760, designHeight: 440) { values in
                LabPFWindow(values, jobs: true)
            },
        ],
        questions: [
            .init(id: "measured", title: "Is it true?",
                  question: "Every card measures 255 in your screenshots; the difference is what is drawn on them. Does that match what you see in the exhibits?",
                  choices: [
                      .init(id: "yes", name: "Yes: it's the stripes and the empty card"),
                      .init(id: "no", name: "No: the inspector still looks whiter (tell me where)"),
                  ],
                  recommended: "yes",
                  why: "The measurement is from your own screenshots: tree, editor, inspector, jobs list and Details all 255, the stripes 245, the canvas 234."),
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Stripes only in the grid, one white, centred empty inspector.",
                  values: ["zebra": Zebra.gridOnly.rawValue, "sideCards": SideCards.white.rawValue, "emptyInspector": EmptyInspector.centred.rawValue],
                  isRecommended: true),
            .init(id: "calm", name: "Calmest", summary: "No stripes, softer side cards.",
                  values: ["zebra": Zebra.none.rawValue, "sideCards": SideCards.softer.rawValue, "emptyInspector": EmptyInspector.centred.rawValue]),
        ]
    )
}

/// The window with a query tab or the Agent Jobs tab, drawn with round 32.1's choices.
private struct LabPFWindow: View {
    let zebra: PanelFillsLightRound.Zebra
    let sideCards: PanelFillsLightRound.SideCards
    let empty: PanelFillsLightRound.EmptyInspector
    let jobs: Bool

    init(zebra: PanelFillsLightRound.Zebra, sideCards: PanelFillsLightRound.SideCards, empty: PanelFillsLightRound.EmptyInspector, jobs: Bool) {
        self.zebra = zebra
        self.sideCards = sideCards
        self.empty = empty
        self.jobs = jobs
    }

    @MainActor init(_ values: RoundValues, jobs: Bool) {
        self.init(zebra: .init(rawValue: values["zebra"]) ?? .gridOnly, sideCards: .init(rawValue: values["sideCards"]) ?? .white,
                  empty: .init(rawValue: values["emptyInspector"]) ?? .centred, jobs: jobs)
    }

    private var surfaces: LabWKSurfaces {
        var s = LabWKSurfaces.echo
        if sideCards == .softer { s.sideCard = Color.adaptive(light: NSColor(white: 0.985, alpha: 1), dark: .textBackgroundColor) }
        return s
    }

    var body: some View {
        LabWKWindow(surfaces: surfaces, tabs: jobs ? ["Query 1", "Jobs"] : ["Query 1", "Query 2"], activeTab: jobs ? 1 : 0,
                    tree: AnyView(LabSHCard(server: .production, look: .today, rowLimit: 6, surfaces: surfaces)),
                    inspector: AnyView(inspector)) {
            if jobs {
                HStack(spacing: SpacingTokens.xs) {
                    LabPFList(title: "Jobs", rows: ["Cleanup Safepoint", "CommandLog Cleanup", "Daily SQL Job", "DatabaseBackup LOG", "DatabaseBackup FULL", "IntegrityCheck", "IndexOptimize"],
                              striped: zebra == .today)
                        .labWKCard(surfaces.card, surfaces)
                    LabPFList(title: "Details", rows: ["DatabaseIntegrityCheck · TSQL", "", "", "", ""], striped: zebra == .today)
                        .labWKCard(surfaces.card, surfaces)
                }
            } else {
                VStack(spacing: SpacingTokens.xs) {
                    LabWKEditor().frame(height: SpacingTokens.xxxl * 2).labWKCard(surfaces.card, surfaces)
                    VStack(spacing: SpacingTokens.none) {
                        LabWKGrid(rows: LabWKGrid.checkpointRows + LabWKGrid.checkpointRows)
                            .environment(\.labWKStriped, zebra != .none)
                        Spacer(minLength: 0)
                        LabWKFooter()
                    }
                    .labWKCard(surfaces.card, surfaces)
                }
            }
        }
    }

    @ViewBuilder
    private var inspector: some View {
        switch empty {
        case .today: LabWKNoSelection()
        case .box:
            LabWKNoSelection().background(ColorTokens.Workspace.groupFill, in: .rect(cornerRadius: SpacingTokens.xs)).padding(SpacingTokens.xs)
        case .centred:
            VStack(spacing: SpacingTokens.xxs) {
                Image(systemName: "sidebar.right").font(TypographyTokens.title2).foregroundStyle(ColorTokens.Text.tertiary)
                Text("No Selection").font(TypographyTokens.standard.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                Text("Select an object, a cell or a row.").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(SpacingTokens.sm)
            .frame(maxWidth: .infinity, minHeight: SpacingTokens.xxxl * 5)
        }
    }
}

/// A tool tab's list pane: a title and rows, striped or plain.
private struct LabPFList: View {
    let title: String
    let rows: [String]
    let striped: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            Text(title).font(TypographyTokens.headline).padding(SpacingTokens.sm)
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                Text(row).font(TypographyTokens.standard).lineLimit(1)
                    .padding(.horizontal, SpacingTokens.sm)
                    .frame(maxWidth: .infinity, minHeight: SpacingTokens.lg + SpacingTokens.xxs, alignment: .leading)
                    .background(striped && !index.isMultiple(of: 2) ? ColorTokens.Sidebar.hoverFill : .clear)
            }
            Spacer(minLength: 0)
        }
    }
}
