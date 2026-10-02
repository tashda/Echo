import SwiftUI

/// Round 59 · A card arriving under the pinned menu. Round 57 built the glass pill that follows the scroll
/// and is pushed out by the next card. The owner asked how the hand-over between two cards should look:
/// the previous card's pill, the next card's top edge and corners. Changes TREE-2.3.
@MainActor
enum CardHandoverRound {
    private static let width = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xl

    static let spec = RoundSpec(
        controls: [
            .of("handover", "The hand-over", LabHOHandover.self, default: .push,
                question: "Scroll slowly down through the cards, and back, with each. What should the pill do as the next card arrives?",
                recommend: .overtaken,
                why: "A pill that is shoved up by the next card looks like something being moved out of the way; one that is covered by the next card looks like a card sliding over another, which is what is happening. The pill never leaves its place, so it never has to be anywhere else, and its glass is the thing that stays steady under your eye until the new card's own edge takes it. HO0 is round 57 as built and the safe choice if overlapping feels fussy.",
                summary: \.summary),
            .of("cards", "The cards", LabHOCards.self, default: .apart,
                question: "Compare the cards apart and overlapping, with the hand-over you chose. How should two cards meet?",
                recommend: .overlap,
                why: "Overlap with a shadow is what makes the hand-over read: the next card's top edge is a shape lying on the last card, so the pill disappears under something and not into a gap. With an 8pt gap the pill has to leave through the canvas, which is why HO0 needs to push it.",
                summary: \.summary),
            .of("form", "The pill", LabHSForm.self, default: .pill),
            .of("material", "Pill material", LabHSMaterial.self, default: .glass),
            .of("sample", "Server", LabSHSample.self, default: .production),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "Round 57 as built: the pill is pushed out by the next card, the cards apart.",
                  isEchoToday: true, designWidth: width, designHeight: 560) { _ in
                LabHOTree(look: behaviour(), handover: .push, overlap: false)
            },
            .init(id: "proposal", title: "Proposal",
                  summary: "Scroll slowly through the three cards and back; click icons in a pill.",
                  designWidth: width, designHeight: 560) { values in
                LabHOTree(look: look(values), handover: LabHOHandover(rawValue: values["handover"]) ?? .push,
                          overlap: (LabHOCards(rawValue: values["cards"]) ?? .apart) == .overlap)
            },
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Cards overlap with a shadow; the next card slides over the pill.",
                  values: ["handover": LabHOHandover.overtaken.rawValue, "cards": LabHOCards.overlap.rawValue],
                  isRecommended: true),
            .init(id: "built", name: "As built", summary: "Round 57: the pill is pushed out, the cards apart.",
                  values: ["handover": LabHOHandover.push.rawValue, "cards": LabHOCards.apart.rawValue]),
            .init(id: "chip", name: "A name on the way out", summary: "The pill shrinks to a name chip, then the next card covers it.",
                  values: ["handover": LabHOHandover.chip.rawValue, "cards": LabHOCards.overlap.rawValue]),
        ]
    )

    /// The pill and its material as the owner chose them in round 57: HB3, clear glass.
    private static func look(_ values: RoundValues) -> LabHSLook {
        var look = LabHSLook(isToday: false)
        look.form = LabHSForm(rawValue: values["form"]) ?? .pill
        look.material = LabHSMaterial(rawValue: values["material"]) ?? .glass
        look.morph = .follows
        look.click = .smooth
        look.push = .slides
        return look
    }

    private static func behaviour() -> LabHSLook {
        var look = LabHSLook(isToday: false)
        look.form = .pill; look.material = .glass; look.morph = .follows; look.click = .smooth
        return look
    }
}
