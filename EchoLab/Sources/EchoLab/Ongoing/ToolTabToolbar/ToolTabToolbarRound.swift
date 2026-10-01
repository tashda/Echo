import SwiftUI

/// Round 37.5 · Tool tabs: the tab's own buttons in the toolbar. The owner: whenever a tab has
/// dedicated buttons they go in the window toolbar, at the right, to the left of the window's
/// icons, and they should show that they belong to the tab in front; the query editor has several
/// groups, and Run is special and may look like a regular button. This reverses round 45 (tool
/// actions in the tab). Echo today (WorkspaceToolbarItems): a query tab shows Run in its own
/// capsule that turns red (round 24), Format · Validate · Help · Plan, and SQLCMD · Statistics for
/// SQL Server, each a plain glass group that hides when another tab is in front; tools put their
/// buttons on their header line (37.2, 37.3) and nothing in the toolbar (45).
@MainActor
enum ToolTabToolbarRound {
    private static func look(_ v: RoundValues) -> LabTBLook { LabTBLook.from(v) }
    private static let strip: [LabTBTab] = [.query, .profiler, .policy]

    static let spec = RoundSpec(
        controls: [
            .of("tie", "Tie to the tab", LabTBTie.self, default: .iconTray,
                question: "Switch between the ties on the Proposals and in 'Every tie'. Which makes the buttons read as the front tab's, without shouting?",
                recommend: .iconTray,
                why: "The grey tray is the tab bar's own plate, so the section reads as part of the tabs rather than the window, and the tab's symbol (the same one as in its tab) says which tab. TT2, the symbol alone, is the quiet runner-up; TT4's white plate is the most literal but fights the glass around it, and TT5's name costs up to 120pt.",
                summary: \.summary),
            .of("groups", "Several groups", LabTBGroups.self, default: .dividers,
                question: "Look at the query tab, which has three groups. How should a tab with more than one group show them?",
                recommend: .dividers,
                why: "Inside a tray, three separate capsules make a crowded row of bubbles; one capsule with short hairlines keeps the groups apart and the section one piece. GR2's melted glass looks the same at rest and only differs in motion; GR3 hides Format and Plan behind a click."),
            .of("run", "Run", LabTBRun.self, default: .plain,
                question: "Set State to Running and compare the three Runs, in the Proposal and in 'Every Run'.",
                recommend: .plain,
                why: "You suggested Run could look like a regular button: as the first symbol in the tab's group it is one of the tab's buttons, and running still shows, the ▶ becoming a red ■. It costs round 24's red capsule, which is easier to spot across the room; RN0 keeps it if you miss that."),
            .of("move", "What moves", LabTBMove.self, default: .buttons,
                question: "Look at SQL Profiler and Error Log. What leaves the header line for the toolbar?",
                recommend: .buttons,
                why: "You asked for the dedicated buttons; a picker and a search field are how you look at the tab's content, so they stay next to it on the header line. MV0 empties the header to a name but puts a search field in the window toolbar, where macOS keeps the window's own search."),
            .of("mainLook", "Main action", LabTBMainLook.self, default: .word,
                question: "Compare SQL Profiler's Start Trace as a symbol and with its word.",
                recommend: .word,
                why: "You accepted the worded glass capsule in 37.3, and Start Trace, New Backup or Pause are not obvious from a symbol; one word per tab is affordable. MA0 is the pick if every toolbar button should be a symbol."),
            .of("gap", "Gap", LabTBGap.self, default: .fixed,
                question: "Look at the space between the tab's section and the window's icons.",
                recommend: .fixed,
                why: "With a tray or the tab's symbol the section is already set apart; the toolbar's own gap keeps the right side as compact as today. The hairline is for TT0 to TT2, where nothing else separates them."),
            .of("motion", "Switching", LabTBMotion.self, default: .morph,
                question: "Click through the tabs in 'Switching tabs' with each motion.",
                recommend: .morph,
                why: "The tray is one piece that only changes its contents, so letting its glass reshape says 'same place, other tab'; it is Liquid Glass's own behaviour. A fade is the safe second; the slide moves too much for something you switch often."),
            .of("state", "State", LabTBState.self, default: .resting),
        ],
        exhibits: [
            .init(id: "todayQuery", title: "Echo today: a query tab", summary: "Run, then two plain glass groups; nothing ties them to the tab.",
                  isEchoToday: true, isWide: true, designWidth: 900, designHeight: 230) { v in
                LabTBWindow(tabs: strip, active: .query, look: { var l = LabTBLook.today; l.running = look(v).running; return l }(), isToday: true)
            },
            .init(id: "todayTool", title: "Echo today: SQL Profiler", summary: "Every control on the header line (37.2, 37.3); nothing in the toolbar (45).",
                  isEchoToday: true, isWide: true, designWidth: 900, designHeight: 230) { v in
                LabTBWindow(tabs: strip, active: .profiler, look: look(v), isToday: true)
            },
            .init(id: "query", title: "Proposal: a query tab", summary: "Run and the editor's two groups, tied to Query 2.",
                  isWide: true, designWidth: 900, designHeight: 230) { v in
                LabTBWindow(tabs: strip, active: .query, look: look(v))
            },
            .init(id: "profiler", title: "Proposal: SQL Profiler", summary: "Start Trace and three buttons; the database picker and filter stay by the name (MV1).",
                  isWide: true, designWidth: 900, designHeight: 230) { v in
                LabTBWindow(tabs: strip, active: .profiler, look: look(v))
            },
            .init(id: "policy", title: "Proposal: Policy Management", summary: "No main action, one group.",
                  isWide: true, designWidth: 900, designHeight: 230) { v in
                LabTBWindow(tabs: [.query, .policy, .activity], active: .policy, look: look(v))
            },
            .init(id: "activity", title: "Proposal: Activity Monitor", summary: "Pause and Refresh; the interval stays by the name.",
                  isWide: true, designWidth: 900, designHeight: 230) { v in
                LabTBWindow(tabs: [.query, .policy, .activity], active: .activity, look: look(v))
            },
            .init(id: "structure", title: "Proposal: the structure editor", summary: "Add Column; Apply stays in its bar at the bottom (37.4).",
                  isWide: true, designWidth: 900, designHeight: 230) { v in
                LabTBWindow(tabs: [.query, .structure], active: .structure, look: look(v))
            },
            .init(id: "errorLog", title: "Proposal: Error Log", summary: "Cycle Log and Refresh; the log picker and search stay by the name.",
                  isWide: true, designWidth: 900, designHeight: 230) { v in
                LabTBWindow(tabs: [.query, .errorLog], active: .errorLog, look: look(v))
            },
            .init(id: "switching", title: "Switching tabs", summary: "Click the tabs; Availability Groups has no buttons of its own.",
                  isWide: true, designWidth: 900, designHeight: 150) { v in
                LabTBSwitching(look: look(v))
            },
            .init(id: "ties", title: "Every tie", summary: "TT0 to TT7 on the query tab, with the other controls as set.",
                  isWide: true, designWidth: 900, designHeight: 520) { v in
                LabTBGallery(kind: .ties, look: look(v))
            },
            .init(id: "groupings", title: "Every way to show several groups", summary: "GR0 to GR3 on the query tab.",
                  isWide: true, designWidth: 900, designHeight: 280) { v in
                LabTBGallery(kind: .groups, look: look(v))
            },
            .init(id: "runs", title: "Every Run", summary: "RN0 to RN2, resting and running.",
                  isWide: true, designWidth: 900, designHeight: 400) { v in
                LabTBGallery(kind: .runs, look: look(v))
            },
        ],
        questions: [
            .init(id: "empty", title: "A tab without buttons",
                  question: "Availability Groups has no buttons of its own. What does the toolbar show while it is in front?",
                  choices: [
                      .init(id: "nothing", name: "EM0 · Nothing: the window's icons only"),
                      .init(id: "mark", name: "EM1 · The tie alone (the tray with the tab's symbol)"),
                  ],
                  recommended: "nothing",
                  why: "An empty tray is a control that does nothing; the section appearing only when there is something to press is what makes it mean 'this tab has buttons'."),
            .init(id: "narrow", title: "A narrow window",
                  question: "When the toolbar runs out of room, what gives way first?",
                  choices: [
                      .init(id: "system", name: "NW0 · The system's » menu, from the left as macOS does"),
                      .init(id: "tabFirst", name: "NW1 · The tab's section folds into ⋯ first, the window's icons stay"),
                  ],
                  recommended: "tabFirst",
                  why: "Search, Overview and the Inspector are what you reach for in any tab; the tab's buttons also have menus and shortcuts, so they are the ones to fold."),
            .init(id: "headerAfter", title: "The header line afterwards",
                  question: "With the buttons in the toolbar, a tool's header line holds its name, subtitle and (MV1) its picker and search. Keep the header line?",
                  choices: [
                      .init(id: "keep", name: "HL0 · Yes: the name and what you look at stay above the content"),
                      .init(id: "thin", name: "HL1 · Only when there is a picker or search; otherwise the tab says the name"),
                  ],
                  recommended: "keep",
                  why: "Every tool keeps the same first line (37.2), and the subtitle (server, 1,204 events) has nowhere else to go."),
            .init(id: "replace45", title: "Round 45",
                  question: "This puts tool buttons back in the toolbar, which round 45 took out. Replace round 45?",
                  choices: [
                      .init(id: "replace", name: "R45-0 · Yes: this round's answer replaces 45"),
                      .init(id: "queryOnly", name: "R45-1 · No: only the query editor uses the toolbar; tools keep 45"),
                  ],
                  recommended: "replace",
                  why: "You asked for every tab's dedicated buttons in the toolbar; one rule for every tab, with the tie saying whose they are, is what makes it learnable."),
        ],
        exhibitTopic: ("Which toolbar?", "Do the Proposals make the buttons read as the front tab's, against Echo today?", "query",
                       "A grey tray in the tab bar's colour, starting with the tab's symbol, holding the tab's buttons in one glass capsule; Run a plain ▶ that turns red."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "TT7, GR1, RN1, MV1, MA1, the fixed gap, the glass reshaping.",
                  values: ["tie": LabTBTie.iconTray.rawValue, "groups": LabTBGroups.dividers.rawValue, "run": LabTBRun.plain.rawValue,
                           "move": LabTBMove.buttons.rawValue, "mainLook": LabTBMainLook.word.rawValue, "gap": LabTBGap.fixed.rawValue,
                           "motion": LabTBMotion.morph.rawValue], isRecommended: true),
            .init(id: "quiet", name: "Quietest", summary: "Only the tab's symbol, separate capsules, Run as today.",
                  values: ["tie": LabTBTie.icon.rawValue, "groups": LabTBGroups.separate.rawValue, "run": LabTBRun.capsule.rawValue,
                           "gap": LabTBGap.hairline.rawValue, "motion": LabTBMotion.fade.rawValue]),
            .init(id: "loud", name: "Most literal", summary: "The active tab's white plate under the buttons.",
                  values: ["tie": LabTBTie.plate.rawValue, "groups": LabTBGroups.dividers.rawValue, "run": LabTBRun.lead.rawValue]),
            .init(id: "symbols", name: "All symbols", summary: "Every button a symbol, Run plain.",
                  values: ["mainLook": LabTBMainLook.symbol.rawValue, "run": LabTBRun.plain.rawValue]),
        ]
    )
}
