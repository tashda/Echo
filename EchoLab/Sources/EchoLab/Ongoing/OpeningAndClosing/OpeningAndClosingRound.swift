import SwiftUI

/// Round 48 · Opening, connecting and closing the last tab. The owner, running Echo: (1) the
/// welcome should lose the word Echo and keep only the mark, animated like the website's hero;
/// (2) connecting shoves the welcome to the right and the server's page appears with no
/// animation at all; (3) opening a tab is fine as it is, but closing the last tab lands on the
/// welcome instead of the page of the server that is still connected.
///
/// From the code: (2) is the shell giving the tree its space in the same layout pass that swaps the
/// canvas page (WorkspaceShell, WorkspaceTabContainerView's `.transition(.opacity)`); (3) is
/// `AppDirector+TabDelegate.tabStore(_:didRemoveTabID:)`, which sets `activeSessionID = nil` when no
/// tab is left, so `WorkspaceTabContainerView` shows the welcome. The mark's motion is
/// echodb.dev's `Mark.astro`. Changes the welcome and server page rules of the Window and cards area.
///
/// Accepted 2026-10-01 with every recommendation except LV2 (the owner chose the pills echoing out
/// on connect). Built into Echo: WelcomeMark, WelcomeMarkMotion, WorkspaceShell+WelcomeDeparture.
@MainActor
enum OpeningAndClosingRound {
    private static let width: CGFloat = 720

