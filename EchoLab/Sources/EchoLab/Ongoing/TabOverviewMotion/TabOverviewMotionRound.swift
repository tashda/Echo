import SwiftUI

/// Round 35.4 · Tab overview: opening, closing and keys. Echo today (plan O3,
/// WorkspaceTabContainerView+OverviewPinch): the toolbar's overview button, ⇧⌘O or a pinch in opens
/// it; the tab scales down and fades as the overview scales in on the house spring, and picking a
/// card reverses it. It is not a true zoom into the card (the card's frame isn't known).
@MainActor
enum TabOverviewMotionRound {
    enum Motion: String, CaseIterable {
        case today = "OM0 · The tab shrinks and fades; the overview scales in (today)"
        case zoom = "OM1 · The tab shrinks into its own card; the others fade in around it"
        case rise = "OM2 · The cards rise from the bottom like a sheet"
        case crossfade = "OM3 · A quick crossfade"

        var summary: String {
            switch self {
            case .today: "Two separate movements; your eye loses the tab you were in."
            case .zoom: "Safari and Mission Control: the tab becomes its card, so you always know where you came from. Picking a card zooms it back to full size."
            case .rise: "The tab stays put and dims; the overview slides up over it."
            case .crossfade: "Fastest, no spatial story."
            }
        }
    }

    static let spec = RoundSpec(
        controls: [
            .of("motion", "Motion", Motion.self, default: .zoom,
                question: "Press Open and close the overview, then click other cards, in each motion and at both speeds. Which keeps you oriented?",
                recommend: .zoom,
                why: "The point of the motion is to show where your tab went and where the picked one comes from; only a zoom into the card does both. It needs the card's frame from inside the scroll view, which is why today approximates it; worth building properly.",
                summary: \.summary),
        ],
        actions: [
            .init(id: "toggle", title: "Open and close the overview", symbol: "square.grid.2x2") { $0["pulse"] = UUID().uuidString },
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Click the tab to open; click a card to go there.",
                  isEchoToday: true, designWidth: 560, designHeight: 380) { values in
                LabTOMotionStage(motion: .today, values: values)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls.",
                  designWidth: 560, designHeight: 380) { values in
                LabTOMotionStage(motion: Motion(rawValue: values["motion"]) ?? .zoom, values: values)
            },
        ],
        questions: [
            .init(id: "keys", title: "Keyboard",
                  question: "With the overview open: arrows move between cards, Return opens, Esc goes back to the tab you came from. What does ⌫ do?",
                  choices: [
                      .init(id: "close", name: "KB0 · Closes the selected tab (with Undo)"),
                      .init(id: "nothing", name: "KB1 · Nothing; closing is ⌘W on the selected card"),
                  ],
                  recommended: "nothing",
                  why: "⌫ while typing a search would delete text in one moment and close a tab the next; ⌘W is already Close Tab everywhere."),
            .init(id: "pinch", title: "Pinch",
                  question: "Keep the trackpad pinch that opens and closes the overview?",
                  choices: [.init(id: "keep", name: "PI0 · Keep it (today)"), .init(id: "drop", name: "PI1 · Remove it")],
                  recommended: "keep",
                  why: "It's how Safari's overview opens on a trackpad, and with the zoom motion it follows your fingers' meaning."),
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", values: ["motion": Motion.zoom.rawValue], isRecommended: true),
        ]
    )
}

/// One tab that opens into a grid of six cards and back.
private struct LabTOMotionStage: View {
    let motion: TabOverviewMotionRound.Motion
    let values: RoundValues
    @State private var isOpen = false
    @State private var current = LabTOTab.activeID
    @Namespace private var space
    @Environment(\.echoMotion) private var echoMotion

    private var tabs: [LabTOTab] { Array(LabTOTab.samples.prefix(6)) }
    private var animation: Animation { motion == .crossfade ? echoMotion.hover : echoMotion.standard }

    var body: some View {
        ZStack {
            ColorTokens.Workspace.canvas
            if isOpen { overview.transition(overviewTransition) }
            if !isOpen || motion == .rise {
                fullTab
                    .opacity(isOpen && motion == .rise ? 0.35 : 1)
                    .transition(tabTransition)
                    .onTapGesture { withAnimation(animation) { isOpen = true } }
            }
        }
        .clipped()
        .onChange(of: values["pulse"]) { _, _ in withAnimation(animation) { isOpen.toggle() } }
    }

    private var fullTab: some View {
        let tab = tabs.first { $0.id == current } ?? tabs[0]
        return LabTOSnapshot(tab: tab)
            .clipShape(.rect(cornerRadius: SpacingTokens.sm, style: .continuous))
            .matchedGeometryEffect(id: motion == .zoom ? tab.id : "none-full", in: space)
            .padding(SpacingTokens.sm)
    }

    private var overview: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sm), count: 3), spacing: SpacingTokens.sm) {
            ForEach(tabs) { tab in
                LabTOCard(tab: tab, isActive: tab.id == current, compact: true)
                    .matchedGeometryEffect(id: motion == .zoom ? tab.id : "none-\(tab.id)", in: space)
                    .onTapGesture { withAnimation(animation) { current = tab.id; isOpen = false } }
            }
        }
        .padding(SpacingTokens.md)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(motion == .rise ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(ColorTokens.Workspace.canvas))
    }

    private var overviewTransition: AnyTransition {
        switch motion {
        case .today: .scale(scale: 1.08).combined(with: .opacity)
        case .zoom, .crossfade: .opacity
        case .rise: .move(edge: .bottom)
        }
    }

    private var tabTransition: AnyTransition {
        switch motion {
        case .today: .scale(scale: 0.92).combined(with: .opacity)
        case .zoom, .crossfade, .rise: .opacity
        }
    }
}
