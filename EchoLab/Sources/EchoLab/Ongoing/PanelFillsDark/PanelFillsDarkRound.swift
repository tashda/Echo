import AppKit
import SwiftUI

/// Round 32.2 · Panels in dark mode. Measured from the owner's dark screenshot: canvas 27 to 29,
/// every card 30 (out of 255). The canvas is windowBackgroundColor and the cards textBackgroundColor
/// (ColorTokens.Workspace), which are nearly the same in dark mode; the card shadow (black 12%) can't
/// show on a dark canvas, so only the 0.5pt separator edge at 35% tells a card from the canvas.
/// The exhibits are always drawn dark. Changes WIN (canvas and cards).
@MainActor
enum PanelFillsDarkRound {
    enum Canvas: String, CaseIterable {
        case today = "DC0 · Window background, about 28 (today)"
        case darker = "DC1 · A step darker, about 18"
        case black = "DC2 · Almost black, about 9"
        case lighter = "DC3 · Lighter than the cards, about 44 (cards sit in it)"

        var white: CGFloat? {
            switch self {
            case .today: nil
            case .darker: 0.07
            case .black: 0.035
            case .lighter: 0.17
            }
        }
    }

    enum Card: String, CaseIterable {
        case today = "DD0 · Text background, 30 (today, the Midnight editor's colour)"
        case lighter = "DD1 · A step lighter, about 38"
    }

    enum Edge: String, CaseIterable {
        case today = "DE0 · Separator at 35%, 0.5pt (today)"
        case hairline = "DE1 · White at 10%, 0.5pt"
        case lit = "DE2 · DE1 with a lit top edge"
    }

    enum Shadow: String, CaseIterable {
        case today = "DS0 · Black 12% (today)"
        case deep = "DS1 · Black 50%, a little wider"
    }

    struct Look {
        var canvas: Canvas, card: Card, edge: Edge, shadow: Shadow
        static let today = Look(canvas: .today, card: .today, edge: .today, shadow: .today)

        @MainActor static func from(_ v: RoundValues) -> Look {
            Look(canvas: .init(rawValue: v["canvas"]) ?? .darker, card: .init(rawValue: v["card"]) ?? .today,
                 edge: .init(rawValue: v["edge"]) ?? .lit, shadow: .init(rawValue: v["shadow"]) ?? .deep)
        }

        var surfaces: LabWKSurfaces {
            var s = LabWKSurfaces.echo
            if let white = canvas.white { s.canvas = Color(nsColor: NSColor(white: white, alpha: 1)) }
            if card == .lighter {
                s.card = Color(nsColor: NSColor(white: 0.15, alpha: 1))
                s.sideCard = s.card
            }
            if edge != .today { s.edge = ColorTokens.Text.primary.opacity(0.1) }
            if edge == .lit { s.topHighlight = ColorTokens.Text.primary.opacity(0.14) }
            if shadow == .deep { s.shadowOpacity = 0.5; s.shadowRadius = 14 }
            return s
        }
    }

    static let spec = RoundSpec(
        controls: [
            .of("canvas", "Canvas", Canvas.self, default: .darker,
                question: "Look at the whole Proposal window. How dark should the canvas behind the cards be?",
                recommend: .darker,
                why: "Moving the canvas, not the cards, keeps the editor's Midnight background (30) the same as its card, and a 12-step gap is what Finder and Xcode leave between their window and content. Almost black makes the cards glow; a lighter canvas reverses the light-mode logic, where cards are the brightest surface."),
            .of("card", "Cards", Card.self, default: .today,
                question: "Compare the cards at 30 and at about 38.",
                recommend: .today,
                why: "Lighter cards would no longer match the Midnight editor, so the editor would sit as a dark slab inside a lighter card."),
            .of("edge", "Edge", Edge.self, default: .lit,
                question: "Look at the cards' edges, especially at the top.",
                recommend: .lit,
                why: "In dark mode light comes from the edge, not the shadow: a white hairline with a slightly brighter top is how macOS 26 draws its own dark panels and sheets. The grey separator at 35% almost vanishes on a dark canvas."),
            .of("shadow", "Shadow", Shadow.self, default: .deep,
                question: "Compare the shadows under the cards.",
                recommend: .deep,
                why: "Black 12% can't be seen on a dark canvas; 50% gives the cards the same lift they have in light mode. Keep light mode's shadow as it is."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Canvas about 28, cards 30, a grey 0.5pt edge.",
                  isEchoToday: true, isWide: true, designWidth: 760, designHeight: 440) { _ in
                LabPDWindow(look: .today)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls.",
                  isWide: true, designWidth: 760, designHeight: 440) { values in
                LabPDWindow(look: Look.from(values))
            },
        ],
        questions: [
            .init(id: "contrast", title: "Increase Contrast",
                  question: "With Increase Contrast on, what should change on top of the choice above?",
                  choices: [
                      .init(id: "edge", name: "IC0 · A solid 1pt edge in the separator colour"),
                      .init(id: "same", name: "IC1 · Nothing more"),
                  ],
                  recommended: "edge",
                  why: "That is what the system does for its own panels with Increase Contrast; the hairline and lit edge are too subtle for someone who turned it on."),
        ],
        exhibitTopic: ("Which dark window?", "Is the Proposal easier to read than Echo today in dark mode?", "proposal",
                       "A darker canvas, cards unchanged, a lit hairline edge and a real shadow."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Darker canvas, today's cards, lit edge, deep shadow.",
                  values: ["canvas": Canvas.darker.rawValue, "card": Card.today.rawValue, "edge": Edge.lit.rawValue, "shadow": Shadow.deep.rawValue],
                  isRecommended: true),
            .init(id: "edgeOnly", name: "Edges only", summary: "Today's colours with a lit edge and shadow.",
                  values: ["canvas": Canvas.today.rawValue, "card": Card.today.rawValue, "edge": Edge.lit.rawValue, "shadow": Shadow.deep.rawValue]),
            .init(id: "black", name: "Black canvas", values: ["canvas": Canvas.black.rawValue, "edge": Edge.hairline.rawValue]),
        ]
    )
}

private struct LabPDWindow: View {
    let look: PanelFillsDarkRound.Look

    var body: some View {
        let surfaces = look.surfaces
        LabWKWindow(surfaces: surfaces, tree: AnyView(LabSHCard(server: .production, look: .today, rowLimit: 6, surfaces: surfaces))) {
            VStack(spacing: SpacingTokens.xs) {
                LabWKEditor().frame(height: SpacingTokens.xxxl * 2).labWKCard(surfaces.card, surfaces)
                VStack(spacing: SpacingTokens.none) {
                    LabWKGrid()
                    Spacer(minLength: 0)
                    LabWKFooter()
                }
                .labWKCard(surfaces.card, surfaces)
            }
        }
        .environment(\.colorScheme, .dark)
    }
}
