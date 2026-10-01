import SwiftUI

/// Round 45 · Tool tabs: the main action in the toolbar. The owner, on 37.3: "New Policy" or
/// "Start Trace / Stop Trace" should live in a separate group in the window toolbar, like the Run
/// button or a + sign; and for the running state, "can't we use the run button in the toolbar?".
/// Echo today (WorkspaceToolbarItems.contextActionItems, TabContextToolbarButton.swift): SQL
/// Profiler's Start Trace is a bordered button in its own toolbar row inside the tab; Activity
/// Monitor's Pause is an eye in the toolbar's tab-tools capsule; Agent Jobs' Start Job is a
/// ToolbarRunButton (▶, red ■) in that capsule, beside Open in Window. Three tools, three places.
/// Drawn with 36.1's TP0 refined strip and 37.2's UH5 header (both recommended, not yet decided).
@MainActor
enum ToolTabMainActionRound {
    static let spec = RoundSpec(
        controls: [
            .of("place", "Main action", LabMAPlace.self, default: .byKindPlain,
                question: "Switch State between Resting and Running and look at the three tools. Where should the main action live?",
                recommend: .byKindPlain,
                why: "You asked for Run or a +: MA3 is exactly that. ▶ in Run's place already means 'start what this tab does' and ⌘↩ already presses it, and + already means 'new' in the tab strip, so nothing new to learn. MA2 is the close second if a bare ▶ feels too vague on a tool (its word costs about 80pt of toolbar); MA0 keeps 37.3's capsule in the header.",
                summary: \.summary),
            .of("running", "Running", LabMARunning.self, default: .run,
                question: "With State on Running, compare the two running looks on SQL Profiler and Activity Monitor.",
                recommend: .run,
                why: "Once the action sits in Run's place it should run like Run: one running look in the toolbar, decided in round 24 (red glass, ■, the time after 3 s). The pulsing dot (ST1) was chosen for a button inside the header; in the toolbar it would be a second way of saying 'running'."),
            .of("state", "State", LabMAState.self, default: .running),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today: SQL Profiler", summary: "Start Trace in a toolbar row inside the tab; nothing in the window toolbar.",
                  isEchoToday: true, isWide: true, designWidth: 860, designHeight: 330) { values in
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    LabMAToolbar(action: nil, place: .header, runningLook: .run, running: false)
                    LabTTTab(tool: .profiler, look: .today, running: isRunning(values))
                }
                .padding(.top, SpacingTokens.sm).padding(.horizontal, SpacingTokens.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(ColorTokens.Workspace.canvas)
            },
            .init(id: "todayOthers", title: "Echo today: Activity Monitor and Agent Jobs", summary: "Pause is an eye, Start Job a ▶, both in the toolbar's tab-tools capsule.",
                  isEchoToday: true, isWide: true, designWidth: 860, designHeight: 120) { _ in
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    LabMAToolbar(action: nil, place: .header, runningLook: .run, running: false, todayExtras: ["eye.fill"])
                    LabMAToolbar(action: nil, place: .header, runningLook: .run, running: false, todayExtras: ["play.fill", "rectangle.portrait.and.arrow.right"])
                }
                .padding(SpacingTokens.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(ColorTokens.Workspace.canvas)
            },
            .init(id: "profiler", title: "Proposal: SQL Profiler", summary: "Start Trace and Stop Trace: something that starts and stops.",
                  isWide: true, designWidth: 860, designHeight: 360) { values in
                LabMAExhibit(tool: .profiler, action: .startTrace, place: place(values), runningLook: runningLook(values), running: isRunning(values))
            },
            .init(id: "policy", title: "Proposal: Policy Management", summary: "New Policy: something that creates.",
                  isWide: true, designWidth: 860, designHeight: 360) { values in
                LabMAExhibit(tool: .policy, action: .newPolicy, place: place(values), runningLook: runningLook(values), running: isRunning(values))
            },
            .init(id: "activity", title: "Proposal: Activity Monitor", summary: "Pause and Resume: a monitor runs from the moment it opens, so running shows ⏸, not red.",
                  isWide: true, designWidth: 860, designHeight: 360) { values in
                LabMAExhibit(tool: .activity, action: .pause, place: place(values), runningLook: runningLook(values), running: isRunning(values))
            },
        ],
        questions: [
            .init(id: "plus", title: "More than one kind of New",
                  question: "Policy Management makes policies and conditions. On its Conditions page, what does + do?",
                  choices: [
                      .init(id: "page", name: "PL0 · Makes what the shown page lists (New Condition); hidden on pages that list nothing you make"),
                      .init(id: "menu", name: "PL1 · Opens a menu of everything the tool can make"),
                  ],
                  recommended: "page",
                  why: "The page already says what you're looking at, so + can act in one click; the tooltip names it (New Condition). A menu costs a click every time for a choice the page made."),
            .init(id: "shortcut", title: "Keyboard",
                  question: "Should ⌘↩ press the tool's ▶ (start and stop), as it runs a query in the editor?",
                  choices: [
                      .init(id: "yes", name: "KS0 · Yes: ⌘↩ presses whatever is in Run's place"),
                      .init(id: "no", name: "KS1 · No: ⌘↩ stays the editor's"),
                  ],
                  recommended: "yes",
                  why: "If it looks like Run and sits where Run sits, it should answer to Run's key; otherwise the button lies about what ⌘↩ does in that tab."),
            .init(id: "others", title: "The toolbar's other tool buttons",
                  question: "Echo puts some tool controls in the toolbar today (Activity Monitor's eye, Maintenance's database picker, Jobs' Open in Window). Where do they go?",
                  choices: [
                      .init(id: "header", name: "TG0 · Into the tool's header line; the toolbar keeps only the main action"),
                      .init(id: "toolbar", name: "TG1 · They stay in the toolbar's tab-tools capsule"),
                  ],
                  recommended: "header",
                  why: "One rule: the toolbar has the one thing you start or make, the header line has how you look at it (pickers, search, other actions, 37.3). Today the database picker is in the toolbar for Maintenance and in the header for Profiler; that split is what looked off."),
        ],
        exhibitTopic: ("Which one?", "Do the proposals put the main action where you expect it, against Echo today?", "profiler",
                       "Run's button and the strip's +, in Run's place in the toolbar: nothing new to learn."),
        presets: [
            .init(id: "recommended", name: "My recommendation", values: ["place": LabMAPlace.byKindPlain.rawValue, "running": LabMARunning.run.rawValue], isRecommended: true),
            .init(id: "words", name: "With words", values: ["place": LabMAPlace.byKindWords.rawValue, "running": LabMARunning.run.rawValue]),
            .init(id: "header", name: "As 37.3 accepted", values: ["place": LabMAPlace.header.rawValue, "running": LabMARunning.dot.rawValue]),
        ]
    )

    private static func place(_ values: RoundValues) -> LabMAPlace { LabMAPlace(rawValue: values["place"]) ?? .byKindPlain }
    private static func runningLook(_ values: RoundValues) -> LabMARunning { LabMARunning(rawValue: values["running"]) ?? .run }
    private static func isRunning(_ values: RoundValues) -> Bool { (LabMAState(rawValue: values["state"]) ?? .running) == .running }
}
