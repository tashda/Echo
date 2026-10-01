import SwiftUI

/// Round 30.1 · Server card: the header. The owner finds the header (TREE-2.1 name, TREE-2.2
/// product line) too quiet and asked for headers with more presence, in the server's colour, the
/// accent colour or a custom colour. Echo today: bold 13pt name, grey 11pt product line and the
/// dock's section ("SQL Server 2017 · Agent Jobs"), nothing else (ObjectBrowserRowView+Headers).
/// The connection's colour exists today but only the rail's selected monogram uses it.
///
/// Rev 2 (the owner's notes): only HD0, HD4, HD5 (a better line), HD7 and HD8 stay, with variations
/// on each; plain (HD0), the header's colour and the dock icon's colour become settings.
///
/// Accepted 2026-10-01: HD4 by default, with HD0, HD12, HD7 and HD16 to choose in Settings ›
/// Appearance › Server Header; CS1 by default with None and Accent in Server Header Color; SL0;
/// DK1 as Current Dock Icon; HS0 as that menu; CO2; SC1. Built into Echo as TREE-2.6.
@MainActor
enum ServerHeaderLookRound {
    private static let cardWidth = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.lg
    private static let columnWidth = cardWidth + SpacingTokens.lg

    static let spec = RoundSpec(
        controls: [
            .of("style", "Header", LabSHStyle.self, default: .wash,
                question: "Try the headers in the Proposal and compare them in Every header, then look at Three servers. Which one should Echo draw when the header is coloured?",
                recommend: .glow,
                why: "A close call with HD4, which you picked: HD10 keeps its soft colour but puts it behind the name, where you look, so the dock and the first rows stay on the plain card and a red production server reads as marked, not as an alarm. HD9 and the banners colour more of the card than you want to look at all day; the lines are calm but carry little colour; the plates put glass on the card, which the window rules keep for controls.",
                summary: \.summary,
                newChoices: (2, [.cap, .glow, .fadingLine, .bar, .onePlate, .pill, .insetBanner, .fadingBanner])),
            .of("source", "Colour", LabSHColourSource.self, default: .server,
                question: "This becomes a setting (Settings › Appearance › Server Header › Colour: None, Server's Colour, Accent Colour). Switch it in the Settings exhibit. Which should a new install start with?",
                recommend: .server,
                why: "You picked CS1: only the server's colour tells servers apart, which is why the header has colour at all. The accent is the same on every server; None is there for anyone who wants it. The custom colour (CS3) is gone because SC1 already sets the server's own colour from the header's menu.",
                summary: \.summary),
            .of("secondLine", "Second line", LabSHSecondLine.self, default: .productSection,
                question: "Look at the line under the name. What should it say?",
                recommend: .productSection,
                why: "You decided in round 19 that it names the dock's current section; the product stays because two servers of different versions often share a name prefix. Login and host belong in the inspector and the tooltip."),
            .of("dockTint", "Dock icon", LabSHDockTint.self, default: .header,
                question: "This becomes a setting beside Section Dock Icons (Mono / Duotone): Current Dock Icon. Switch it in the Settings exhibit. Which should it start with?",
                recommend: .header,
                why: "You picked DK1: the current section in the server's colour ties the dock to its header. With the header's colour set to None it falls back to the accent, so the current icon is never grey."),
            .of("sample", "Server", LabSHSample.self, default: .production),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "Bold 13pt name, the product and section in grey, the dock. The connection's colour is not used.",
                  isEchoToday: true, designWidth: columnWidth, designHeight: 400) { values in
                LabSHColumn { LabSHCard(server: sample(values), look: .today) }
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Hover the header for the chevron.",
                  designWidth: columnWidth, designHeight: 400) { values in
                LabSHColumn { LabSHCard(server: sample(values), look: LabSHLook(values)) }
            },
            .init(id: "three", title: "Three servers", summary: "Production, test and a PostgreSQL server in one column, each in its own colour.",
                  designWidth: columnWidth, designHeight: 560) { values in
                LabSHColumn {
                    LabSHCard(server: .production, look: LabSHLook(values), rowLimit: 3)
                    LabSHCard(server: .test, look: LabSHLook(values), rowLimit: 2, selectedRow: nil)
                    LabSHCard(server: .development, look: LabSHLook(values), rowLimit: 2, selectedRow: nil)
                }
            },
            .init(id: "gallery", title: "Every header",
                  summary: "All thirteen headers in the chosen colour, a row per family: plain, wash, line, plate, banner. Scroll for more.",
                  designWidth: 700, designHeight: 600) { values in
                LabSHGallery(values: values)
            },
            .init(id: "settings", title: "Settings",
                  summary: "Settings › Appearance with the three new rows. Colour and Current Dock Icon change the round's controls; Style switches the card below to Plain.",
                  addedIn: 2, designWidth: 460, designHeight: 600) { values in
                LabSHSettings(values: values)
            },
        ],
        questions: [
            .init(id: "plainSetting", title: "Plain header as a setting",
                  question: "You asked that HD0 can be chosen by the user. How should Settings offer it? Try Style in the Settings exhibit.",
                  choices: [
                      .init(id: "pair", name: "HS0 · Server Header: Plain or Coloured (the header chosen here)"),
                      .init(id: "all", name: "HS1 · A menu with every header from this round"),
                      .init(id: "colourNone", name: "HS2 · No style setting: Colour None draws the plain header"),
                  ],
                  recommended: "pair",
                  why: "Two headers are two looks to get right in light, dark, Increase Contrast and every corner size; a menu of thirteen is thirteen. HS2 is tidier but ties two things together: you may want the plain header and still the colour on the dock, the rail and the tabs.",
                  addedIn: 2),
            .init(id: "colourShared", title: "One colour per server",
                  question: "Once the header has the server's colour, where else should that colour appear?",
                  choices: [
                      .init(id: "header", name: "CO0 · The header only"),
                      .init(id: "rail", name: "CO1 · The header and the rail's monogram (always, not only when selected)"),
                      .init(id: "tabs", name: "CO2 · CO1, and a dot on the server's tabs and the footer's server pill"),
                  ],
                  recommended: "tabs",
                  why: "The point of a production colour is that you can't run a query on the wrong server: the tab and the footer pill are where you are when you press Run. The rail and header alone don't follow you into the editor."),
            .init(id: "colourSet", title: "Setting the colour",
                  question: "Where do you set a server's colour?",
                  choices: [
                      .init(id: "sheet", name: "SC0 · In the connection sheet only (today)"),
                      .init(id: "menu", name: "SC1 · Also from the header's right-click menu, with the swatches"),
                  ],
                  recommended: "menu",
                  why: "The header is where you notice that a colour is wrong or missing; a Colour submenu there saves a trip to Manage Connections and writes the same connection colour."),
        ],
        exhibitTopic: ("Which header?", "Judged against Echo today, is the Proposal the header to build?", "proposal",
                       "A soft glow of the server's colour behind the name gives the card presence and tells production from test at a glance, while the dock and rows stay calm."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "A glow of the server's colour from the corner, the dock in the same colour.",
                  values: ["style": LabSHStyle.glow.rawValue, "source": LabSHColourSource.server.rawValue,
                           "secondLine": LabSHSecondLine.productSection.rawValue, "dockTint": LabSHDockTint.header.rawValue],
                  isRecommended: true),
            .init(id: "wash", name: "Your pick", summary: "HD4's wash in the server's colour, the dock in the same colour.",
                  values: ["style": LabSHStyle.wash.rawValue, "source": LabSHColourSource.server.rawValue, "dockTint": LabSHDockTint.header.rawValue]),
            .init(id: "line", name: "Quiet line", summary: "Today's header with the redrawn line along the top.",
                  values: ["style": LabSHStyle.edge.rawValue, "source": LabSHColourSource.server.rawValue]),
            .init(id: "inset", name: "Inset banner", summary: "The banner as a panel inside the card, concentric corners.",
                  values: ["style": LabSHStyle.insetBanner.rawValue, "source": LabSHColourSource.server.rawValue, "dockTint": LabSHDockTint.header.rawValue]),
        ]
    )

    private static func sample(_ values: RoundValues) -> LabSHServer {
        (LabSHSample(rawValue: values["sample"]) ?? .production).server
    }
}

/// Every header on the same server: a row per family, three to a row.
private struct LabSHGallery: View {
    let values: RoundValues

    var body: some View {
        let base = LabSHLook(values)
        let server = (LabSHSample(rawValue: values["sample"]) ?? .production).server
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                ForEach(LabSHFamily.allCases, id: \.self) { family in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        Text(family.rawValue).font(TypographyTokens.standard.weight(.semibold)).foregroundStyle(ColorTokens.Text.primary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sm, alignment: .top), count: 3),
                                  alignment: .leading, spacing: SpacingTokens.sm) {
                            ForEach(family.styles, id: \.self) { style in
                                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                                    Text(style.number)
                                        .font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                                    LabSHCard(server: server, look: base.with(style), rowLimit: 1)
                                }
                            }
                        }
                    }
                }
            }
            .padding(SpacingTokens.sm)
        }
        .labScrollSizing()
        .background(ColorTokens.Workspace.canvas)
    }
}
