import SwiftUI

/// Round 28.14 · Editor: the gutter's lane (the owner's screenshots of the gutter styles). Echo
/// today (LineNumberRulerView): the lane covers the whole gutter inset 5pt, with an 8pt corner in
/// the palette's grey, drawn inside the editor's scroll view, so it stops about 25pt above the
/// card's bottom; the numbers stay right-aligned 2pt from its right edge, with the empty 11pt
/// slot for the error dot and Run arrow on their left. Column and Hairline were fixed to run the
/// card's full height (decd9770); this page decides the lane. Changes EDT-2.1.
@MainActor
enum EditorGutterLaneRound {
    static let spec = RoundSpec(
        controls: [
            .of("laneHolds", "What the lane holds", LabQELaneHolds.self, default: .numbers,
                question: "Compare the two in the Proposal, with The editor shows set to A mistake while typing. What should the lane wrap?",
                recommend: .numbers,
                why: "A lane round the numbers alone is symmetric, so the numbers sit in its middle; the error dot and Run arrow keep their place just left of it. Wrapping the empty marker slot is what pushes today's numbers to one side.",
                summary: \.summary),
            .of("laneAlign", "Numbers", LabQELaneAlign.self, default: .centre,
                question: "Look at lines 1 to 9 (one digit) against 10 to 12. Should the numbers be centred in the lane?",
                recommend: .centre,
                why: "In a narrow lane a single digit right-aligned looks like it slipped to one side; centred, 1 to 9 and 10 to 12 all sit on the lane's middle. Right-alignment matters for long columns of numbers in a table, not for a few line numbers."),
            .of("laneHeight", "Height", LabQELaneHeight.self, default: .full,
                question: "Should the lane run the card's height?",
                recommend: .full,
                why: "A lane that stops short reads as a floating box, the same fault the column had; 5pt from every edge makes it a calm inset strip, as the design board described it (GT2).",
                summary: \.summary),
            .of("laneCorner", "Corners", LabQELaneCorner.self, default: .concentric,
                question: "Try each with Card Corners at 10 and at 26 in the toolbar. Which corner should the lane have?",
                recommend: .concentric,
                why: "Concentric corners follow the card's own (minus the 5pt inset), so the lane looks cut from the same shape at any Card Corners setting; a fixed 8pt looks wrong at 26, and round ends turn a 30pt-wide lane into a pill.",
                summary: \.summary),
            .of("laneFill", "Fill", LabQELaneFill.self, default: .system,
                question: "Look in light and dark. What should the lane be made of?",
                recommend: .system,
                why: "The system's quiet fill is what macOS uses for grouped content, so the lane follows dark mode and Increase Contrast and matches the tree's selection and grouped boxes; the palette's fixed greys don't follow anything. The outline is lighter but adds another hairline beside the code.",
                summary: \.summary),
            LabQERound.sceneControl(default: .liveError),
            LabQERound.baseControl,
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "The lane as Echo draws it now: the whole gutter, right-aligned numbers, 25pt short of the bottom.",
                  isEchoToday: true, designWidth: LabQERound.width, designHeight: LabQERound.height) { values in
                LabQEEditor(style: LabQEStyle.today.with { $0.gutter = .lane }, scene: LabQERound.scene(values, .liveError))
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls, on Lane.", designWidth: LabQERound.width, designHeight: LabQERound.height) { values in
                LabQEEditor(style: LabQEBase.proposal(values).with { $0.gutter = .lane }, scene: LabQERound.scene(values, .liveError))
            },
            LabQERound.gallery("Corners", "Every corner, on the proposal's lane.", LabQELaneCorner.self, \.laneCorner, scene: .liveError,
                               cellHeight: 180, adjust: { $0.gutter = .lane }),
            LabQERound.gallery("Fills", "Every fill, on the proposal's lane.", LabQELaneFill.self, \.laneFill, scene: .liveError, id: "fills",
                               cellHeight: 180, adjust: { $0.gutter = .lane }),
        ],
        exhibitTopic: ("Which lane?", "Look at both in light and dark, at Card Corners 10 and 26. Is the proposal better than Echo today?", "proposal",
                       "A quiet strip round the numbers alone, the card's height, its corners following the card's, the numbers in its middle."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Numbers only, centred, full height, concentric, system fill.",
                  values: ["laneHolds": LabQELaneHolds.numbers.rawValue, "laneAlign": LabQELaneAlign.centre.rawValue,
                           "laneHeight": LabQELaneHeight.full.rawValue, "laneCorner": LabQELaneCorner.concentric.rawValue,
                           "laneFill": LabQELaneFill.system.rawValue],
                  isRecommended: true),
            .init(id: "today", name: "Like Echo today",
                  values: ["laneHolds": LabQELaneHolds.everything.rawValue, "laneAlign": LabQELaneAlign.right.rawValue,
                           "laneHeight": LabQELaneHeight.short.rawValue, "laneCorner": LabQELaneCorner.eight.rawValue,
                           "laneFill": LabQELaneFill.palette.rawValue]),
            .init(id: "pill", name: "Pill", summary: "Numbers only, centred, round ends, an outline.",
                  values: ["laneHolds": LabQELaneHolds.numbers.rawValue, "laneAlign": LabQELaneAlign.centre.rawValue,
                           "laneHeight": LabQELaneHeight.full.rawValue, "laneCorner": LabQELaneCorner.capsule.rawValue,
                           "laneFill": LabQELaneFill.outline.rawValue]),
        ]
    )
}
