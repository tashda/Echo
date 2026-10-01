import SwiftUI

/// Round 30.1 · Server card: the header. The owner finds the header (TREE-2.1 name, TREE-2.2
/// product line) too quiet and asked for headers with more presence, in the server's colour, the
/// accent colour or a custom colour. Echo today: bold 13pt name, grey 11pt product line and the
/// dock's section ("SQL Server 2017 · Agent Jobs"), nothing else (ObjectBrowserRowView+Headers).
/// The connection's colour exists today but only the rail's selected monogram uses it.
@MainActor
enum ServerHeaderLookRound {
    private static let cardWidth = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.lg
    private static let columnWidth = cardWidth + SpacingTokens.lg

    static let spec = RoundSpec(
        controls: [
            .of("style", "Header", LabSHStyle.self, default: .monogram,
                question: "Try each header in the Proposal, then look at Three servers. Which one gives the card presence without shouting over the rows?",
                recommend: .monogram,
                why: "The monogram is already how the rail names a server, so the card and the rail finally read as the same thing, and a 30pt tile gives the header weight without making the name bigger. HD4 and HD8 colour the whole top, which turns a red production server into an alarm on every glance; HD5 is easy to miss; HD7 puts glass on the card, which the window rules keep for controls.",
                summary: \.summary),
            .of("source", "Colour", LabSHColourSource.self, default: .server,
                question: "Switch the colour with HD2 and HD4 set. Where should the header's colour come from?",
                recommend: .server,
                why: "A colour only helps if it tells servers apart, and the connection's colour already exists for that (it is the rail's selected monogram). The accent colour is the same on every server, so it decorates but says nothing; a separate custom colour per header would be a second colour to keep in step with the connection's.",
                summary: \.summary),
            .of("secondLine", "Second line", LabSHSecondLine.self, default: .productSection,
                question: "Look at the line under the name. What should it say?",
                recommend: .productSection,
                why: "You decided in round 19 that it names the dock's current section; the product stays because two servers of different versions often share a name prefix. Login and host belong in the inspector and the tooltip."),
            .of("dockTint", "Dock icon", LabSHDockTint.self, default: .accent,
                question: "With a colour set, compare the dock's current icon in accent and in the header's colour.",
                recommend: .accent,
                why: "The accent marks what is selected everywhere in Echo (tabs, rows, the dock); in a red header the red current icon would read as an error."),
            .of("custom", "Custom colour", LabSHCustomColour.self, default: .purple),
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
            .init(id: "gallery", title: "Every header", summary: "All nine headers in the chosen colour, side by side.",
                  designWidth: 700, designHeight: 470) { values in
                LabSHGallery(values: values)
            },
        ],
        questions: [
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
                       "It gives every card the rail's monogram in the server's own colour, so the card has weight and you can tell production from test at a glance."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "The rail's monogram in the server's colour, accent dock.",
                  values: ["style": LabSHStyle.monogram.rawValue, "source": LabSHColourSource.server.rawValue,
                           "secondLine": LabSHSecondLine.productSection.rawValue, "dockTint": LabSHDockTint.accent.rawValue],
                  isRecommended: true),
            .init(id: "loud", name: "Loud", summary: "A coloured banner with the dock in the same colour.",
                  values: ["style": LabSHStyle.banner.rawValue, "source": LabSHColourSource.server.rawValue, "dockTint": LabSHDockTint.header.rawValue]),
            .init(id: "quiet", name: "Quiet colour", summary: "Today's header with a line of colour on top.",
                  values: ["style": LabSHStyle.edge.rawValue, "source": LabSHColourSource.server.rawValue]),
            .init(id: "accent", name: "Accent wash", summary: "A wash of the accent colour on every server.",
                  values: ["style": LabSHStyle.wash.rawValue, "source": LabSHColourSource.accent.rawValue]),
        ]
    )

    private static func sample(_ values: RoundValues) -> LabSHServer {
        (LabSHSample(rawValue: values["sample"]) ?? .production).server
    }
}

/// Every header style on the same server, three to a row.
private struct LabSHGallery: View {
    let values: RoundValues

    var body: some View {
        let base = LabSHLook(values)
        let server = (LabSHSample(rawValue: values["sample"]) ?? .production).server
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sm), count: 3), spacing: SpacingTokens.sm) {
            ForEach(LabSHStyle.allCases, id: \.self) { style in
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text(style.rawValue.components(separatedBy: " · ").first ?? "")
                        .font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                    LabSHCard(server: server, look: base.with(style), rowLimit: 1)
                }
            }
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorTokens.Workspace.canvas)
    }
}
