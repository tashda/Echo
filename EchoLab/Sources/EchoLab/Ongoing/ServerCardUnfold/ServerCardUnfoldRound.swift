import SwiftUI

/// Round 46 · Server card: opening and closing. The owner, checking round 30.2 in Echo: the card's
/// edge glides, but the dock and the tree "just appear". Cause, from the code: the tree's list
/// turns animation off whenever its dock selections change (`.animation(nil, value: dockSelections)`
/// in ObjectBrowserOutlineView, so a section switch never slides rows). Opening or closing a
/// docked server adds or removes its dock, which counts as a change, so the dock and every row
/// arrive and leave at once, over the canvas, while the cards layer still glides the edge. Echo
/// today below draws exactly that. The owner asked to look at how switching sections animates
/// (round 19, S3: a veil in the card's colour, the edge settling, the veil fading away) and find a
/// proper way to bring the dock in. Changes TREE-2.5.
@MainActor
enum ServerCardUnfoldRound {
    private static let width = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xl * 2

    static let spec = RoundSpec(
        controls: [
            .of("dock", "Dock", LabUFDock.self, default: .grow,
                question: "Close and open the Proposal with each dock choice (Slow motion helps). How should the dock arrive?",
                recommend: .grow,
                why: "The dock is the card's only glass, and glass on macOS 26 takes shape rather than fading: growing from 92% under the header, coming into focus, reads as the capsule forming out of the server's name. A plain fade looks like a loading state; sliding from under the name fights the header for the same 10pt; DA4 is the richest but makes you wait for icons you came to click.",
                summary: \.summary),
            .of("rows", "Rows", LabUFRows.self, default: .veil,
                question: "Now watch the rows as the card opens. Which arrival belongs with the dock above?",
                recommend: .veil,
                why: "You pointed at the section switch: RA1 is that motion, so opening a card and switching its section speak one language, and one veil animates instead of every row (it costs the main thread almost nothing). RA2 shows an empty card first; RA3 is lively but 300 ms for seven databases; RA4 is honest but the rows slide past the edge with no settling.",
                summary: \.summary),
            .of("close", "Closing", LabUFClose.self, default: .veilThenFold,
                question: "Close the card. How should the dock and the rows leave?",
                recommend: .veilThenFold,
                why: "Covering the rows first is how a section switch starts, so closing reads as the same family, and the edge never has to cut through rows. CL1 runs both at once and the rows smear under the moving edge; CL3 is fine but flashes the empty card.",
                summary: \.summary),
            .of("speed", "Speed", LabUFSpeed.self, default: .normal),
        ],
        actions: [
            .init(id: "replay", title: "Close and open", symbol: "rectangle.compress.vertical") { values in
                values["pulse"] = UUID().uuidString
            },
            .init(id: "switch", title: "Switch section", symbol: "arrow.left.arrow.right") { values in
                values["switchPulse"] = UUID().uuidString
            },
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "The edge glides; the dock and the rows are there at once, over the canvas, then gone at once. Click the header, or a dock icon to see the section switch.",
                  isEchoToday: true, designWidth: width, designHeight: 420) { values in
                LabUFColumn { LabUFCard(look: .today(values), pulse: values["pulse"], switchPulse: values["switchPulse"]) }
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Click the header to close and open; click a dock icon to compare with a section switch.",
                  designWidth: width, designHeight: 420) { values in
                LabUFColumn { LabUFCard(look: LabUFLook(values), pulse: values["pulse"], switchPulse: values["switchPulse"]) }
            },
            .init(id: "column", title: "In a column", summary: "Three servers, the middle one closed. Open it: the card below follows the edge.",
                  designWidth: width, designHeight: 560) { values in
                LabUFColumn {
                    LabUFCard(look: LabUFLook(values), title: "dkloosql20-t", product: "SQL Server 2022", tint: ColorTokens.Status.success, startsOpen: false)
                    LabUFCard(look: LabUFLook(values), pulse: values["pulse"])
                    LabUFCard(look: LabUFLook(values), title: "postgres18", product: "PostgreSQL 18", tint: ColorTokens.Status.info, startsOpen: false)
                }
            },
        ],
        exhibitTopic: ("Which opening?", "Judged against Echo today, is the Proposal how a server card should open and close?", "proposal",
                       "The dock takes shape out of the header while the edge glides, and the rows come in and go out under the same veil as a section switch, so the card has one way of changing."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "The dock grows out of the header; rows under the switch's veil; closing covers, then folds.",
                  values: ["dock": LabUFDock.grow.rawValue, "rows": LabUFRows.veil.rawValue, "close": LabUFClose.veilThenFold.rawValue],
                  isRecommended: true),
            .init(id: "quiet", name: "Quiet", summary: "Everything fades with the edge.",
                  values: ["dock": LabUFDock.fade.rawValue, "rows": LabUFRows.fadeAfter.rawValue, "close": LabUFClose.reverse.rawValue]),
            .init(id: "lively", name: "Lively", summary: "The capsule unfolds and the rows cascade.",
                  values: ["dock": LabUFDock.unfold.rawValue, "rows": LabUFRows.cascade.rawValue, "close": LabUFClose.reverse.rawValue]),
            .init(id: "drawer", name: "Drawer", summary: "The edge uncovers the dock and rows; nothing fades.",
                  values: ["dock": LabUFDock.slide.rawValue, "rows": LabUFRows.drawer.rawValue, "close": LabUFClose.reverse.rawValue]),
        ]
    )
}

/// The tree's column: the canvas with the cards stacked, as Echo lays them out.
private struct LabUFColumn<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: SpacingTokens.xs) { content; Spacer(minLength: 0) }
            .padding(SpacingTokens.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(ColorTokens.Workspace.canvas)
    }
}
