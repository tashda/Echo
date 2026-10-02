import SwiftUI

/// Round 54 · Minimizing a card into the trail. Round 51 (SH5) and the owner's answer decided that a
/// minimized card leaves the tree and its trail item takes a dashed ring. This round is how that
/// looks in motion: the card's journey (AN), how the trail item answers (RC), when the cards below
/// close the gap (GP) and how the card comes back (RS). Changes TREE-2.4 and the rail's items.
@MainActor
enum CardToTrailRound {
    private static let width = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xxxl * 2

    static let spec = RoundSpec(
        controls: [
            .of("motion", "Journey", LabMVMotion.self, default: .arc,
                question: "Press Play, then minimize a card by clicking its header, with each journey. Which one should a card take into the trail?",
                recommend: .arc,
                why: "A card is too big and too busy to be followed in flight; what the eye can follow is a thing the size of its destination. The arc shrinks the card to a disc in its own colour first, then carries that disc along a curve to the item, so you see which server went where. The genie is the closest to the system's own but squeezes live text and rows, which looks like a glitch at 0.65 s; the shrink is the quietest that still travels; the fade (AN0) is the one to ship if you want no flourish at all.",
                summary: \.summary),
            .of("receive", "Trail item", LabMVReceive.self, default: .popRing,
                question: "Watch the trail item as the card lands. How should it answer?",
                recommend: .popRing,
                why: "The ring is what changes, so the answer is the ring drawing itself, and a short swell tells the eye where to look; together they are 0.5 s that make the arrival visible without a sound or a bounce of the whole rail. Glow is the one that works worst in light mode, where the glow of a pale server colour disappears.",
                summary: \.summary),
            .of("gap", "Gap", LabMVGap.self, default: .during,
                question: "Compare the cards below rising at once and rising after the card lands.",
                recommend: .during,
                why: "A hole in the list for half a second says something is still there; closing it as the card leaves says it is gone and on its way. After-landing is calmer if the journey is short.",
                summary: \.summary),
            .of("restore", "Coming back", LabMVRestore.self, default: .reverse,
                question: "Click a ringed item. How should the card come back?",
                recommend: .reverse,
                why: "The same motion backwards teaches itself: you saw the card go in, so you know where it comes from. Growing on a spring is the friendlier one, but the overshoot makes the card cross the one above it.",
                summary: \.summary),
            .of("speed", "Speed", LabMVSpeed.self, default: .standard),
        ],
        actions: [
            .init(id: "play", title: "Play: minimize the first card and bring it back", symbol: "play.fill") { values in
                values["pulse"] = UUID().uuidString
            },
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "The card fades where it is and the gap closes: what a collapse does now, without the trail. Click a card's header.",
                  isEchoToday: true, designWidth: width, designHeight: 440) { values in
                LabMVWindow(look: LabMVLook(motion: .inPlace, receive: .none, gap: .after, restore: .simple,
                                            speed: LabMVLook(values).speed), pulse: values["pulse"])
            },
            .init(id: "proposal", title: "Proposal",
                  summary: "Built from the controls. Click a header to minimize; click the ringed item to restore; or press Play.",
                  designWidth: width, designHeight: 440) { values in
                LabMVWindow(look: LabMVLook(values), pulse: values["pulse"])
            },
            .init(id: "all", title: "Every journey",
                  summary: "All eight at once with the chosen trail item, gap and return. Press Play to run them together.",
                  designWidth: 700, designHeight: 620) { values in
                LabMVGallery(look: LabMVLook(values), pulse: values["pulse"])
            },
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "An arc, a pop and a ring, the gap closing at once, the same way back.",
                  values: ["motion": LabMVMotion.arc.rawValue, "receive": LabMVReceive.popRing.rawValue, "gap": LabMVGap.during.rawValue,
                           "restore": LabMVRestore.reverse.rawValue],
                  isRecommended: true),
            .init(id: "quiet", name: "Quiet", summary: "A shrink, no answer, the gap after.",
                  values: ["motion": LabMVMotion.shrink.rawValue, "receive": LabMVReceive.none.rawValue, "gap": LabMVGap.after.rawValue,
                           "restore": LabMVRestore.simple.rawValue]),
            .init(id: "system", name: "Like macOS", summary: "A genie in, a spring out.",
                  values: ["motion": LabMVMotion.genie.rawValue, "receive": LabMVReceive.pop.rawValue, "gap": LabMVGap.during.rawValue,
                           "restore": LabMVRestore.grow.rawValue]),
            .init(id: "ring", name: "Ring only", summary: "Nothing travels; the ring draws itself.",
                  values: ["motion": LabMVMotion.ringFirst.rawValue, "receive": LabMVReceive.ring.rawValue, "gap": LabMVGap.during.rawValue,
                           "restore": LabMVRestore.simple.rawValue]),
        ]
    )
}
