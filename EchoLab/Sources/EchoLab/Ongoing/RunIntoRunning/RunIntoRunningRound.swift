import SwiftUI

/// Round 24 · Run: ▶ into ■. The owner's notes on round 20: the button “coming in from the side”
/// isn't good, ▶ must transform into ■, the capsule must grow much more smoothly for the timer, and
/// the glass morph (A2) should give way to a morph of the icon only. Changes EDT-4.3.
@MainActor
enum RunIntoRunningRound {
    private static var simulation: LabRBSimulation { .shared }

    static let spec = RoundSpec(
        controls: [
            .of("morph", "Morph", LabRMMorph.self, default: .replace,
                question: "Run the 3 s query in each option (Compare: Morphs), and scrub M2 and M3 in Slow motion. Which way should ▶ become ■?",
                recommend: .replace,
                why: "You said round 20's R1, R2 and R4 had exactly the animation you want, and this is it: the capsule stays and ▶ is replaced by ■ in place. M2 (corners slide) is the closest alternative if you want to see the shape itself change; magic replace only crossfades these two symbols; draw and squeeze pass through an empty moment.",
                summary: \.summary),
            .of("fill", "Red", LabRMFill.self, default: .fade,
                question: "Watch the capsule in each option. How should it turn red?",
                recommend: .fade,
                why: "It keeps the red capsule you chose in round 20 (R0) while the button stays one button: nothing slides in from the side, which was your complaint about F0. F3 is exactly R1 (plain glass, red ■) if the red capsule itself is what made R0 feel wrong; the flood reads as a flash at full speed.",
                summary: \.summary),
            .of("grow", "Time", LabRMGrow.self, default: .fadeAfter,
                question: "Run Until stopped in each option and watch the right edge. How should the capsule grow and the time appear?",
                recommend: .fadeAfter,
                why: "The edge moves on its own first and the time fades into space that is already there, so nothing is squeezed while it moves; that's the difference from R0 and R3, where the words pushed the edge. W4 is R1's calm (nothing ever widens) but loses the time you picked. Rolling digits every second is more motion than a toolbar wants.",
                summary: \.summary),
            .of("curve", "Curve", LabRMCurve.self, default: .staged,
                question: "Run the 3 s query several times at Default and Fast. Which timing feels smoothest?",
                recommend: .staged,
                why: "Changing the icon and colour first, then the width, means only one thing moves at a time, and nothing overshoots. The house spring's bounce is what makes today's edge look jumpy; smooth without staging moves three things at once.",
                summary: \.summary),
            .of("ending", "Ending", LabRMEnding.self, default: .together,
                question: "Let a 3 s query finish in each option. How should it go back?",
                recommend: .together,
                why: "One movement back, with the ✓ you chose (E1) drawing as the red drains. Shrinking first adds a beat where the button is empty; running the morph backwards drops the ✓ you picked.",
                summary: \.summary),
            .of("compare", "Compare", LabRMCompare.self, default: .morph),
            .of("speed", "Speed", LabSpeed.self, default: .standard),
        ],
        actions: [
            .init(id: "quick", title: "0.3 s", symbol: "hare") { _ in simulation.start(nil, seconds: 0.3, outcome: .success) },
            .init(id: "medium", title: "3 s", symbol: "gauge.with.dots.needle.67percent") { _ in simulation.start(nil, seconds: 3, outcome: .success) },
            .init(id: "manual", title: "Until stopped", symbol: "tortoise") { _ in simulation.start(nil, seconds: nil, outcome: .success) },
            .init(id: "fails", title: "Fails after 2 s", symbol: "exclamationmark.triangle") { _ in simulation.start(nil, seconds: 2, outcome: .failure) },
            .init(id: "stop", title: "Stop", symbol: "stop.fill") { _ in simulation.cancel() },
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "Round 20 as built: the plain ▶ is swapped for the system's red prominent button with ■ and the time, which slides in beside it.",
                  isEchoToday: true, designWidth: LabRMToolbarExhibit.width, designHeight: LabRMToolbarExhibit.height) { values in
                LabRMToolbarExhibit(options: .today, values: values)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls.",
                  designWidth: LabRMToolbarExhibit.width, designHeight: LabRMToolbarExhibit.height) { values in
                LabRMToolbarExhibit(options: LabRMOptions(values: values), values: values)
            },
            .init(id: "slow", title: "Slow motion",
                  summary: "The proposal four times the size and four times slower. For M2 and M3, drag the scrubber through ▶ to ■.",
                  designWidth: LabRMSlowMotionExhibit.width, designHeight: LabRMSlowMotionExhibit.height) { values in
                LabRMSlowMotionExhibit(options: LabRMOptions(values: values))
            },
            .init(id: "compare", title: "Side by side",
                  summary: "Every choice of the control named in Compare, all running the same query.",
                  designWidth: LabRMGalleryExhibit.width, designHeight: LabRMGalleryExhibit.height) { values in
                LabRMGalleryExhibit(rows: (LabRMCompare(rawValue: values["compare"]) ?? .morph).rows(LabRMOptions(values: values)), values: values)
            },
        ],
        questions: [
            .init(id: "build", title: "Building it in the real toolbar",
                  question: "The toolbar draws its own glass around Run. To change one capsule smoothly, Echo has to draw the red itself instead of switching to the system's prominent button. Is that acceptable?",
                  choices: [
                      .init(id: "draw", name: "Y · Draw the red inside the toolbar's glass", summary: "What the proposal shows; the red is Echo's, the glass is the system's."),
                      .init(id: "system", name: "N · Keep the system's prominent button", summary: "Only the icon morphs; the button swap stays."),
                  ],
                  recommended: "draw",
                  why: "The swap is exactly what you didn't like, and it comes from the system replacing one button with another. Drawing the red ourselves keeps it one button. check: the tint must match the system's prominent red in light, dark and Increase Contrast; I'll compare them side by side in Echo."),
        ],
        exhibitTopic: ("Which change?",
                       "Run the same queries in Echo today and the Proposal, and scrub the slow motion. Is the proposal what you meant?",
                       "proposal",
                       "One button that stays put: ▶ is replaced by ■ in place, as in R1, while the capsule turns red; then the edge moves out and the time fades in, with no bounce; at the end the red drains as the ✓ draws."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "R1's in-place change with R0's red and time: M1, F1, W1, K2, B0.",
                  values: ["morph": LabRMMorph.replace.rawValue, "fill": LabRMFill.fade.rawValue, "grow": LabRMGrow.fadeAfter.rawValue,
                           "curve": LabRMCurve.staged.rawValue, "ending": LabRMEnding.together.rawValue],
                  isRecommended: true),
            .init(id: "r1", name: "Exactly round 20's R1", summary: "In place, plain glass, red ■, no time in the capsule.",
                  values: ["morph": LabRMMorph.replace.rawValue, "fill": LabRMFill.plain.rawValue, "grow": LabRMGrow.noTime.rawValue,
                           "curve": LabRMCurve.smooth.rawValue, "ending": LabRMEnding.together.rawValue]),
            .init(id: "shape", name: "Shape morph", summary: "The tip splits into a square, red fades in, then the time.",
                  values: ["morph": LabRMMorph.corners.rawValue, "fill": LabRMFill.fade.rawValue, "grow": LabRMGrow.fadeAfter.rawValue,
                           "curve": LabRMCurve.staged.rawValue, "ending": LabRMEnding.together.rawValue]),
            .init(id: "today", name: "Like Echo today", summary: "M0, F0, W0, K0, B0.",
                  values: ["morph": LabRMMorph.swap.rawValue, "fill": LabRMFill.swap.rawValue, "grow": LabRMGrow.swap.rawValue,
                           "curve": LabRMCurve.spring.rawValue, "ending": LabRMEnding.together.rawValue]),
            .init(id: "lively", name: "Lively", summary: "Turn and square, red floods, the time slides out.",
                  values: ["morph": LabRMMorph.turn.rawValue, "fill": LabRMFill.flood.rawValue, "grow": LabRMGrow.slideOut.rawValue,
                           "curve": LabRMCurve.spring.rawValue, "ending": LabRMEnding.together.rawValue]),
            .init(id: "symbols", name: "SF Symbols only", summary: "Draw off and on, fade, digits roll.",
                  values: ["morph": LabRMMorph.draw.rawValue, "fill": LabRMFill.fade.rawValue, "grow": LabRMGrow.roll.rawValue,
                           "curve": LabRMCurve.smooth.rawValue, "ending": LabRMEnding.shrinkFirst.rawValue]),
        ]
    )
}
