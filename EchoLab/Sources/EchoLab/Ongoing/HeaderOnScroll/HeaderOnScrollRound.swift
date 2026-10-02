import SwiftUI

/// Round 57 · The card header while the tree scrolls. Revision 3: the owner's finalists are HB3 (the
/// menu as a floating glass pill) and HB1 (the menu as a slim bar), without a tint. What matters is
/// the animation: while scrolling, and what happens when an icon is clicked while the card is scrolled
/// down, when the header must come back and the card gets taller between the other cards. The lab is a
/// tree of three cards, each header pinned from its own scroll position, pushed out by the next card.
/// Changes TREE-2.1 and the section dock (TREE-3).
@MainActor
enum HeaderOnScrollRound {
    private static let width = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xl

    static let spec = RoundSpec(
        controls: [
            .of("form", "Form", LabHSForm.self, default: .pill,
                question: "Scroll the tree slowly (the menu morphs over the first 52pt of each card), then back, then click icons while a card is scrolled. Which form?",
                recommend: .pill,
                why: "You like both. The pill lets the rows run the full width of the card under it and says 'menu', not 'second banner'; the bar is the more solid and keeps the colour on screen the whole time you read a card, which the pill (in clear glass) does not. If the server's colour must always be visible, ship HB1 or HB2; if the card should look as quiet as possible when scrolled, HB3.",
                summary: \.summary),
            .of("material", "The pill", LabHSMaterial.self, default: .glass,
                question: "With a pill form: compare the materials over the rows.",
                recommend: .glass,
                why: "Clear glass is what you picked, and it is the one the rest of the window is made of (the trail, the drawer). The solid pill keeps the colour, the frosted and the surface ones are the calm answers if the blur behind clear glass feels busy against fifty rows of text.",
                summary: \.summary),
            .of("morph", "The morph", LabHSMorph.self, default: .follows,
                question: "Scroll very slowly, stop half-way, and scroll back, with each. How should the menu change shape?",
                recommend: .follows,
                why: "A morph tied to the scroll position is the one that cannot lag or fight you: it is exactly where your finger is, reverses exactly, and costs no timer. The spring at a threshold is livelier but plays on its own clock, so a quick flick and a slow drag look different and the two can disagree with the scroll for a frame.",
                summary: \.summary),
            .of("click", "Clicking an icon while scrolled", LabHSClick.self, default: .smooth,
                question: "Scroll a card down, click an icon in its menu, and watch the header and the card with each. How should the header come back?",
                recommend: .smooth,
                why: "Because the morph follows the scroll, a smooth scroll to the card's top plays the whole morph backwards by itself: the pill opens into the menu row, the banner descends, the new rows are where they will be, and it is one motion rather than a scroll and a separate header animation. The jump with its own spring (CK3) is the one to pick if scrolling a long way should not take time; the instant jump is how it feels today and the reason you asked.",
                summary: \.summary),
            .of("feel", "The spring", LabHSFeel.self, default: .house,
                question: "Compare the three on CK3 and on the threshold morph. How lively?",
                recommend: .house,
                why: "The house spring is what the trail's glide and the drawer use, so cards and rail move as one family. Smooth if the bounce is felt on a banner this large.",
                summary: { $0.rawValue }),
            .of("position", "Pill position", LabHSPosition.self, default: .centre,
                question: "With a pill form, where should the pill sit in the card's width?",
                recommend: .centre,
                why: "Centred: it does not point at either side of a list whose rows are left-aligned and whose scroll bar is on the right. At the leading edge it lines up with the rows' icons if you want the rows and the menu to share an edge."),
            .of("push", "When the next card arrives", LabHSPush.self, default: .slides,
                question: "Scroll until the next card's top reaches the pinned menu. What does the menu do?",
                recommend: .slides,
                why: "It is pushed up and out by the card that is taking its place, like a sticky section header: it never overlaps the next card's own banner and the hand-over is a motion you can follow. The full hand-over (the next card's header rounding as it is overtaken) is round 59."),
            .of("slim", "Bar height", LabHSSlim.self, default: .medium),
            .of("speed", "Speed", LabHSSpeed.self, default: .standard),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "The whole banner pinned, a hard edge, pushed out by the card's end. Scroll.",
                  isEchoToday: true, designWidth: width, designHeight: 560) { _ in
                LabHSTree(look: .today)
            },
            .init(id: "proposal", title: "Proposal",
                  summary: "Built from the controls. Scroll slowly, back up, and click icons while a card is scrolled.",
                  designWidth: width, designHeight: 560) { values in
                LabHSTree(look: LabHSLook(values))
            },
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "The pill, in clear glass, following the scroll; an icon click scrolls the card up and the header comes back.",
                  values: ["form": LabHSForm.pill.rawValue, "material": LabHSMaterial.glass.rawValue, "morph": LabHSMorph.follows.rawValue,
                           "click": LabHSClick.smooth.rawValue, "feel": LabHSFeel.house.rawValue, "position": LabHSPosition.centre.rawValue,
                           "push": LabHSPush.slides.rawValue],
                  isRecommended: true),
            .init(id: "bar", name: "The bar", summary: "HB1: the menu as a slim bar, following the scroll.",
                  values: ["form": LabHSForm.bar.rawValue, "morph": LabHSMorph.follows.rawValue, "click": LabHSClick.smooth.rawValue]),
            .init(id: "spring", name: "A spring", summary: "The pill morphs on a spring at a threshold; a click reveals the header on its own spring.",
                  values: ["form": LabHSForm.pill.rawValue, "material": LabHSMaterial.glass.rawValue, "morph": LabHSMorph.springs.rawValue,
                           "click": LabHSClick.reveal.rawValue, "feel": LabHSFeel.house.rawValue]),
            .init(id: "namepill", name: "A pill with the name", summary: "One surface with the name and the menu, in frosted material.",
                  values: ["form": LabHSForm.pillName.rawValue, "material": LabHSMaterial.frosted.rawValue, "morph": LabHSMorph.follows.rawValue,
                           "click": LabHSClick.smooth.rawValue]),
        ]
    )
}
