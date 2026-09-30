import SwiftUI

/// Round 18 · Notification toast: everything about the toast itself, Echo today beside a proposal
/// built from the controls. Touches NTF-1.1 to 1.6, NTF-2.1 to 2.2 and NTF-3.1 to 3.6.
@MainActor
enum NotificationToastRound {
    private static let width: CGFloat = 520
    private static let height: CGFloat = 420

    static let spec = RoundSpec(
        controls: [
            .of("layout", "Layout", NTLayout.self, default: .titleDetail,
                question: "Post Query failed and Long error. Which layout tells you what happened without hovering?",
                recommend: .titleDetail,
                why: "The bold title with the reason under it matches the history's cards and shows why a query failed at a glance. One line hides the reason; the pill hides even the title's end; the server line is rarely needed."),
            .of("actions", "Actions", NTActions.self, default: .smallButtons,
                question: "Hover a toast. How should Open Tab, Copy and Show All look?",
                recommend: .smallButtons,
                why: "You chose small buttons for the history (round 17); the toast should speak the same language. Text links look like body text; icons need their tooltips."),
            .of("dismiss", "Dismiss", NTDismiss.self, default: .swipe,
                question: "Get rid of a toast in each way. Which feels natural?",
                recommend: .swipe,
                why: "Flicking it to the right is how macOS banners go away, and × still appears on hover for the pointer. An × always showing adds noise; clicking anywhere dismisses by accident."),
            .of("material", "Material", NTMaterial.self, default: .glass,
                question: "Post a success and an error over the editor, in light and dark. Which surface?",
                recommend: .glass,
                why: "Toasts float over content, and floating controls are glass (decided). Tinting repeats the icon's colour over the whole toast; an opaque card looks like part of the editor."),
            .of("arrival", "Arrival", NTArrival.self, default: .drop,
                question: "Post several. How should a toast arrive?",
                recommend: .drop,
                why: "They sit just below the tab bar, so dropping from above reads as coming from the window's chrome. Growing from the corner is a close second; sliding from the edge travels furthest."),
            .of("stacking", "Stacking", NTStacking.self, default: .deck,
                question: "Post four quickly, then hover the stack. How should several toasts share the corner?",
                recommend: .deck,
                why: "Three full toasts cover a big piece of the editor. A deck shows the newest with the others peeking behind and fans out on hover, like Notification Center; newest-only hides that more happened."),
            .of("duration", "Duration", NTDuration.self, default: .five,
                question: "Post a success and don't touch it. Does it stay long enough to read?",
                recommend: .five,
                why: "Three seconds is too short to read a title and a reason; macOS banners stay about five. Errors stay until dismissed in every option."),
            .of("speed", "Speed", LabSpeed.self, default: .standard),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "One line, text links on hover, × on hover, glass, dropping from the top, a list of three, 3 s.",
                  isEchoToday: true, designWidth: width, designHeight: height) { _ in
                NTExhibit(options: .today)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls.",
                  designWidth: width, designHeight: height) { values in
                NTExhibit(options: NTOptions(values: values))
                    .id(NTOptions(values: values).stacking.rawValue + NTOptions(values: values).layout.rawValue)
            },
        ],
        exhibitTopic: ("Which toast?", "Post the same events in both, hover them and dismiss them. Is the proposal better than Echo today?",
                       "proposal",
                       "It keeps the corner, glass and drop you already have, but shows the reason without hovering, uses the history's buttons, goes away with a flick, stacks as a deck and stays long enough to read."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "L2, A2, D3, M1, E1, S2, T2.",
                  values: ["layout": NTLayout.titleDetail.rawValue, "actions": NTActions.smallButtons.rawValue,
                           "dismiss": NTDismiss.swipe.rawValue, "material": NTMaterial.glass.rawValue,
                           "arrival": NTArrival.drop.rawValue, "stacking": NTStacking.deck.rawValue,
                           "duration": NTDuration.five.rawValue],
                  isRecommended: true),
            .init(id: "today", name: "Like Echo today", summary: "L1, A1, D1, M1, E1, S1, T1.",
                  values: ["layout": NTLayout.oneLine.rawValue, "actions": NTActions.textLinks.rawValue,
                           "dismiss": NTDismiss.hoverX.rawValue, "material": NTMaterial.glass.rawValue,
                           "arrival": NTArrival.drop.rawValue, "stacking": NTStacking.list.rawValue,
                           "duration": NTDuration.three.rawValue]),
        ]
    )
}
