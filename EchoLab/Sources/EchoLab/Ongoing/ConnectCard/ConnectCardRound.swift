import SwiftUI

/// Round 56 · The connect card, now its own button. The connect button is a glass circle of its own under
/// the connected and recent pills (round 55), but round 52's card still opens as if from the top group
/// of connected servers. This round decides how it opens from the circle, what it holds now that the
/// connected servers are in plain sight, what the circle does meanwhile, what the other pills do,
/// and that it dismisses on a click outside, Escape and the close button.
@MainActor
enum ConnectCardRound {
    private static let width = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xxxl * 3

    static let spec = RoundSpec(
        controls: [
            .of("presentation", "Opens as", LabCPPresentation.self, default: .grows,
                question: "Press the circle with each presentation, then click outside the card and press Escape. How should the card open from the circle?",
                recommend: .grows,
                why: "The circle is the button and the card is what it opens: one liquid glass shape that swells from the circle and shrinks back into it says that without a word, and keeps the card's corner at the thing you pressed. The spring from the corner (PR1) is the same without the morph, and the safe choice if the morph looks wrong at Corners 10; the pills melting into one panel (PR2) is what you accepted in round 52 but no longer matches a button that is not part of a pill.",
                summary: \.summary),
            .of("content", "The card holds", LabCPContent.self, default: .search,
                question: "Open the card with each content. What should it hold now that the connected servers are visible beside it?",
                recommend: .search,
                why: "The row of connected servers repeated what is a few points to its left, and made the card taller for nothing. The search field with the three actions beside it is the first thing you use and the only thing the card does that the trail does not.",
                summary: \.summary),
            .of("button", "The circle meanwhile", LabCPButton.self, default: .morphs,
                question: "Open and close the card with each. What should the circle do while the card is open?",
                recommend: .morphs,
                why: "It is the button you will reach for again, and it is where your pointer already is: the rack turning to an × with a symbol effect makes the circle the close button, so the card needs none of its own. A pressed rack (CB1) is the quiet choice that keeps the glyph.",
                summary: \.summary),
            .of("others", "The other pills", LabCPOthers.self, default: .stay,
                question: "Open the card and try the trail with each. What do the connected and recent pills do?",
                recommend: .stay,
                why: "The trail is how you move around Echo; a card that does not take it away lets you switch server with the card still open. Dimming (OT1) is the choice if the card should feel modal, and goes with a scrim.",
                summary: \.summary),
            .of("close", "Close button", LabCPClose.self, default: .yes,
                question: "You asked for a click outside to dismiss it, as well as the ×. Keep the ×?",
                recommend: .yes,
                why: "A click outside and Escape are invisible, so a visible way out is what makes the card feel safe; with CB0 the circle is that button and this one is redundant, with CB1 or CB2 it is needed."),
            .of("scrim", "Scrim", LabCPScrim.self, default: .none),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "Round 52's card: the pills fade and the card grows from the top of the trail. Press the circle; click outside to dismiss.",
                  isEchoToday: true, designWidth: width, designHeight: 520) { _ in
                LabCPWindow(look: .today)
            },
            .init(id: "proposal", title: "Proposal",
                  summary: "Built from the controls. Press the circle to open; click outside the card, press Escape or the close button to dismiss.",
                  designWidth: width, designHeight: 520) { values in
                LabCPWindow(look: LabCPLook(values))
            },
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "The circle grows into a card that holds the search field and the three actions; the circle becomes the ×.",
                  values: ["presentation": LabCPPresentation.grows.rawValue, "content": LabCPContent.search.rawValue,
                           "button": LabCPButton.morphs.rawValue, "others": LabCPOthers.stay.rawValue, "close": LabCPClose.yes.rawValue],
                  isRecommended: true),
            .init(id: "palette", name: "Palette", summary: "A centred palette with a scrim and a close button.",
                  values: ["presentation": LabCPPresentation.palette.rawValue, "content": LabCPContent.search.rawValue,
                           "button": LabCPButton.stays.rawValue, "others": LabCPOthers.dim.rawValue, "scrim": LabCPScrim.light.rawValue,
                           "close": LabCPClose.yes.rawValue]),
            .init(id: "popover", name: "System popover", summary: "A popover with an arrow; it dismisses itself on a click outside.",
                  values: ["presentation": LabCPPresentation.popover.rawValue, "content": LabCPContent.search.rawValue,
                           "button": LabCPButton.stays.rawValue, "others": LabCPOthers.stay.rawValue, "close": LabCPClose.no.rawValue]),
        ]
    )
}
