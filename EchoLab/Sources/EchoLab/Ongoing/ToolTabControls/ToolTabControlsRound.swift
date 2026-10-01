import SwiftUI

/// Round 37.3 · Tool tabs: buttons and controls. Echo today: every tool chooses its own: SQL
/// Profiler's primary is `.bordered` small tinted, secondaries are borderless symbols, the database
/// is a pop-up after a "Database" label, and the running state is a green "Tracing" label; other
/// tools use `.borderedProminent`, `.link` or plain buttons. The editor's floating pieces were
/// decided in round 28.15 (DF0: glass, symbol in colour, words in grey); this applies that language.
@MainActor
enum ToolTabControlsRound {
    static let spec = RoundSpec(
        controls: [
            .of("primary", "Main action", LabTTPrimary.self, default: .glass,
                question: "Look at Start Trace and New Policy in each style.",
                recommend: .glass,
                why: "It's the editor's language you just decided (DF0), so a tool's main action and the editor's floating pieces look like one family. A prominent blue capsule competes with Run, the only tinted thing in the toolbar; bare text looks like a link."),
            .of("secondary", "Other actions", LabTTSecondary.self, default: .group,
                question: "Compare Clear, Events and Export.",
                recommend: .group,
                why: "One capsule for the related actions, like the toolbar's own groups; bare symbols float unanchored (the 'off' you saw), and a circle each is a lot of glass for three small actions."),
            .of("picker", "Pickers", LabTTPicker.self, default: .pill,
                question: "Compare the database picker in each style.",
                recommend: .pill,
                why: "The value is what matters (All Databases); a symbol says what kind of value. A separate label and a system pop-up is the mismatch in today's Profiler."),
            .of("status", "Running", LabTTStatus.self, default: .inButton,
                question: "With the trace running, where should that show?",
                recommend: .inButton,
                why: "Like Run turning into Stop: the place you started it is where you stop it, and its dot says it's live. A separate green word is a second thing to look for."),
            .of("search", "Search", LabTTSearch.self, default: .capsule,
                question: "Should every tool with a list get the same search, and how?",
                recommend: .capsule,
                why: "Most tools have none today; a capsule in the same place on every tool is learned once. Expanding saves 150pt but hides the field's prompt."),
            .of("running", "Running", LabTTRunning.self, default: .running),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today: SQL Profiler", summary: "As built.",
                  isEchoToday: true, isWide: true, designWidth: 860, designHeight: 330) { values in
                LabTTTab(tool: .profiler, look: .today, running: (LabTTRunning(rawValue: values["running"]) ?? .running) == .running)
            },
            .init(id: "profiler", title: "Proposal: SQL Profiler", summary: "37.2's two rows with the controls above.",
                  isWide: true, designWidth: 860, designHeight: 330) { values in
                LabTTTab(tool: .profiler, look: LabTTLook.from(values), running: (LabTTRunning(rawValue: values["running"]) ?? .running) == .running)
            },
            .init(id: "policy", title: "Proposal: Policy Management", summary: "The same controls on a manage tool.",
                  isWide: true, designWidth: 860, designHeight: 330) { values in
                LabTTTab(tool: .policy, look: LabTTLook.from(values))
            },
        ],
        questions: [
            .init(id: "size", title: "Control height",
                  question: "How tall should these controls be?",
                  choices: [
                      .init(id: "28", name: "CH0 · 28pt, as the toolbar's capsules"),
                      .init(id: "24", name: "CH1 · 24pt, as the footer's pills"),
                  ],
                  recommended: "28",
                  why: "The header row is a toolbar for the tab and sits at the top like the window's; 24pt is the footer's size, which is quieter by design."),
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation",
                  values: ["primary": LabTTPrimary.glass.rawValue, "secondary": LabTTSecondary.group.rawValue, "picker": LabTTPicker.pill.rawValue,
                           "status": LabTTStatus.inButton.rawValue, "search": LabTTSearch.capsule.rawValue],
                  isRecommended: true),
            .init(id: "system", name: "System controls", summary: "Prominent primary, circles, chips, a status pill.",
                  values: ["primary": LabTTPrimary.prominent.rawValue, "secondary": LabTTSecondary.circles.rawValue, "picker": LabTTPicker.chip.rawValue,
                           "status": LabTTStatus.pill.rawValue, "search": LabTTSearch.expanding.rawValue]),
        ]
    )
}
