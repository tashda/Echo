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
            .of("form", "Header", LabHRForm.self, default: .slim,
                question: "Click the icon menu's icons in the Proposal, then see all eight in Every header. Which one should the server card have?",
                recommend: .slim,
                why: "The banner is your favourite because it is the one header that says which server you are on without reading; F4 keeps that and removes what makes it heavy: the second line, and the 20pt of colour under it. It becomes a label for the card, the colour carries on behind the icon menu, and the right side tells you the section. F3 is the one to ship if you would rather change nothing about the banner itself.",
                summary: \.summary),
            .of("dock", "Icon menu", LabHRDock.self, default: .pill,
                question: "Click through the icons with each treatment on the Proposal, then see all six in Every icon menu and Every icon menu, plain card. How should the icon menu sit?",
                recommend: .pill,
                why: "The frosted strip is the problem on a banner: glass has nothing to blur but a flat colour, so it goes white. With no capsule the icons sit straight on the colour and the selected one is a white pill that slides between them, which is the one idea that works on a banner and on a plain card (there the pill is the server's colour at 18%). D4 is the close second if you want the menu to feel like a control.",
                summary: \.summary),
            .of("right", "Right side", LabHRRight.self, default: .section,
                question: "Click through the sections and watch the header's right side. What should it show?",
                recommend: .section,
                why: "The icon menu has no labels, and the selected icon is the only thing that says where you are; the name of the section answers that in words and costs one short word. The icon beside it (RT2, RT3) repeats the menu a few points below.",
                summary: \.summary),
            .of("reach", "Colour reaches", LabHRReach.self, default: .dock,
                question: "Compare the colour stopping under the name with carrying on behind the icon menu.",
                recommend: .dock,
                why: "One surface for the header and the menu is what ties the section name on the right to the icon below it. It is also what the banner does in Echo today, so RC1 changes nothing; RC0 leaves the menu on the card, where the pill works but the glass has nothing behind it.",
                summary: \.summary),
            .of("eyebrow", "Eyebrow", LabHREyebrow.self, default: .engine,
                question: "Choose a large-name form (F5, F7 or F8), then compare the lines over the name. What should it say?",
                recommend: .engine,
                why: "You doubted that anyone cares about the version; the engine does not change and tells a PostgreSQL server from a SQL Server one at a glance, which the colour does not. The section (EY1) is the most useful but would then also be on the right in RT1, so pick one. The version stays one tooltip away.",
                summary: \.summary),
            .of("tone", "Colour", LabHRTone.self, default: .echo,
                question: "Compare the banner's colour as Echo draws it with the same colour darkened.",
                recommend: .echo,
                why: "You chose R4 as it is; the darker colour is for you to see how much of the generated look is saturation. If white type or the pill feel weak on red or yellow, CL1 is the fix.",
                summary: \.summary),
            .of("sample", "Server", LabSHSample.self, default: .production),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "The wash header with the glass icon menu (Echo's default). Click an icon.",
                  isEchoToday: true, designWidth: width, designHeight: 400) { values in
                LabHRColumn { LabHRCard(server: sample(values), look: .today) }
            },
            .init(id: "proposal", title: "Proposal",
                  summary: "Built from the controls. Click the icons: the right side and the eyebrow follow. Hover the header for the chevron.",
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
            .init(id: "forms", title: "Every header",
                  summary: "All eight forms with the chosen icon menu, right side and eyebrow. Scroll for more.",
                  designWidth: 700, designHeight: 620) { values in
                LabHRFormGallery(look: LabHRLook(values), server: sample(values))
            },
            .init(id: "docks", title: "Every icon menu",
                  summary: "The chosen header with each of the six treatments. Click the icons.",
                  designWidth: 700, designHeight: 620) { values in
                LabHRDockGallery(look: LabHRLook(values), server: sample(values))
            },
            .init(id: "docksPlain", title: "Every icon menu, plain card",
                  summary: "The six treatments on the plain card (F1), where there is no colour for the menu to sit on.",
                  designWidth: 700, designHeight: 620) { values in
                LabHRDockGallery(look: LabHRLook(values).with(form: .plain), server: sample(values))
            },
        ],
        questions: [
            .init(id: "plainCard", title: "On a plain card",
                  question: "If the header stays plain (F1), how should the icon menu look? Open Every icon menu, plain card.",
                  choices: [
                      .init(id: "pill", name: "D3 · The selected icon in a pill of the server's colour", summary: nil),
                      .init(id: "recessed", name: "D4 · A recessed capsule with a raised disc, as the trail's selection", summary: nil),
                      .init(id: "tinted", name: "D1 · Glass with a hint of the server's colour", summary: nil),
                      .init(id: "glass", name: "D0 · Today's glass", summary: nil),
                  ],
                  recommended: "recessed",
                  why: "On the plain card the capsule is what makes it look pasted on, because glass over a white card is white over white. A recess takes its colour from the card and the raised disc is the same disc the trail uses to say \"selected\", so the menu and the trail share one idea."),
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Slim banner, the section on the right, colour through the icon menu, the selected icon in a white pill.",
                  values: ["form": LabHRForm.slim.rawValue, "dock": LabHRDock.pill.rawValue, "right": LabHRRight.section.rawValue,
                           "reach": LabHRReach.dock.rawValue, "eyebrow": LabHREyebrow.engine.rawValue, "tone": LabHRTone.echo.rawValue],
                  isRecommended: true),
            .init(id: "r4", name: "Your banner, a calmer menu", summary: "R4 as it is, with the icon menu in a recess.",
                  values: ["form": LabHRForm.banner.rawValue, "dock": LabHRDock.recessed.rawValue, "right": LabHRRight.none.rawValue,
                           "reach": LabHRReach.dock.rawValue, "tone": LabHRTone.echo.rawValue]),
            .init(id: "title", name: "Large name", summary: "HQ10 on the banner, eyebrow without the version, an underline menu.",
                  values: ["form": LabHRForm.bannerTitle.rawValue, "dock": LabHRDock.underline.rawValue, "right": LabHRRight.none.rawValue,
                           "reach": LabHRReach.dock.rawValue, "eyebrow": LabHREyebrow.engine.rawValue, "tone": LabHRTone.echo.rawValue]),
            .init(id: "plain", name: "Plain, recessed menu", summary: "No colour surface; the menu is a recess with a raised disc.",
                  values: ["form": LabHRForm.plainTitle.rawValue, "dock": LabHRDock.recessed.rawValue, "right": LabHRRight.none.rawValue,
                           "reach": LabHRReach.header.rawValue, "eyebrow": LabHREyebrow.engine.rawValue]),
        ]
    )

    private static func sample(_ values: RoundValues) -> LabSHServer {
        (LabSHSample(rawValue: values["sample"]) ?? .production).server
    }
}
