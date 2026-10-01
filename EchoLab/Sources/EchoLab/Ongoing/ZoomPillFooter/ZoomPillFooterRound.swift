import SwiftUI

/// Round 31 · Editor: the zoom pill and the footer. Echo today (EditorZoomControl, QueryInputSection):
/// the pill is an overlay at the editor's bottom leading corner, 8pt in (`SpacingTokens.xs`) and 28pt up
/// (the editor's 20pt bottom padding plus 8); its text is 11pt secondary with 8 by 4pt padding, about
/// 21pt tall. The footer's pills are 24pt (`LayoutTokens.Footer.chipHeight`), 12pt in, 9pt above the
/// card's edge (`LayoutTokens.Footer.pillInset`), with primary text. Without results the footer sits in
/// the editor's card, so the pill lands on top of the server pill.
@MainActor
enum ZoomPillFooterRound {
    enum WithResults: String, CaseIterable {
        case today = "ZW0 · 28pt up, 8pt in (today)"
        case footer = "ZW1 · 9pt up, 12pt in: where the footer's pills sit in their card"
    }

    enum WithoutResults: String, CaseIterable {
        case today = "ZN0 · 28pt up, 8pt in, over the server pill (today)"
        case stackedTight = "ZN1 · Above the server pill, left edges aligned, 6pt between"
        case stacked = "ZN2 · Above the server pill, left edges aligned, 9pt between"
        case inFooter = "ZN3 · In the footer row, after the Results and Messages pill"

        var summary: String {
            switch self {
            case .today: "The pill's bottom is 5pt below the server pill's top and 4pt further left, so they collide."
            case .stackedTight: "A tight stack: reads as one group with the server pill."
            case .stacked: "The same 9pt the pills keep from the card's edge, so the corner has one rhythm."
            case .inFooter: "Not above it at all: one more pill in the footer row while there are no results."
            }
        }
    }

    enum Height: String, CaseIterable {
        case today = "ZH0 · About 21pt (today)"
        case footer = "ZH1 · 24pt, as the footer's pills"
    }

    enum TextColour: String, CaseIterable {
        case secondary = "ZT0 · Secondary grey (today)"
        case primary = "ZT1 · Primary, as the server pill"
    }

    struct Look {
        var withResults: WithResults
        var withoutResults: WithoutResults
        var height: Height
        var text: TextColour
        static let today = Look(withResults: .today, withoutResults: .today, height: .today, text: .secondary)

        @MainActor static func from(_ values: RoundValues) -> Look {
            Look(withResults: WithResults(rawValue: values["withResults"]) ?? .footer,
                 withoutResults: WithoutResults(rawValue: values["withoutResults"]) ?? .stacked,
                 height: Height(rawValue: values["height"]) ?? .footer,
                 text: TextColour(rawValue: values["text"]) ?? .primary)
        }
    }

