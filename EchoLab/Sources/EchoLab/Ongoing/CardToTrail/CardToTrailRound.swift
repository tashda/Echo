import SwiftUI

/// Round 54 · Minimizing a card into the trail. Revision 2: one animation, made properly.
///
/// The owner did not like the eight journeys of revision 1 (they liked the ideas of AN1, a straight
/// shrink, and AN3, fold then fly, but they were janky) and asked for the card to transform into
/// the trail circle during the animation and land in its place, smooth, instant on click, with
/// very little bounce. This is that: the card's colour banner is what becomes the circle. A real spring
/// drives one progress value and every part is recomputed from it each frame (see LabMVMorph), so
/// there are no cross-faded snapshots, no squeezed text and no stages that wait for each other.
/// Round 51's SH5 (a minimized card leaves the tree) is built. Changes TREE-2.4 and the rail's items.
@MainActor
enum CardToTrailRound {
    private static let width = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xxxl * 2

    static let spec = RoundSpec(
        controls: [
            .of("fold", "The card", LabMVFold.self, default: .rows,
                question: "Minimize a card with each (use Slow to study). What should the card itself do while the banner flies?",
                recommend: .rows,
                why: "You liked the fold of AN3 and the directness of AN1: this overlaps them. The rows fold into the header in the first 45% while the banner is already narrowing, so there is no pause between two stages (the cause of the jank), and you see the rows go in. FD2 is the cleanest shape if you would rather not see the card at all.",
                summary: \.summary),
            .of("path", "Path", LabMVPath.self, default: .curve,
                question: "Watch the disc's route with each path. How should it travel?",
                recommend: .curve,
                why: "A straight line cuts across the cards in the way and reads as a drag. A 25% curve leaves along the card and arrives from the side, which is how the disc ends up beside the rail instead of on top of it. The swoop is for a card that is a long way from its item.",
                summary: \.summary),
            .of("bounce", "Bounce", LabMVBounce.self, default: .tiny,
                question: "Minimize with each and watch the disc land. How much should it bounce?",
                recommend: .tiny,
                why: "You asked for very little. The bounce is the spring's own overshoot, shown as the disc swelling about 3% and settling: you feel it arrive without seeing it move twice. More than that, and the ring that draws a moment later seems to chase the disc.",
                summary: { $0.rawValue }),
            .of("duration", "Duration", LabMVDuration.self, default: .standard,
                question: "Compare the three lengths. How long should it take?",
                recommend: .standard,
                why: "0.6 s is long enough to follow a disc across a window and short enough to feel like the answer to a click; 0.45 s is the one to ship if you minimize cards often. The spring finishes its bounce inside the time.",
                summary: { $0.rawValue }),
            .of("landing", "Landing", LabMVLanding.self, default: .ring,
                question: "Watch the last 15% of the move with each. How does the disc become the trail item?",
                recommend: .ring,
                why: "The item is letters in the server's colour and a dashed ring. The disc's fill clears while its white letters take the colour and the ring draws itself, so there is no moment when one thing is replaced by another: what is left when the fill is gone is the item.",
                summary: \.summary),
            .of("gap", "The cards below", LabMVGap.self, default: .during),
            .of("restore", "Coming back", LabMVRestore.self, default: .reverse),
            .of("speed", "Speed", LabMVSpeed.self, default: .standard),
        ],
        actions: [
            .init(id: "play", title: "Play: minimize the first card and bring it back", symbol: "play.fill") { values in
                values["pulse"] = UUID().uuidString
            },
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "A card fades where it is and the gap closes. Click a card's header.",
                  isEchoToday: true, designWidth: width, designHeight: 440) { values in
                LabMVWindow(look: LabMVLook.today, pulse: values["pulse"])
            },
            .init(id: "proposal", title: "Proposal",
                  summary: "Built from the controls. Click a header to minimize; click the ringed item to restore; or press Play.",
                  designWidth: width, designHeight: 440) { values in
                LabMVWindow(look: LabMVLook(values), pulse: values["pulse"])
            },
            .init(id: "stills", title: "Eight stills",
                  summary: "The flight at 0, 12, 25, 40, 55, 70, 85 and 100% with the chosen fold, path and landing: check the shapes without watching.",
                  designWidth: 700, designHeight: 620) { values in
                LabMVFilmstrip(look: LabMVLook(values))
            },
        ],
        questions: [
            .init(id: "reduce", title: "Reduce Motion",
                  question: "With Reduce Motion on, what should minimizing do?",
                  choices: [
                      .init(id: "fade", name: "RM0 · The card fades and the cards below rise; the item's ring simply appears", summary: nil),
                      .init(id: "short", name: "RM1 · The same flight without the bounce, at half the length", summary: nil),
                  ],
                  recommended: "fade",
                  why: "Travel across the window is exactly what Reduce Motion is for; the ring appearing is still a clear answer, and Echo's motion tokens already turn springs into short fades."),
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Rows fold as the banner flies a gentle curve, a very small bounce, the ring draws.",
                  values: ["fold": LabMVFold.rows.rawValue, "path": LabMVPath.curve.rawValue, "bounce": LabMVBounce.tiny.rawValue,
                           "duration": LabMVDuration.standard.rawValue, "landing": LabMVLanding.ring.rawValue],
                  isRecommended: true),
            .init(id: "clean", name: "Clean", summary: "Only the banner travels, straight, no bounce.",
                  values: ["fold": LabMVFold.banner.rawValue, "path": LabMVPath.straight.rawValue, "bounce": LabMVBounce.none.rawValue,
                           "duration": LabMVDuration.fast.rawValue, "landing": LabMVLanding.disc.rawValue]),
            .init(id: "lively", name: "Lively", summary: "A swoop, more bounce, a pop as the ring closes.",
                  values: ["fold": LabMVFold.direct.rawValue, "path": LabMVPath.swoop.rawValue, "bounce": LabMVBounce.more.rawValue,
                           "duration": LabMVDuration.slow.rawValue, "landing": LabMVLanding.ringPop.rawValue]),
        ]
    )
}
