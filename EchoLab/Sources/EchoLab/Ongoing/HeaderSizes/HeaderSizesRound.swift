import SwiftUI

/// Round 58 · Smaller card headers and what each setting does. Even with Server Name Size Small and
/// Banner with Title the cards feel too big, and Line Above the Name = None added a line under the
/// name. This round shows smaller names, tighter spacing and layouts with fewer lines, and writes
/// down what each setting does to the header's height (the table) with the drawing built from the
/// same numbers. Changes TREE-2.1 and Settings › Appearance › Server Header.
@MainActor
enum HeaderSizesRound {
    private static let width = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xl

    static let spec = RoundSpec(
        controls: [
            .of("layout", "Layout", LabHZLayout.self, default: .inline,
                question: "Compare the heights in Every size and Heights, then look at the Proposal. How many rows should the banner have?",
                recommend: .inline,
                why: "Three rows are what makes the card big: the line, the name and the menu each take one. One row (the name on the left, the five icons on the right) is 40pt at Tight against 92pt today and still has the name and the menu. The slim banner (LY3) is the one that keeps the menu large and clear of the colour.",
                summary: \.summary),
            .of("size", "Name size", LabHZSize.self, default: .s14,
                question: "Compare the name at each size on the chosen layout. How big should the name be?",
                recommend: .s14,
                why: "14pt bold-ish is one point above the rows (13pt), which is all a name that is also a heading needs; today's Small is 18 and Medium 22. The settings can still offer larger ones.",
                summary: { $0.rawValue }),
            .of("eyebrow", "Line above the name", LabHZEyebrow.self, default: .none,
                question: "Choose the layouts with a line. What should the setting do?",
                recommend: .none,
                why: "None must be only the name, with the height reduced by the line and its gap and nothing added under the name: the Heights table shows exactly what it removes. At one row the line has no room at all, so the setting is hidden for LY1 and LY3.",
                summary: { $0.rawValue }),
            .of("density", "Spacing", LabHZDensity.self, default: .tight,
                question: "Compare the padding round the banner's content.",
                recommend: .tight,
                why: "6pt top and bottom against 10: the same card in 8pt less, and the header still breathes because the name is the only large thing in it."),
            .of("sample", "Server", LabSHSample.self, default: .production),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "The title banner as built, Medium (22) with the section line.",
                  isEchoToday: true, designWidth: width, designHeight: 360) { values in
                LabHZColumn { LabHZCard(look: .today, server: sample(values)) }
            },
            .init(id: "proposal", title: "Proposal",
                  summary: "Built from the controls. Click the icons.",
                  designWidth: width, designHeight: 360) { values in
                LabHZColumn { LabHZCard(look: LabHZLook(values), server: sample(values)) }
            },
            .init(id: "three", title: "Three servers",
                  summary: "Three cards at the chosen size: how much of the sidebar does a card take?",
                  designWidth: width, designHeight: 520) { values in
                LabHZColumn {
                    LabHZCard(look: LabHZLook(values), server: .production, rowLimit: 2)
                    LabHZCard(look: LabHZLook(values), server: .test, rowLimit: 2)
                    LabHZCard(look: LabHZLook(values), server: .development, rowLimit: 2)
                }
            },
            .init(id: "sizes", title: "Every size",
                  summary: "The six name sizes on the chosen layout, each with its header height.",
                  designWidth: 700, designHeight: 620) { values in
                LabHZGallery(look: LabHZLook(values), server: sample(values))
            },
            .init(id: "heights", title: "Heights",
                  summary: "The header's height for every size and every Line Above the Name, from the numbers the drawing uses.",
                  designWidth: 460, designHeight: 420) { values in
                LabHZTable(look: LabHZLook(values))
            },
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "One row, 14pt, no line, tight.",
                  values: ["layout": LabHZLayout.inline.rawValue, "size": LabHZSize.s14.rawValue, "eyebrow": LabHZEyebrow.none.rawValue,
                           "density": LabHZDensity.tight.rawValue],
                  isRecommended: true),
            .init(id: "stacked", name: "Stacked, small", summary: "The line, the name and the menu, at 14pt and tight.",
                  values: ["layout": LabHZLayout.stacked.rawValue, "size": LabHZSize.s14.rawValue, "eyebrow": LabHZEyebrow.section.rawValue,
                           "density": LabHZDensity.tight.rawValue]),
            .init(id: "slim", name: "Slim banner", summary: "A 30pt banner and the menu on the card.",
                  values: ["layout": LabHZLayout.slim.rawValue, "size": LabHZSize.s14.rawValue, "eyebrow": LabHZEyebrow.none.rawValue,
                           "density": LabHZDensity.tight.rawValue]),
        ]
    )

    private static func sample(_ values: RoundValues) -> LabSHServer {
        (LabSHSample(rawValue: values["sample"]) ?? .production).server
    }
}

/// The tree's column with cards in it.
struct LabHZColumn<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: SpacingTokens.xs) { content }
            .padding(SpacingTokens.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(ColorTokens.Workspace.canvas)
    }
}
