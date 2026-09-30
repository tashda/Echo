import SwiftUI

/// Round 20 · Run button, page 2: what Run does while a query runs and when it ends, including
/// how quick queries are kept from making the button expand and snap back. The proposal takes its
/// look at rest from page 1. Changes EDT-4.3 and EDT-4.4.
@MainActor
enum RunButtonRunningRound {
    private static var simulation: LabRBSimulation { .shared }

    static let spec = RoundSpec(
        controls: [
            .of("running", "Running look", LabRBRunning.self, default: .redProminent,
                question: "Run the 4 s and Until stopped scenarios and try to cancel in each option (or Compare: Running looks). How should Run look while a query runs?",
                recommend: .redProminent,
                why: "You decided it in round 15: the biggest, reddest target is what you want when a runaway query must stop, and the timer shows it's alive. ■ only and the ring keep the width but hide the time; plain glass is too quiet to find in a hurry; accent reads as selected, not running.",
                summary: \.summary),
            .of("delay", "Delay", LabRBDelay.self, default: .stopThenTimer2,
                question: "Run the 0.2 s, 0.8 s and Several in a row scenarios, then 4 s, in each option (Compare: Delays shows them all at once). Which keeps quick queries calm without hiding a long one?",
                recommend: .stopThenTimer2,
                why: "■ appears the moment you run, so you can always cancel and nothing widens; the red capsule and timer arrive only for queries worth timing, so the many sub-second runs never make the toolbar jump. Waiting before any change (G1, G2) leaves a moment where the button looks idle but a click cancels; G4 hides the time too long.",
                summary: \.summary),
            .of("timer", "Timer", LabRBTimerFormat.self, default: .seconds,
                question: "Run Until stopped and watch the first ten seconds. Which timer reads best?",
                recommend: .seconds,
                why: "“5 s” is what you say out loud and is narrower than 0:05 under a minute; after a minute it becomes 1:05. Tenths flicker constantly in the corner of your eye.",
                summary: nil),
            .of("stopIcon", "Stop icon", LabRBStopIcon.self, default: .stopFill,
                question: "Run a query and look at the stop symbol in each option. Which says Cancel?",
                recommend: .stopFill,
                why: "■ pairs with ▶ everywhere (Xcode, media players). The circled one is heavier than every other glyph in the toolbar; □ reads as a checkbox; ✕ means close, not stop."),
            .of("motion", "Motion while running", LabRBRunningMotion.self, default: .still,
                question: "Run Until stopped and leave it for ten seconds. Should anything move besides the timer?",
                recommend: .still,
                why: "The timer ticking already says it's alive. Breathing, pulsing or a sweep through a ten-minute query is motion you can't turn away from; with Reduce Motion they all stop anyway."),
            .of("change", "Change into running", LabRBChange.self, default: .morph,
                question: "Run the 4 s scenario a few times in each option at Default and Fast speed. How should ▶ become the running look and back?",
                recommend: .morph,
                why: "The glass stretches into the red capsule, so it reads as the same button changing rather than one swapped for another. The real toolbar draws its own glass, so this needs a check in Echo; if the toolbar can't morph, A0 is the fallback. Blur and push add motion that says nothing.",
                summary: \.summary),
            .of("result", "Result", LabRBResult.self, default: .drawn,
                question: "Run a query that succeeds and one that fails (Fails at once) in each option. What should Run show when it ends?",
                recommend: .drawn,
                why: "Same meaning as today and nothing widens, but the ✓ draws itself, so the moment reads as done even from the corner of your eye. Rows and time duplicate the inline result and widen the capsule; the flash tints the whole group; nothing at all hides a failure in a long script.",
                summary: \.summary),
            .of("hold", "Result hold", LabRBHold.self, default: .today,
                question: "Let a result show in each option without touching anything. How long should ✓ or ! stay?",
                recommend: .today,
                why: "Long enough to catch at a glance; the inline result and the footer keep the detail. Keeping ! until the next run is a close second, as it's the only hint in the toolbar if you looked away, but errors also show on the line (QE3)."),
            .of("compare", "Compare", LabRBCompareRunning.self, default: .running),
            .of("outcome", "The query", LabRunOutcome.self, default: .success),
            .of("length", "Takes", LabRBLength.self, default: .medium),
            .of("speed", "Speed", LabSpeed.self, default: .standard),
        ],
        actions: [
            .init(id: "run", title: "Run or cancel", symbol: "play.fill") { values in
                syncKnobs(values)
                simulation.toggle()
            },
            .init(id: "instant", title: "0.2 s", symbol: "hare") { _ in simulation.start(nil, seconds: 0.2, outcome: .success) },
            .init(id: "short", title: "0.8 s", symbol: "gauge.with.dots.needle.33percent") { _ in simulation.start(nil, seconds: 0.8, outcome: .success) },
            .init(id: "slow", title: "4 s", symbol: "gauge.with.dots.needle.67percent") { _ in simulation.start(nil, seconds: 4, outcome: .success) },
            .init(id: "manual", title: "Until stopped", symbol: "tortoise") { _ in simulation.start(nil, seconds: nil, outcome: .success) },
            .init(id: "failsAtOnce", title: "Fails at once", symbol: "exclamationmark.triangle") { _ in simulation.start(nil, seconds: 0.15, outcome: .failure) },
            .init(id: "failsLate", title: "Fails after 3 s", symbol: "exclamationmark.octagon") { _ in simulation.start(nil, seconds: 3, outcome: .failure) },
            .init(id: "several", title: "Several in a row", symbol: "repeat") { _ in simulation.runSeveral() },
            .init(id: "cancelQuickly", title: "Cancel after 0.5 s", symbol: "xmark.circle") { _ in simulation.runAndCancelQuickly() },
            .init(id: "finish", title: "Finish now", symbol: "flag.checkered") { _ in simulation.finish() },
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "Red prominent glass with ■ and 0:05 at once, even for a 0.2 s query; ✓ or ! for 2.4 s; a cancel settles straight back.",
                  isEchoToday: true, designWidth: LabRBToolbarExhibit.width, designHeight: LabRBToolbarExhibit.height) { values in
                LabRBToolbarExhibit(look: .today, values: values).onAppear { syncKnobs(values) }
            },
            .init(id: "proposal", title: "Proposal",
                  summary: "Built from this page's controls, at rest as page 1 sets it.",
                  designWidth: LabRBToolbarExhibit.width, designHeight: LabRBToolbarExhibit.height) { values in
                LabRBToolbarExhibit(look: .proposal(), values: values)
                    .onChange(of: values["outcome"]) { _, _ in syncKnobs(values) }
                    .onChange(of: values["length"]) { _, _ in syncKnobs(values) }
            },
            .init(id: "compare", title: "Side by side",
                  summary: "Every choice of the control named in Compare, all running the same query. Use the scenarios to see them diverge.",
                  designWidth: LabRBGalleryExhibit.width, designHeight: LabRBGalleryExhibit.height) { values in
                LabRBGalleryExhibit(rows: (LabRBCompareRunning(rawValue: values["compare"]) ?? .running).rows(.proposal()), values: values)
            },
        ],
        questions: [
            .init(id: "background", title: "Running in another tab",
                  question: "A query runs in Query 2 while you edit Query 1. Should Query 1's Run say so?",
                  choices: [
                      .init(id: "nothing", name: "B0 · No (today)", summary: "Query 2's tab shows its spinner; Run belongs to this tab."),
                      .init(id: "dot", name: "B1 · A small dot on Run", summary: "Something is running elsewhere; the tooltip says where."),
                      .init(id: "count", name: "B2 · A count badge", summary: "The number of queries running in this window."),
                  ],
                  recommended: "nothing",
                  why: "Run acts on this tab only, and the tab strip already shows a spinner on the running tab (and the tab overview lists it). A badge on Run suggests clicking it affects the other query."),
            .init(id: "cancelled", title: "After a cancel",
                  question: "Use Cancel after 0.5 s. What should Run show once the query has stopped?",
                  choices: [
                      .init(id: "back", name: "Z0 · Straight back to ▶ (today)"),
                      .init(id: "mark", name: "Z1 · A grey ✕ for a moment", summary: "Confirms the cancel took, as the server may take a moment to stop."),
                  ],
                  recommended: "back",
                  why: "You pressed ■ yourself, so you know; the footer says Cancelled. A grey ✕ would help only if cancelling were slow, which the delay (■ at once) already makes visible."),
            .init(id: "done", title: "Long query finishes while you're away",
                  question: "A query ran for minutes and you switched to another app. How should you learn it finished?",
                  choices: [
                      .init(id: "toast", name: "N0 · The toast and history (today)", summary: "Echo's notification toast when you come back."),
                      .init(id: "system", name: "N1 · A system notification after 30 s", summary: "macOS Notification Center, only when Echo isn't in front."),
                      .init(id: "badge", name: "N2 · The Dock icon bounces once"),
                  ],
                  recommended: "system",
                  why: "Run's ✓ is gone after 2.4 s and you weren't looking. A system notification for queries over 30 s, only while Echo is in the background, is how Xcode and Terminal report long builds; a bouncing Dock icon is loud and says nothing about which query."),
        ],
        exhibitTopic: ("Which running Run?",
                       "Run every scenario in both toolbars. Is the proposal better than Echo today?",
                       "proposal",
                       "Quick queries no longer make the red capsule flash open and shut, the timer arrives only when it means something, the glass morphs instead of swapping, and the ✓ draws itself. What you decided in round 15 (red, ■, the timer) stays."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "R0, G3, 5 s, ■, still, morph, drawn ✓, 2.4 s.",
                  values: ["running": LabRBRunning.redProminent.rawValue, "delay": LabRBDelay.stopThenTimer2.rawValue,
                           "timer": LabRBTimerFormat.seconds.rawValue, "stopIcon": LabRBStopIcon.stopFill.rawValue,
                           "motion": LabRBRunningMotion.still.rawValue, "change": LabRBChange.morph.rawValue,
                           "result": LabRBResult.drawn.rawValue, "hold": LabRBHold.today.rawValue],
                  isRecommended: true),
            .init(id: "today", name: "Like Echo today", summary: "Every control as Echo runs now.",
                  values: ["running": LabRBRunning.redProminent.rawValue, "delay": LabRBDelay.atOnce.rawValue,
                           "timer": LabRBTimerFormat.clock.rawValue, "stopIcon": LabRBStopIcon.stopFill.rawValue,
                           "motion": LabRBRunningMotion.still.rawValue, "change": LabRBChange.replace.rawValue,
                           "result": LabRBResult.glyph.rawValue, "hold": LabRBHold.today.rawValue]),
            .init(id: "fixedWidth", name: "Never widens", summary: "■ in a spinning ring, the time in the tooltip, drawn ✓.",
                  values: ["running": LabRBRunning.ring.rawValue, "delay": LabRBDelay.atOnce.rawValue,
                           "timer": LabRBTimerFormat.seconds.rawValue, "stopIcon": LabRBStopIcon.stopFill.rawValue,
                           "motion": LabRBRunningMotion.still.rawValue, "change": LabRBChange.magic.rawValue,
                           "result": LabRBResult.drawn.rawValue, "hold": LabRBHold.today.rawValue]),
            .init(id: "quiet", name: "Quiet", summary: "Plain glass with a red ■ and the time after a second; no result.",
                  values: ["running": LabRBRunning.quietTimer.rawValue, "delay": LabRBDelay.afterSecond.rawValue,
                           "timer": LabRBTimerFormat.seconds.rawValue, "stopIcon": LabRBStopIcon.stopFill.rawValue,
                           "motion": LabRBRunningMotion.still.rawValue, "change": LabRBChange.replace.rawValue,
                           "result": LabRBResult.none.rawValue, "hold": LabRBHold.today.rawValue]),
            .init(id: "loud", name: "Loud", summary: "Red capsule at once, breathing ■, a flash, errors stay.",
                  values: ["running": LabRBRunning.redProminent.rawValue, "delay": LabRBDelay.atOnce.rawValue,
                           "timer": LabRBTimerFormat.tenths.rawValue, "stopIcon": LabRBStopIcon.stopFill.rawValue,
                           "motion": LabRBRunningMotion.breathe.rawValue, "change": LabRBChange.push.rawValue,
                           "result": LabRBResult.flash.rawValue, "hold": LabRBHold.errorsStay.rawValue]),
            .init(id: "tab", name: "Like a tab", summary: "A spinner that becomes ■ on hover; rows and time after.",
                  values: ["running": LabRBRunning.spinner.rawValue, "delay": LabRBDelay.afterQuarter.rawValue,
                           "timer": LabRBTimerFormat.seconds.rawValue, "stopIcon": LabRBStopIcon.stopFill.rawValue,
                           "motion": LabRBRunningMotion.still.rawValue, "change": LabRBChange.blur.rawValue,
                           "result": LabRBResult.rows.rawValue, "hold": LabRBHold.long.rawValue]),
        ]
    )

    /// The Takes and The query knobs set what Run or cancel (and a click on any Run) does.
    private static func syncKnobs(_ values: RoundValues) {
        simulation.outcome = LabRunOutcome(rawValue: values["outcome"]) ?? .success
        simulation.length = LabRBLength(rawValue: values["length"]) ?? .medium
    }
}
