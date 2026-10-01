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
        case cool = "DC4 · Cool graphite, about 20, a hint of blue"
        case warm = "DC5 · Warm graphite, about 20, a hint of brown"
        case close = "DC6 · Just under the cards, about 24"
        case underPage = "DC7 · The system's under-page colour, what Finder's sidebar sits on"
        case accent = "DC8 · Dark, with the accent colour at 8%"

        var color: Color? {
            switch self {
            case .today: nil
            case .darker: Color(nsColor: NSColor(white: 0.07, alpha: 1))
            case .black: Color(nsColor: NSColor(white: 0.035, alpha: 1))
            case .lighter: Color(nsColor: NSColor(white: 0.17, alpha: 1))
            case .cool: Color(nsColor: NSColor(red: 0.07, green: 0.078, blue: 0.10, alpha: 1))
            case .warm: Color(nsColor: NSColor(red: 0.092, green: 0.082, blue: 0.074, alpha: 1))
            case .close: Color(nsColor: NSColor(white: 0.095, alpha: 1))
            case .underPage: Color(nsColor: .underPageBackgroundColor)
            case .accent: Color(nsColor: NSColor(white: 0.07, alpha: 1).blended(withFraction: 0.08, of: .controlAccentColor) ?? NSColor(white: 0.07, alpha: 1))
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
        case stronger = "DE3 · A 1pt line, 16% of the text colour"
        case outer = "DE4 · A dark outer line and a light inner hairline, like a bevel"
        case quiet = "DE5 · A 7% hairline and a lit top edge, the quietest"
    }

    enum Shadow: String, CaseIterable {
        case today = "DS0 · Black 12% (today)"
        case deep = "DS1 · Black 50%, a little wider"
        case tight = "DS2 · Tight and dark: black 60%, 6pt"
        case wide = "DS3 · Wide and soft: black 55%, 28pt, well below the card"
        case none = "DS4 · No shadow, the edge does the work"
        case contact = "DS5 · A small contact shadow and a wide ambient one"

        /// Opacity, radius and offset in dark and in light mode: a dark shadow shows on white, a dark canvas needs more.
        func values(dark: Bool) -> (opacity: Double, radius: CGFloat, y: CGFloat) {
            switch self {
            case .today: (0.12, 10, 4)
            case .deep: dark ? (0.5, 14, 4) : (0.18, 14, 4)
            case .tight: dark ? (0.6, 6, 2) : (0.16, 6, 2)
            case .wide: dark ? (0.55, 28, 10) : (0.14, 28, 10)
            case .none: (0, 0, 0)
            case .contact: dark ? (0.6, 3, 1) : (0.2, 3, 1)
            }
        }
    }

    enum Contrast: String, CaseIterable {
        case edge = "IC0 · A solid 1pt edge in the separator colour"
        case same = "IC1 · Nothing more"
        case heavy = "IC2 · A solid 2pt edge, 60% of the text colour"
        case split = "IC3 · A 1pt solid edge, and the canvas pushed further from the cards"
        case crisp = "IC4 · A 1pt solid edge and no shadow, crisp rather than blurred"
    }

    struct Look {
        var canvas: Canvas, card: Card, edge: Edge, shadow: Shadow, contrast: Contrast
        static let today = Look(canvas: .today, card: .today, edge: .today, shadow: .today, contrast: .same)

        @MainActor static func from(_ v: RoundValues) -> Look {
            Look(canvas: .init(rawValue: v["canvas"]) ?? .darker, card: .init(rawValue: v["card"]) ?? .today,
                 edge: .init(rawValue: v["edge"]) ?? .lit, shadow: .init(rawValue: v["shadow"]) ?? .deep,
                 contrast: .init(rawValue: v["contrast"]) ?? .edge)
        }

        /// `dark` false draws the same edge, shadow and contrast choices on light mode's canvas and cards,
        /// which stay as they are (the owner likes light mode today).
        func surfaces(dark: Bool, increaseContrast: Bool) -> LabWKSurfaces {
            var s = LabWKSurfaces.echo
            if dark {
                if let color = canvas.color { s.canvas = color }
                if card == .lighter {
                    s.card = Color(nsColor: NSColor(white: 0.15, alpha: 1))
                    s.sideCard = s.card
                }
            }
            switch edge {
            case .today: break
            case .hairline: s.edge = ColorTokens.Text.primary.opacity(0.1)
            case .lit:
                s.edge = ColorTokens.Text.primary.opacity(0.1)
                if dark { s.topHighlight = ColorTokens.Text.primary.opacity(0.14) }
            case .stronger: s.edge = ColorTokens.Text.primary.opacity(0.16); s.edgeWidth = 1
            case .outer:
                s.edge = ColorTokens.Text.primary.opacity(dark ? 0.12 : 0.08)
                s.outerLine = .black.opacity(dark ? 0.55 : 0.12)
            case .quiet:
                s.edge = ColorTokens.Text.primary.opacity(0.07)
                if dark { s.topHighlight = ColorTokens.Text.primary.opacity(0.1) }
            }
            let shadow = shadow.values(dark: dark)
            s.shadowOpacity = shadow.opacity; s.shadowRadius = shadow.radius; s.shadowY = shadow.y
            if self.shadow == .contact {
                let ambient = dark ? (0.4, 24.0, 10.0) : (0.1, 24.0, 10.0)
                s.ambientShadowOpacity = ambient.0; s.ambientShadowRadius = ambient.1; s.ambientShadowY = ambient.2
            }
            if increaseContrast {
                switch contrast {
                case .same: break
                case .edge: s.edge = ColorTokens.Workspace.cardEdge; s.edgeWidth = 1; s.topHighlight = nil; s.outerLine = nil
                case .heavy: s.edge = ColorTokens.Text.primary.opacity(0.6); s.edgeWidth = 2; s.topHighlight = nil; s.outerLine = nil
                case .split:
                    s.edge = ColorTokens.Workspace.cardEdge; s.edgeWidth = 1; s.topHighlight = nil; s.outerLine = nil
                    s.canvas = dark ? Color(nsColor: NSColor(white: 0.03, alpha: 1)) : Color(nsColor: NSColor(white: 0.9, alpha: 1))
                case .crisp:
                    s.edge = ColorTokens.Workspace.cardEdge; s.edgeWidth = 1; s.topHighlight = nil; s.outerLine = nil
                    s.shadowOpacity = 0; s.ambientShadowOpacity = 0
                }
            }
            return s
        }
    }

    static let spec = RoundSpec(
        controls: [
            .of("canvas", "Canvas", Canvas.self, default: .darker,
                question: "Look at the whole Proposal window. How dark should the canvas behind the cards be?",
                recommend: .cool,
                why: "You did not like DC1 to DC3, so rev 2 tries a hue instead of only a level: DC4 is a graphite with a hint of blue, as Xcode's and Terminal's dark windows are, which separates canvas from the neutral cards without going black. DC6 is the gentlest step if you want the cards only a little lifted. Moving the canvas, not the cards, keeps the editor's Midnight background (30) equal to its card.",
                newChoices: (2, [.cool, .warm, .close, .underPage, .accent])),
            .of("card", "Cards", Card.self, default: .today,
                question: "Compare the cards at 30 and at about 38.",
                recommend: .today,
                why: "You picked DD0. Lighter cards would no longer match the Midnight editor, so the editor would sit as a dark slab inside a lighter card."),
            .of("edge", "Edge", Edge.self, default: .lit,
                question: "Look at the cards' edges in the dark and in the light Proposal. Which edge reads as a card in dark and still looks like today in light?",
                recommend: .quiet,
                why: "You like light mode as it is, so the best edge is the one that changes light least: DE5 is only 7% of the text colour, so in light it is almost today's grey, and in dark it adds the lit top that separates the card. DE4 is the strongest in dark, but its outer line is a visible change in light.",
                newChoices: (2, [.stronger, .outer, .quiet])),
            .of("shadow", "Shadow", Shadow.self, default: .deep,
                question: "Compare the shadows under the cards in the dark and the light Proposal.",
                recommend: .contact,
                why: "A shadow has to be dark on a dark canvas to show at all, and each option is drawn with a lighter version in light mode, so you can judge both. DS5 pairs a small contact shadow, which grounds the card, with a wide ambient one, which is how macOS lifts its own windows; in light it stays close to today's.",
                newChoices: (2, [.tight, .wide, .none, .contact])),
            .of("contrast", "Increase Contrast", Contrast.self, default: .edge,
                question: "Look at the Increase Contrast exhibits, dark and light. What should change when the setting is on?",
                recommend: .edge,
                why: "A solid 1pt edge is what the system does for its own panels with Increase Contrast and changes nothing else. IC3 also moves the canvas, which is a bigger change than the setting asks for; IC4 trades the soft shadow for a crisp edge, which is a good second.",
                newChoices: (2, [.heavy, .split, .crisp])),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Canvas about 28, cards 30, a grey 0.5pt edge.",
                  isEchoToday: true, isWide: true, designWidth: 760, designHeight: 440) { _ in
                LabPDWindow(look: .today, dark: true, increaseContrast: false)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls.",
                  isWide: true, designWidth: 760, designHeight: 440) { values in
                LabPDWindow(look: Look.from(values), dark: true, increaseContrast: false)
            },
            .init(id: "proposalContrast", title: "Proposal, Increase Contrast on", summary: "The Proposal with the Increase Contrast choice added.",
                  isWide: true, addedIn: 2, designWidth: 760, designHeight: 440) { values in
                LabPDWindow(look: Look.from(values), dark: true, increaseContrast: true)
            },
            .init(id: "lightToday", title: "Light mode today", summary: "How light mode looks now, to compare against.",
                  isWide: true, addedIn: 2, designWidth: 760, designHeight: 440) { _ in
                LabPDWindow(look: .today, dark: false, increaseContrast: false)
            },
            .init(id: "lightProposal", title: "Proposal in light mode", summary: "The same edge and shadow choices on light mode's canvas and cards (canvas and cards stay as today).",
                  isWide: true, addedIn: 2, designWidth: 760, designHeight: 440) { values in
                LabPDWindow(look: Look.from(values), dark: false, increaseContrast: false)
            },
            .init(id: "lightContrast", title: "Light mode, Increase Contrast on", summary: "The Increase Contrast choice in light mode.",
                  isWide: true, addedIn: 2, designWidth: 760, designHeight: 440) { values in
                LabPDWindow(look: Look.from(values), dark: false, increaseContrast: true)
            },
        ],
        questions: [],
        exhibitTopic: ("Which dark window?", "Is the Proposal easier to read than Echo today in dark mode, and does the light Proposal still look like light mode today?", "proposal",
                       "A graphite canvas, cards unchanged, a quiet lit edge and a contact shadow."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Cool graphite canvas, today's cards, quiet lit edge, contact shadow.",
                  values: ["canvas": Canvas.cool.rawValue, "card": Card.today.rawValue, "edge": Edge.quiet.rawValue, "shadow": Shadow.contact.rawValue, "contrast": Contrast.edge.rawValue],
                  isRecommended: true),
            .init(id: "edgeOnly", name: "Edges only", summary: "Today's colours with a quiet lit edge and a contact shadow.",
                  values: ["canvas": Canvas.today.rawValue, "card": Card.today.rawValue, "edge": Edge.quiet.rawValue, "shadow": Shadow.contact.rawValue]),
            .init(id: "close", name: "Gentle step", summary: "Canvas just under the cards, a stronger 1pt edge, a tight shadow.",
                  values: ["canvas": Canvas.close.rawValue, "edge": Edge.stronger.rawValue, "shadow": Shadow.tight.rawValue]),
        ]
    )
}

private struct LabPDWindow: View {
    let look: PanelFillsDarkRound.Look
    let dark: Bool
    let increaseContrast: Bool

    var body: some View {
        let surfaces = look.surfaces(dark: dark, increaseContrast: increaseContrast)
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
        .environment(\.colorScheme, dark ? .dark : .light)
    }
}
