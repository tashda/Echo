import SwiftUI

/// Round 50 · Server card: a header that looks designed. Revision 3 is a clean start.
///
/// The owner tried 45 options in revisions 1 and 2 and kept none; their favourite is still Echo's
/// banner (R4). They asked to explore (1) the icon menu on a coloured surface, or on a plain
/// card without it looking like a white strip pasted on top; (2) HQ10's large name with an eyebrow
/// that is not the database version; (3) HQ30's slim banner with the selected section on the
/// right instead of the latency, reaching down behind the icon menu. Changes TREE-2.1, TREE-2.2,
/// TREE-2.6 and the section dock (TREE-3).
@MainActor
enum ServerHeaderPolishRound {
    private static let width = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xl

    static let spec = RoundSpec(
        controls: [
            .of("form", "Header", LabHRForm.self, default: .bannerTitle,
                question: "F5 is your pick. Compare it once more in Every header: should it stay F5?",
                recommend: .bannerTitle,
                why: "You picked F5 and said you love it. The other forms stay so you can still switch: F4 (slim banner) is the one to ship if the large name feels too tall next to the rows.",
                summary: \.summary),
            .of("dock", "Icon menu", LabHRDock.self, default: .pill,
                question: "You picked D3 but its pill did not show (my bug, fixed). Click the icons in the Proposal: does the pill read now?",
                recommend: .pill,
                why: "On the colour a white pill is the strongest cue there is. D4 (a recess with a raised disc) is the runner-up if you want the menu to look like a control.",
                summary: \.summary),
            .of("icon", "Selected icon", LabHRIcon.self, default: .filled15,
                question: "Click through the icons with each weight and size. How heavy should the selected icon be?",
                recommend: .filled15,
                why: "The filled symbol at 15pt bold is the heaviest change that keeps all five icons the same family; a heavy 16 starts to look like a different set, and a half-strength row (IC5) makes the menu hard to read when nothing is selected.",
                summary: \.summary),
            .of("pill", "Pill", LabHRPill.self, default: .compact,
                question: "Click through the icons with each pill. What should sit behind the selected icon?",
                recommend: .compact,
                why: "A compact capsule leaves clear colour on both sides, so it reads as an object rather than a bar. The wide one touches its neighbours; the disc echoes the trail's selection but is narrower than the icons' spacing; the raised, outline and glass ones are the three to look at in dark mode.",
                summary: \.summary),
            .of("name", "Name", LabHRName.self, default: .bold20,
                question: "Compare the large name in every typeface in Typefaces, then in the Proposal. Which typeface and size?",
                recommend: .semibold22,
                why: "The name is the one thing the card has to say. A lighter weight at 22pt reads as a title rather than a label next to the 13pt rows; New York and Mono have character but are the two that would not suit every server name (dkloosql10-p in serif looks like a poem).",
                summary: { $0.rawValue }),
            .of("eyebrowStyle", "Eyebrow", LabHREyebrowStyle.self, default: .standard,
                question: "Compare the eyebrows in Typefaces. How should the line over the name be set?",
                recommend: .bold,
                why: "At 10pt semibold the eyebrow disappears into the colour; 11pt bold with wider tracking holds on every colour in the palette, including yellow and amber, without competing with the name.",
                summary: { $0.rawValue }),
            .of("edge", "Banner edge", LabHREdge.self, default: .hairline,
                question: "See all nine in Edges, then in the Proposal over the rows. How should the banner end against the card?",
                recommend: .hairline,
                why: "You like both the soft fade and the sharp edge: a sharp edge with a hairline of light keeps the sharpness and fixes what makes it harsh, the colour ending against white with nothing between. It is also the one that holds in dark mode, where a shadow (ED5) can't be seen and a fade turns muddy. ED4 is the most refined fade if you want it soft.",
                summary: \.summary),
            .of("colour", "Colour", LabHRColour.self, default: .sample),
            .of("sample", "Server", LabSHSample.self, default: .production),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "The wash header with the glass icon menu (Echo's default). Click an icon.",
                  isEchoToday: true, designWidth: width, designHeight: 400) { values in
                LabHRColumn { LabHRCard(server: sample(values), look: .today) }
            },
            .init(id: "proposal", title: "Proposal",
                  summary: "Built from the controls. Click the icons: the eyebrow follows. Hover the header for the chevron.",
                  designWidth: width, designHeight: 400) { values in
                LabHRColumn { LabHRCard(server: sample(values), look: LabHRLook(values)) }
            },
            .init(id: "three", title: "Three servers",
                  summary: "Production, test and a PostgreSQL server in one column.",
                  designWidth: width, designHeight: 560) { values in
                LabHRColumn {
                    LabHRCard(server: .production, look: LabHRLook(values), rowLimit: 3)
                    LabHRCard(server: .test, look: LabHRLook(values), rowLimit: 2, selectedRow: nil)
                    LabHRCard(server: .development, look: LabHRLook(values), rowLimit: 2, selectedRow: nil)
                }
            },
            .init(id: "edges", title: "Edges", summary: "The nine ways the banner can end, with the rest of the proposal. Scroll for more.",
                  addedIn: 4, designWidth: 700, designHeight: 620) { values in
                let look = LabHRLook(values)
                LabHRVariantGallery(variants: LabHREdge.allCases.map { edge in
                    var copy = look; copy.edge = edge; return (edge.rawValue, copy)
                }, server: sample(values))
            },
            .init(id: "typefaces", title: "Typefaces",
                  summary: "Left: the ten names with the chosen eyebrow. Scroll down: the six eyebrows with the chosen name.",
                  addedIn: 4, designWidth: 700, designHeight: 620) { values in
                let look = LabHRLook(values)
                LabHRVariantGallery(variants: LabHRName.allCases.map { name in
                    var copy = look; copy.name = name; return (name.rawValue, copy)
                } + LabHREyebrowStyle.allCases.map { style in
                    var copy = look; copy.eyebrowStyle = style; return (style.rawValue, copy)
                }, server: sample(values))
            },
            .init(id: "icons", title: "Selected icon",
                  summary: "The six weights and sizes, then the seven pills, each on the chosen icon menu.",
                  addedIn: 4, designWidth: 700, designHeight: 620) { values in
                let look = LabHRLook(values)
                LabHRVariantGallery(variants: LabHRIcon.allCases.map { icon in
                    var copy = look; copy.icon = icon; return (icon.rawValue, copy)
                } + LabHRPill.allCases.map { pill in
                    var copy = look; copy.pill = pill; return (pill.rawValue, copy)
                }, server: sample(values))
            },
            .init(id: "colours", title: "Colours",
                  summary: "The 30 colours on the chosen header, in the lab's appearance. Switch light and dark in the toolbar.",
                  addedIn: 4, designWidth: 700, designHeight: 620) { values in
                LabHRColourGallery(look: LabHRLook(values), server: sample(values))
            },
            .init(id: "pairs", title: "Light and dark",
                  summary: "Every colour in light (left) and dark (right) at once.",
                  addedIn: 4, designWidth: 700, designHeight: 620) { values in
                LabHRColourPairs(look: LabHRLook(values), server: sample(values))
            },
            .init(id: "forms", title: "Every header",
                  summary: "All eight forms with the chosen settings. Scroll for more.",
                  designWidth: 700, designHeight: 620) { values in
                LabHRFormGallery(look: LabHRLook(values), server: sample(values))
            },
            .init(id: "docks", title: "Every icon menu",
                  summary: "The chosen header with each of the six treatments. Click the icons.",
                  designWidth: 700, designHeight: 620) { values in
                LabHRDockGallery(look: LabHRLook(values), server: sample(values))
            },
        ],
        questions: [
            .init(id: "palette", title: "Colours to offer",
                  question: "Open Colours and Light and dark. Which set of colours should a server's colour picker offer?",
                  choices: [
                      .init(id: "system", name: "PC0 · The eight system colours (today)", summary: nil),
                      .init(id: "tuned", name: "PC1 · Sixteen colours tuned for light and dark", summary: nil),
                      .init(id: "full", name: "PC2 · All thirty here, each with a light and a dark version", summary: nil),
                      .init(id: "fullCustom", name: "PC3 · All thirty and a colour well for any colour", summary: nil),
                  ],
                  recommended: "fullCustom",
                  why: "The system colours are the same in every app and look flat as a full banner. Each colour here has its own light and dark version (darker and calmer in light, brighter in dark) so white type holds on all of them; a colour well on top is for the person with a brand colour. Sixteen is enough if thirty is too many to scan, and I would cut Gold, Sand, Moss and Steel first."),
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "F5, the selected icon in a compact white pill, a bold filled icon, a hairline edge.",
                  values: ["form": LabHRForm.bannerTitle.rawValue, "dock": LabHRDock.pill.rawValue, "icon": LabHRIcon.filled15.rawValue,
                           "pill": LabHRPill.compact.rawValue, "name": LabHRName.semibold22.rawValue, "eyebrowStyle": LabHREyebrowStyle.bold.rawValue,
                           "edge": LabHREdge.hairline.rawValue],
                  isRecommended: true),
            .init(id: "picked", name: "As you picked", summary: "F5, D3, as they were; for comparing.",
                  values: ["form": LabHRForm.bannerTitle.rawValue, "dock": LabHRDock.pill.rawValue, "icon": LabHRIcon.semibold14.rawValue,
                           "pill": LabHRPill.wide.rawValue, "name": LabHRName.bold20.rawValue, "eyebrowStyle": LabHREyebrowStyle.standard.rawValue,
                           "edge": LabHREdge.soft.rawValue]),
            .init(id: "soft", name: "Frosted", summary: "A frosted fade, raised pill.",
                  values: ["edge": LabHREdge.frosted.rawValue, "pill": LabHRPill.raised.rawValue, "icon": LabHRIcon.heavy16.rawValue]),
            .init(id: "panel", name: "A panel", summary: "Rounded bottom corners, a serif name.",
                  values: ["edge": LabHREdge.rounded.rawValue, "name": LabHRName.serif22.rawValue, "pill": LabHRPill.disc.rawValue]),
        ]
    )

    private static func sample(_ values: RoundValues) -> LabSHServer {
        (LabSHSample(rawValue: values["sample"]) ?? .production).server
    }
}
