import SwiftUI

/// Round 50 · Server card: a header that looks designed. The owner finds every round-30 header
/// "90% good" but still AI-made: not the idea but the finish (the font, the colours, where things
/// sit). This round varies the ingredients (HP designs, colour strength, typeface, second line,
/// how the dock sits) so the direction can be narrowed. Changes TREE-2.1, TREE-2.2 and TREE-2.6.
///
/// Why they read as generated: a saturated top-to-bottom gradient, white bold type at the same
/// 13pt as the rows, a glass capsule floating over the colour, and everything on one axis with
/// no typographic hierarchy. Each design here removes at least one of those.
@MainActor
enum ServerHeaderPolishRound {
    private static let width = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xl

    static let spec = RoundSpec(
        controls: [
            .of("design", "Header", LabHPDesign.self, default: .ink,
                question: "Step through the headers in the Proposal, then compare them all in Every header. Which one looks designed rather than generated?",
                recommend: .ink,
                why: "A close call with HP5 Tile. Ink keeps the presence you asked for in round 30, but as a flat, darkened surface: no gradient, no glow, no capsule on top, so it reads as a title bar and the colour is a material, not an effect. Tile is the quietest and the most native, but at 32pt the colour is too small to spot a red production server at a glance. The soft and glass ones (HP0, HP7, HP8) are what you already have at 90%.",
                summary: \.summary),
            .of("strength", "Colour", LabHPStrength.self, default: .standard,
                question: "Switch between Muted, Standard and Vivid on the Proposal and on Three servers. How much colour should a header carry?",
                recommend: .standard,
                why: "Saturation is most of the generated look: round 30's banners are Vivid, the user's own colour at full strength. Standard darkens it so white type holds contrast and two red and green cards side by side don't glare. Muted is what to ship if you would rather the colour only whispers.",
                summary: \.summary),
            .of("face", "Name", LabHPFace.self, default: .semibold,
                question: "Try each typeface on the chosen header, then see them together in Typefaces. Which sets the server's name best?",
                recommend: .semibold,
                why: "Bold 13pt is the same size and nearly the same weight as the rows under it, which is why the header doesn't hold. Semibold 14 adds hierarchy without changing the family, so the card still belongs to the sidebar. Mono is the one with character (names are identifiers) but turns every card into a code block; New York is the boldest change and I would not ship it in a database client.",
                summary: \.summary),
            .of("line", "Second line", LabHPLine.self, default: .today,
                question: "Compare the lines under the name. What should they say, and how?",
                recommend: .today,
                why: "You decided in round 19 that it names the product and the dock's current section. Small caps (SL1) is the sharpest alternative, but they drop the section, which is the only place the card says where you are; the dock only shows an icon.",
                summary: \.summary),
            .of("dock", "Dock", LabHPDock.self, default: .below,
                question: "Compare how the dock sits against the colour. Where should it go?",
                recommend: .below,
                why: "In your screenshot the glass dock floats half on the colour and half on the card, which is the most generated-looking part of today's card: it blurs a gradient into a smear. Below the header it sits on the card as it does without colour, and each part has one background.",
                summary: \.summary),
            .of("sample", "Server", LabSHSample.self, default: .production),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "The wash header Echo ships as the default, with the same server.",
                  isEchoToday: true, designWidth: width, designHeight: 400) { values in
                LabHPColumn {
                    LabSHCard(server: sample(values), look: LabSHLook(style: .wash, source: .server, secondLine: .productSection, dockTint: .header))
                }
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Hover the header for the chevron.",
                  designWidth: width, designHeight: 400) { values in
                LabHPColumn { LabHPCard(server: sample(values), look: LabHPLook(values)) }
            },
            .init(id: "three", title: "Three servers",
                  summary: "Production, test and a PostgreSQL server in one column: does each still read as its own at a glance?",
                  designWidth: width, designHeight: 560) { values in
                LabHPColumn {
                    LabHPCard(server: .production, look: LabHPLook(values), rowLimit: 3)
                    LabHPCard(server: .test, look: LabHPLook(values), rowLimit: 2, selectedRow: nil)
                    LabHPCard(server: .development, look: LabHPLook(values), rowLimit: 2, selectedRow: nil)
                }
            },
            .init(id: "gallery", title: "Every header",
                  summary: "All thirteen on the chosen server, grouped by how the colour is made. Scroll for more.",
                  designWidth: 700, designHeight: 620) { values in
                LabHPGallery(look: LabHPLook(values), server: sample(values))
            },
            .init(id: "typefaces", title: "Typefaces",
                  summary: "The chosen header in each typeface.",
                  designWidth: width, designHeight: 620) { values in
                LabHPTypefaces(look: LabHPLook(values), server: sample(values))
            },
        ],
        questions: [
            .init(id: "family", title: "Direction",
                  question: "Before the details: which way should the server card go?",
                  choices: [
                      .init(id: "fill", name: "A · A solid, calm fill (Ink, Enamel, Duotone)", summary: nil),
                      .init(id: "type", name: "B · No fill: the type carries the colour (Eyebrow, Badge, Numeral, Chips)", summary: nil),
                      .init(id: "object", name: "C · A small object: a tile, an edge or a glass panel", summary: nil),
                      .init(id: "soft", name: "D · What we have, finished (Wash or Aurora, better type)", summary: nil),
                  ],
                  recommended: "fill",
                  why: "You asked in round 30 for presence and said every header was nearly there; a solid fill is the one family that keeps presence, and Ink or Enamel is that with the generated finish removed. If the first answer is that it still feels heavy, B and C are the quieter, more editorial answers."),
            .init(id: "extras", title: "Information in the header",
                  question: "Chips (HP12) and Badge (HP9) show more than a grey line does. Should the header carry anything beyond name and product?",
                  choices: [
                      .init(id: "none", name: "No: name and product line only", summary: nil),
                      .init(id: "status", name: "Yes: a status dot and the latency", summary: nil),
                      .init(id: "env", name: "Yes: an environment label the user sets (PROD, TEST, DEV)", summary: nil),
                  ],
                  recommended: "none",
                  why: "The rail and tabs already say connecting and lost; latency changes every second and would make the header the busiest part of the card. An environment label is the best idea here, but it needs a new field on the connection, so it is its own round if you want it."),
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Ink, standard colour, semibold 14, dock below.",
                  values: ["design": LabHPDesign.ink.rawValue, "strength": LabHPStrength.standard.rawValue, "face": LabHPFace.semibold.rawValue,
                           "line": LabHPLine.today.rawValue, "dock": LabHPDock.below.rawValue],
                  isRecommended: true),
            .init(id: "quiet", name: "Quiet", summary: "Tile, muted, semibold, tinted dock.",
                  values: ["design": LabHPDesign.tile.rawValue, "strength": LabHPStrength.muted.rawValue, "face": LabHPFace.semibold.rawValue,
                           "line": LabHPLine.today.rawValue, "dock": LabHPDock.below.rawValue]),
            .init(id: "editorial", name: "Editorial", summary: "Eyebrow with small caps and a serif name.",
                  values: ["design": LabHPDesign.eyebrow.rawValue, "strength": LabHPStrength.standard.rawValue, "face": LabHPFace.serif.rawValue,
                           "line": LabHPLine.none.rawValue, "dock": LabHPDock.below.rawValue]),
            .init(id: "lit", name: "Lit", summary: "Enamel, vivid, rounded, dock over the colour.",
                  values: ["design": LabHPDesign.enamel.rawValue, "strength": LabHPStrength.vivid.rawValue, "face": LabHPFace.rounded.rawValue,
                           "line": LabHPLine.today.rawValue, "dock": LabHPDock.over.rawValue]),
            .init(id: "code", name: "Code", summary: "Slab with a monospaced name and the host under it.",
                  values: ["design": LabHPDesign.slab.rawValue, "strength": LabHPStrength.standard.rawValue, "face": LabHPFace.mono.rawValue,
                           "line": LabHPLine.host.rawValue, "dock": LabHPDock.below.rawValue]),
        ]
    )

    private static func sample(_ values: RoundValues) -> LabSHServer {
        (LabSHSample(rawValue: values["sample"]) ?? .production).server
    }
}