    static let spec = RoundSpec(
        controls: [
            .of("mark", "Mark", LabOCMarkStyle.self, default: .echo,
                question: "Press Launch under the Proposal, and watch the four marks in the third exhibit. How should the welcome's mark appear?",
                recommend: .echo,
                why: "You asked for the website's echo, and WM2 is exactly its Mark.astro (same geometry, 0.9 s overshoot curve, 0.12 s stagger), so the website and the app open with the same gesture. WM3's ghosts are the idea made literal but read as a smear on a 120pt mark; WM1 is clean but gives you nothing to see on the one screen that opens every session.",
                summary: \.summary),
            .of("rest", "Buttons and recents", LabOCRest.self, default: .rise,
                question: "With the mark you chose, play Launch again. Should the buttons and the recents wait for the mark?",
                recommend: .rise,
                why: "If the mark flies in while everything else is already there, the eye splits between two things; letting the mark finish first, then the buttons and recents rising 0.15 s apart, gives the screen an order. It costs 0.8 s before the buttons settle, and they are clickable (and visible) during the last half of it.",
                summary: \.summary),
            .of("leave", "Welcome on connect", LabOCLeave.self, default: .pillsOut,
                question: "Press Connect, and look at where the welcome goes. How should it leave?",
                recommend: .stays,
                why: "The shove is a side effect of the canvas shrinking, not a design: cancelling it (LV1) is the smallest change that stops the welcome moving and costs no time. LV2 is the most on-brand (the mark echoes out) but every connect waits 0.4 s for a screen you are leaving; connects are frequent and the server is already there.",
                summary: \.summary),
            .of("columns", "Rail and tree", LabOCColumns.self, default: .railFirst,
                question: "Watch the rail and the tree during Connect. Should they arrive together?",
                recommend: .railFirst,
                why: "The rail's new server is the answer to what you just did; the tree is its consequence. Showing them 0.12 s apart gives the click a visible effect before the layout changes, and the tree then reads as coming from the server. Together is simpler and already how Echo animates showing the tree (⌃⌘S); the gain here is small, so this is the closest call.",
                summary: \.summary),
            .of("arrive", "Server page", LabOCArrive.self, default: .cascade,
                question: "Press Connect again and watch the server's page. How should it arrive?",
                recommend: .cascade,
                why: "Today it fades in with the columns and you see nothing happen. Building it up (name, version, tools, databases, 0.06 s apart, 0.4 s in all) shows the page being made for this server and ends when the columns do. AR1 leaves the canvas empty for half a second, which feels like a stall.",
                summary: \.summary),
            .of("closeWhere", "After the last tab", LabOCCloseWhere.self, default: .serverPage,
                question: "Press Open a tab, then Close the tab. Where should you land?",
                recommend: .serverPage,
                why: "You asked for it, and the rail agrees: the server is still connected and selected there, so a welcome page (which says nothing is connected) contradicts it. The welcome stays for when no server is connected at all. The fix is to stop clearing the active session when the last tab closes.",
                summary: \.summary),
            .of("closeHow", "Closing animation", LabOCCloseHow.self, default: .reveal,
                question: "Close the tab with each choice. How should the page come back?",
                recommend: .reveal,
                why: "You are fine with a tab opening instantly, and closing is the same weight: the card lifting away to a page that was there all along (0.28 s) matches it. CH2 replays the build-up on every close, which is 0.6 s of waiting for a page you have seen; CH0 is Echo today and its cross-fade is the one thing you can't see happen.",
                summary: \.summary),
            .of("speed", "Speed", LabOCSpeed.self, default: .normal),
        ],
        actions: [
            .init(id: "play", title: "Play the story", symbol: "play.fill") { values in values["pulse"] = UUID().uuidString },
            .init(id: "marks", title: "Replay the marks", symbol: "arrow.counterclockwise") { values in values["markPulse"] = UUID().uuidString },
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "Mark and name, the welcome pushed right as the columns slide in, the page there at once, and closing the last tab landing on the welcome. Press Play the story, or a step.",
                  isEchoToday: true, designWidth: width, designHeight: 460) { values in
                LabOCStory(look: .today(values), pulse: values["pulse"])
            },
            .init(id: "proposal", title: "Proposal",
                  summary: "Built from the controls. The same story: launch, connect, open a tab (unchanged), close it.",
                  designWidth: width, designHeight: 460) { values in
                LabOCStory(look: LabOCLook(values), pulse: values["pulse"])
            },
            .init(id: "marks", title: "The marks, side by side",
                  summary: "The four welcome marks. Click one, or Replay the marks, to see it play again.",
                  designWidth: width, designHeight: 250) { values in
                LabOCMarksExhibit(slow: values["speed"] == LabOCSpeed.slow.rawValue, pulse: values["markPulse"])
            },
            .init(id: "timing", title: "Timing",
                  summary: "When each part moves, in seconds after the click. Echo today in grey above the proposal; blue is movement, grey fading, green a page building up.",
                  designWidth: width, designHeight: 600) { values in
                LabOCTimelineExhibit(look: LabOCLook(values))
            },
        ],
        questions: [
            .init(id: "plays", title: "When the mark plays",
                  question: "The welcome appears when the app opens, and again whenever the last server is disconnected. Should the mark echo in each time?",
                  choices: [.init(id: "every", name: "Every time the welcome appears"),
                            .init(id: "launch", name: "Only when the app opens")],
                  recommended: "every",
                  why: "The welcome is only ever on screen when nothing is connected, which is rare, so replaying is a nicety rather than a nag, and it needs no memory of whether it already played. Launch-only means a second welcome in the same session that looks different from the first."),
        ],
        exhibitTopic: ("Which opening?", "Judged against Echo today, are the proposal's three moments (launch, connect, closing the last tab) what Echo should do?", "proposal",
                       "The mark echoes in like the website, connecting stops shoving the welcome and builds the server's page, and closing the last tab returns to that page instead of the welcome."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "The website's echo, the page builds up, a quick reveal on close.",
                  values: ["mark": LabOCMarkStyle.echo.rawValue, "rest": LabOCRest.rise.rawValue, "leave": LabOCLeave.stays.rawValue,
                           "columns": LabOCColumns.railFirst.rawValue, "arrive": LabOCArrive.cascade.rawValue,
                           "closeWhere": LabOCCloseWhere.serverPage.rawValue, "closeHow": LabOCCloseHow.reveal.rawValue],
                  isRecommended: true),
            .init(id: "quiet", name: "Quiet", summary: "No echo; only the bugs fixed and a soft fade.",
                  values: ["mark": LabOCMarkStyle.still.rawValue, "rest": LabOCRest.atOnce.rawValue, "leave": LabOCLeave.stays.rawValue,
                           "columns": LabOCColumns.together.rawValue, "arrive": LabOCArrive.fadeAfter.rawValue,
                           "closeWhere": LabOCCloseWhere.serverPage.rawValue, "closeHow": LabOCCloseHow.crossfade.rawValue]),
            .init(id: "echo", name: "Echo everywhere", summary: "The echo in and out, ghosts, and the page builds up on every return.",
                  values: ["mark": LabOCMarkStyle.ghosts.rawValue, "rest": LabOCRest.rise.rawValue, "leave": LabOCLeave.pillsOut.rawValue,
                           "columns": LabOCColumns.railFirst.rawValue, "arrive": LabOCArrive.cascade.rawValue,
                           "closeWhere": LabOCCloseWhere.serverPage.rawValue, "closeHow": LabOCCloseHow.cascade.rawValue]),
        ]
    )
}
