import SwiftUI

/// Round 30.2 · Server card: collapsing. Echo today (ObjectBrowserRowView+Headers): the header's
/// HStack is top-aligned, so the chevron sits level with the name's top, not centred on the two
/// lines; it shows on hover while open and always while closed. Closing removes the dock and rows:
/// they fade (opacity, `rowRemoval`) while the card's background (ExplorerTreeCardsLayer) changes
/// height at once, so the rows briefly float over the canvas. Changes TREE-2.1 and TREE-1.2.
@MainActor
enum ServerHeaderCollapseRound {
    private static let width = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xl * 2

    static let spec = RoundSpec(
        controls: [
            .of("chevron", "Chevron", LabSCollapseChevron.self, default: .centredText,
                question: "Close and open the Proposal with each place. Where should the chevron sit?",
                recommend: .centredText,
                why: "You saw it off-centre: centring it on the name and product line puts it where the eye reads the header, and it doesn't move when the card closes. CP2 moves it as the dock appears and disappears; CP3 shifts the name, which every other card in the tree keeps at 12pt.",
                summary: \.summary),
            .of("shows", "Shows", LabSCollapseShows.self, default: .today,
                question: "Hover in and out of the header, open and closed. When should the chevron be visible?",
                recommend: .today,
                why: "Finder's sidebar works this way: a closed card must say it can open, an open one only needs the chevron when you reach for it. Always shown adds a mark to every card; hover-only hides that a closed card has more."),
            .of("motion", "Motion", LabSCollapseMotion.self, default: .foldFade,
                question: "Close and open each card with every motion, at Default speed and with Fast. Which feels right?",
                recommend: .foldFade,
                why: "The card's edge moving with its rows is what was missing today. CM2 keeps today's 0.22 s and fades the rows so nothing is left floating when the edge passes; CM3's bounce reads as playful on a card this tall, and CM5 makes you wait for something you asked to hide.",
                summary: \.summary),
            .of("closed", "Closed card", LabSCollapseClosed.self, default: .header,
                question: "Close a card. Should the dock stay visible, so a section can be opened in one click?",
                recommend: .header,
                why: "A closed card is a request for quiet; keeping the dock keeps 34pt of glass per closed server. If you close servers to jump between sections, CC1 is the one to try."),
            .of("symbol", "Symbol", LabSCollapseSymbol.self, default: .turning,
                question: "Compare the bare chevron with one in a soft circle.",
                recommend: .turning,
                why: "The bare chevron is the system's disclosure (Finder, Mail); a circle adds a button shape the tree uses nowhere else."),
        ],
        actions: [
            .init(id: "toggle", title: "Close and open every card", symbol: "rectangle.compress.vertical") { values in
                values["pulse"] = UUID().uuidString
            },
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "Chevron level with the name; the rows fade while the card has already changed size. Click the header.",
                  isEchoToday: true, designWidth: width, designHeight: 420) { values in
                LabSCollapseColumn(look: .today, values: values, servers: [.production])
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Click the header.",
                  designWidth: width, designHeight: 420) { values in
                LabSCollapseColumn(look: LabSCollapseLook(values), values: values, servers: [.production])
            },
            .init(id: "column", title: "Three cards", summary: "The middle card closes and opens; watch the card below it follow.",
                  designWidth: width, designHeight: 560) { values in
                LabSCollapseColumn(look: LabSCollapseLook(values), values: values, servers: [.test, .development, .production])
            },
        ],
        exhibitTopic: ("Which collapse?", "Is the Proposal how a server card should close and open?", "proposal",
                       "The chevron centred on the header and a card that folds with its rows, at today's speed."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Centred chevron, fold while fading, header only when closed.",
                  values: ["chevron": LabSCollapseChevron.centredText.rawValue, "shows": LabSCollapseShows.today.rawValue,
                           "motion": LabSCollapseMotion.foldFade.rawValue, "closed": LabSCollapseClosed.header.rawValue,
                           "symbol": LabSCollapseSymbol.turning.rawValue],
                  isRecommended: true),
            .init(id: "lively", name: "Lively", summary: "Spring fold and the dock kept on closed cards.",
                  values: ["motion": LabSCollapseMotion.spring.rawValue, "closed": LabSCollapseClosed.dock.rawValue]),
            .init(id: "finder", name: "Finder", summary: "A leading disclosure, rows rolling up.",
                  values: ["chevron": LabSCollapseChevron.leading.rawValue, "motion": LabSCollapseMotion.rollUp.rawValue]),
        ]
    )
}

/// A column of collapsible cards on the canvas. The first card in a one-card column, or the
/// middle card in a longer one, answers the Close and open action.
private struct LabSCollapseColumn: View {
    let look: LabSCollapseLook
    let values: RoundValues
    let servers: [LabSHServer]
    @State private var open: [String: Bool] = [:]
    @Environment(\.echoMotion) private var motion

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            ForEach(servers) { server in
                LabSCollapseCard(server: server, look: look, isOpen: binding(server.id))
            }
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorTokens.Workspace.canvas)
        .onChange(of: values["pulse"]) { _, _ in replay() }
    }

    private var target: String { servers[servers.count / 2].id }

    private func binding(_ id: String) -> Binding<Bool> {
        Binding(get: { open[id] ?? true }, set: { open[id] = $0 })
    }

    private func replay() {
        withAnimation(look.animation(motion)) { open[target] = false }
        Task {
            try? await Task.sleep(for: .seconds(1.1))
            withAnimation(look.animation(motion)) { open[target] = true }
        }
    }
}