    static let spec = RoundSpec(
        controls: [
            .of("withResults", "With results", WithResults.self, default: .footer,
                question: "Compare the editor's bottom corner with the results card's footer below it. Where should the pill sit?",
                recommend: .footer,
                why: "You asked for it: the same 9pt from the edge and the same 12pt in as the server pill, so the two cards' bottom corners match."),
            .of("withoutResults", "Without results", WithoutResults.self, default: .stacked,
                question: "Look at the tabs without results. How should the pill sit relative to the server pill?",
                recommend: .stacked,
                why: "You asked for it aligned and above; 9pt is the gap the pills already keep from the edge, so the corner reads as one column with one spacing. 6pt makes the two pills look like a single control; in the footer row it would jump sideways the moment results arrive.",
                summary: \.summary),
            .of("height", "Height", Height.self, default: .footer,
                question: "Compare the two pills' heights.",
                recommend: .footer,
                why: "Two glass pills of different heights stacked on each other look like a mistake; 24pt is the footer's chip height (`LayoutTokens.Footer.chipHeight`)."),
            .of("text", "Text", TextColour.self, default: .primary,
                question: "Compare the pill's 100% with the server pill's text.",
                recommend: .primary,
                why: "You found it too dim; the server pill's text is primary, and the zoom is a control you click, not a passive label."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today, with results", summary: "28pt up and 8pt in, about 21pt tall, grey text.",
                  isEchoToday: true, designWidth: 560, designHeight: 400) { _ in
                LabZPTab(look: .today, hasResults: true)
            },
            .init(id: "todayEmpty", title: "Echo today, no results", summary: "The footer sits in the editor's card and the pill lands on the server pill.",
                  isEchoToday: true, designWidth: 560, designHeight: 400) { _ in
                LabZPTab(look: .today, hasResults: false)
            },
            .init(id: "proposal", title: "Proposal, with results", summary: "Built from the controls.",
                  designWidth: 560, designHeight: 400) { values in
                LabZPTab(look: Look.from(values), hasResults: true)
            },
            .init(id: "proposalEmpty", title: "Proposal, no results", summary: "Built from the controls.",
                  designWidth: 560, designHeight: 400) { values in
                LabZPTab(look: Look.from(values), hasResults: false)
            },
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Footer spacing, stacked 9pt above, 24pt, primary.",
                  values: ["withResults": WithResults.footer.rawValue, "withoutResults": WithoutResults.stacked.rawValue,
                           "height": Height.footer.rawValue, "text": TextColour.primary.rawValue],
                  isRecommended: true),
        ]
    )
}

/// A query tab: the editor card with the zoom pill, then the results card (or, with no results,
/// the footer inside the editor's card).
private struct LabZPTab: View {
    let look: ZoomPillFooterRound.Look
    let hasResults: Bool

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            ZStack(alignment: .bottomLeading) {
                LabWKEditor()
                if !hasResults {
                    LabWKFooter(pills: LabWKPill.ready, afterSegments: inFooter ? AnyView(pill) : nil)
                        .padding(.bottom, LayoutTokens.Footer.bottomLift)
                }
                if !inFooter { pill.padding(.leading, leading).padding(.bottom, bottom) }
            }
            .frame(maxWidth: .infinity, maxHeight: hasResults ? SpacingTokens.xxxl * 3 : .infinity)
            .workspaceCard()
            if hasResults {
                VStack(spacing: SpacingTokens.none) {
                    LabWKGrid()
                    Spacer(minLength: 0)
                    LabWKFooter().padding(.bottom, LayoutTokens.Footer.bottomLift)
                }
                .workspaceCard()
            }
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas)
    }

    private var inFooter: Bool { !hasResults && look.withoutResults == .inFooter }

    private var leading: CGFloat {
        if hasResults { return look.withResults == .today ? SpacingTokens.xs : SpacingTokens.sm }
        return look.withoutResults == .today ? SpacingTokens.xs : SpacingTokens.sm
    }

    private var bottom: CGFloat {
        let pillTop = LayoutTokens.Footer.pillInset + LayoutTokens.Footer.chipHeight
        if hasResults { return look.withResults == .today ? SpacingTokens.md2 + SpacingTokens.xs : LayoutTokens.Footer.pillInset }
        switch look.withoutResults {
        case .today: return SpacingTokens.md2 + SpacingTokens.xs
        case .stackedTight: return pillTop + SpacingTokens.xxs2
        case .stacked, .inFooter: return pillTop + LayoutTokens.Footer.pillInset
        }
    }

    private var pill: some View {
        HStack(spacing: SpacingTokens.xxxs) {
            Text("100%").monospacedDigit()
            Image(systemName: "chevron.down").font(TypographyTokens.compact.weight(.semibold))
        }
        .font(TypographyTokens.detail)
        .foregroundStyle(look.text == .primary ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
        .padding(.horizontal, look.height == .footer ? LayoutTokens.Footer.chipHorizontalPadding : SpacingTokens.xs)
        .padding(.vertical, look.height == .footer ? SpacingTokens.none : SpacingTokens.xxs)
        .frame(height: look.height == .footer ? LayoutTokens.Footer.chipHeight : nil)
        .glassEffect(.regular, in: .capsule)
    }
}
