import SwiftUI

/// Round 44 · The blur under the footer (changes the footer blur, FTR; `LayoutTokens.EdgeBlur`,
/// `BackdropEdgeBlur`). Echo today: ten stacked Gaussian blur layers in the grid's clip view, each a
/// small step towards 12pt, eased in (12 × (k/10)^1.5) over the footer's 38pt plus 24pt, with the
/// card's colour at 35% easing in on top (fb789c41). The owner still sees a band, not a blur that
/// clears smoothly as it goes up. Every exhibit is a real blur of the same AppKit grid.
@MainActor
enum FooterBlurRound {
    static func look(_ technique: LabFBTechnique, _ values: RoundValues) -> LabFBLook {
        LabFBLook(technique: technique,
                  strongest: (LabFBStrength(rawValue: values["strength"]) ?? .twelve).points,
                  reach: (LabFBReach(rawValue: values["reach"]) ?? .tall).points,
                  curve: LabFBCurve(rawValue: values["curve"]) ?? .sCurve,
                  tint: (LabFBTint(rawValue: values["tint"]) ?? .light).opacity,
                  steps: (LabFBSteps(rawValue: values["steps"]) ?? .sixteen).count)
    }

    static func scrolling(_ values: RoundValues) -> Bool {
        (LabFBMotion(rawValue: values["motion"]) ?? .scrolling) == .scrolling
    }

    private static func exhibit(_ technique: LabFBTechnique, id: String, summary: String) -> RoundSpec.Exhibit {
        .init(id: id, title: technique.rawValue, summary: summary,
              designWidth: LabFBSpecimen.width, designHeight: LabFBSpecimen.height) { values in
            LabFBSpecimen(look: look(technique, values), isScrolling: scrolling(values))
        }
    }

    static let spec = RoundSpec(
        controls: [
            .of("motion", "Rows", LabFBMotion.self, default: .scrolling),
            .of("strength", "Strongest blur", LabFBStrength.self, default: .twelve,
                question: "Watch the rows go under the footer. How strong should the blur be at the card's edge?",
                recommend: .twelve,
                why: "12pt turns the rows behind the pills into soft colour without making them a grey wash; 6 and 9 still let you read digits behind the pills, 16 and 20 look like frosted glass."),
            .of("reach", "How high it reaches", LabFBReach.self, default: .tall,
                question: "Look at where the rows start to soften. How far above the footer should it begin?",
                recommend: .tall,
                why: "A blur needs room to fade in, or its top reads as a line: 40pt above the footer is about two rows, so the softening starts gently above the last whole row. 24pt (today) is one row and still shows an edge; 64pt softens rows you are reading."),
            .of("curve", "How it grows", LabFBCurve.self, default: .sCurve,
                question: "Follow one row as it scrolls down into the footer. Which growth feels like one smooth blur?",
                recommend: .sCurve,
                why: "An S curve starts and ends without a corner, so there is no height where the change suddenly starts or stops; easing in leaves a corner at the edge, and holding full strength under the pills makes the band you saw.",
                summary: \.summary),
            .of("tint", "Tint", LabFBTint.self, default: .light,
                question: "Look at the footer's pills over the rows. How much of the card's colour should lie over the blur?",
                recommend: .light,
                why: "The pills are glass and already read on their own; 35% (today) whitens the bottom into a visible band, 15% only keeps busy rows from showing through."),
            .of("steps", "Steps (BT1)", LabFBSteps.self, default: .sixteen,
                question: "Only for Stacked blur steps: how many steps until you can no longer see them?",
                recommend: .sixteen,
                why: "Each step mixes two blurs where it fades in; at 16 the neighbours differ by under a point, which the eye can't separate. 24 costs more layers for no visible gain."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Ten stacked steps to 12pt over the footer and 24pt, 35% tint easing in (fb789c41). Not affected by the controls.",
                  isEchoToday: true, designWidth: LabFBSpecimen.width, designHeight: LabFBSpecimen.height) { values in
                LabFBSpecimen(look: look(.echoToday, values), isScrolling: scrolling(values))
            },
            exhibit(.stacked, id: "stacked", summary: "Echo's way with the controls: Gaussian blur layers, each a small step towards the strongest, faded in along the curve."),
            exhibit(.maskedVariable, id: "maskedVariable", summary: "One blur whose radius follows the curve pixel by pixel, from Core Image's public CIMaskedVariableBlur."),
            exhibit(.material, id: "material", summary: "The system's thinnest material faded in along the curve: frosted, with the material's own tint."),
            exhibit(.fade, id: "fade", summary: "No blur: the rows fade into the card's colour along the curve."),
        ],
        exhibitTopic: ("Which technique?", "Watch each with the rows scrolling, judged against Echo today. Which one blurs the rows away smoothly, with no band?",
                       "maskedVariable",
                       "One blur whose radius changes row by row has no steps, so there is nothing to see as a band: each row is a little softer than the one above. It is public Core Image, one filter instead of ten layers. Stacked steps show where each step fades in; the material and the fade don't blur, they wash the rows out."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "12pt, 40pt above the footer, S curve, 15% tint, 16 steps.",
                  values: ["strength": LabFBStrength.twelve.rawValue, "reach": LabFBReach.tall.rawValue, "curve": LabFBCurve.sCurve.rawValue,
                           "tint": LabFBTint.light.rawValue, "steps": LabFBSteps.sixteen.rawValue],
                  isRecommended: true),
            .init(id: "today", name: "Like Echo today", summary: "12pt, 24pt above the footer, eases in, 35% tint, 10 steps.",
                  values: ["strength": LabFBStrength.twelve.rawValue, "reach": LabFBReach.today.rawValue, "curve": LabFBCurve.easeIn.rawValue,
                           "tint": LabFBTint.today.rawValue, "steps": LabFBSteps.ten.rawValue]),
        ]
    )
}
