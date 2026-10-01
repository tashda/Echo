import SwiftUI

/// Round 33.2 · SQL Server Agent Jobs: New Step. Echo today (AgentJobStepEditorSheet): a
/// SheetLayoutCustomFooter, 480×340 minimum, one grouped section titled "New Step" (the sheet's
/// title again) with Name, Type (12 subsystems), Database, and the command in a plain TextEditor with
/// a hard-coded 6pt corner and an expand button that opens CommandEditorView. No On success / On
/// failure or retries (SSMS's Advanced page). The enabled Add Step is `.bordered`, where
/// VISUAL_GUIDELINES › Sheets wants `.borderedProminent`.
///
/// Revision 2 (owner: NS1's three sections are good, but the hairlines between the top and the
/// bottom are not, and wants more radical layouts): NS3 to NS6, and the sheet's edges as a control.
@MainActor
enum AgentJobStepSheetRound {
    enum Structure: String, CaseIterable {
        case today = "NS0 · One section titled New Step (today)"
        case sections = "NS1 · Three sections: Step, Command, When it finishes"
        case twoPane = "NS2 · Wide: settings on the left, the command on the right"
        case editorFirst = "NS3 · The command fills the sheet; Name, Type, Database on one line above; what happens next as a sentence below"
        case inspector = "NS4 · Wide: the command full height, the settings in a sidebar at the right, like Xcode's inspector"
        case flow = "NS5 · The job's steps at the left with their success and failure arrows; the new step's form at the right"
        case cards = "NS6 · NS1's three sections as cards on the canvas, nothing drawn between them"

        var isWide: Bool { [.twoPane, .inspector, .flow].contains(self) }
    }

    enum Edges: String, CaseIterable {
        case hairlines = "SE0 · Hairlines under the title and over the buttons (every sheet today)"
        case plain = "SE1 · No hairlines: title, content and buttons on one surface"
        case glass = "SE2 · No hairlines; the buttons float on glass over the content"
    }

    enum Command: String, CaseIterable {
        case today = "CE0 · A plain text box with an expand button (today)"
        case editor = "CE1 · Echo's SQL editor: highlighting and line numbers"
        case parse = "CE2 · CE1 with Parse, which checks the T-SQL before you save"
    }

    enum Completion: String, CaseIterable {
        case none = "OC0 · Not offered (today)"
        case offered = "OC1 · On success, On failure, Retry attempts and interval"
    }

    enum Primary: String, CaseIterable {
        case bordered = "PB0 · Bordered (today)"
        case prominent = "PB1 · Prominent, as every sheet"
    }

    struct Look {
        var structure: Structure, edges: Edges, command: Command, completion: Completion, primary: Primary
        static let today = Look(structure: .today, edges: .hairlines, command: .today, completion: .none, primary: .bordered)
        @MainActor static func from(_ v: RoundValues) -> Look {
            Look(structure: .init(rawValue: v["structure"]) ?? .editorFirst, edges: .init(rawValue: v["edges"]) ?? .plain,
                 command: .init(rawValue: v["command"]) ?? .parse,
                 completion: .init(rawValue: v["completion"]) ?? .offered, primary: .init(rawValue: v["primary"]) ?? .prominent)
        }
    }

    static let spec = RoundSpec(
        controls: [
            .of("structure", "Layout", Structure.self, default: .editorFirst,
                question: "Compare the sheet's layouts, NS3 to NS6 first. Which reads best for a step you will come back to edit?",
                recommend: .editorFirst,
                why: "A step is its command: Name, Type and Database are three short values that fit on one line, and On success / On failure read naturally as a sentence, so the editor gets the whole sheet with no section frames at all. If you want to keep NS1's three sections exactly, NS6 keeps them with nothing drawn between. NS4 and NS5 need a sheet 760pt wide; NS5 is the most useful when a job has several steps, but it is a new view to maintain.",
                newChoices: (revision: 2, choices: [.editorFirst, .inspector, .flow, .cards])),
            .of("edges", "Edges", Edges.self, default: .plain,
                question: "Look at the top and bottom of the sheet: the hairline under the title and the one over the buttons. Keep them?",
                recommend: .plain,
                why: "They are the lines you didn't like. On one surface the content's own grouping carries the structure, as in macOS 26's own sheets. Every Echo sheet draws them today (SheetLayout), so this would change all of them, not only New Step. SE2's glass helps only where the content scrolls under the buttons, which few sheets do.",
                addedIn: 2),
            .of("command", "Command", Command.self, default: .parse,
                question: "Look at the command field in each.",
                recommend: .parse,
                why: "A step is SQL you can't run from the tab: highlighting and line numbers make it readable, and Parse catches a typo before the job fails at 2 a.m. (SSMS has the same button)."),
            .of("completion", "When it finishes", Completion.self, default: .offered,
                question: "Should New Step set what happens on success and failure, and retries?",
                recommend: .offered,
                why: "Without them every new step goes to the next step on success and quits the job on failure, and the only way to change that is another tool; they are part of what a step is."),
            .of("primary", "Add Step", Primary.self, default: .prominent,
                question: "Compare the Add Step buttons.",
                recommend: .prominent,
                why: "VISUAL_GUIDELINES › Sheets: an enabled default button is prominent; this sheet builds its own footer and lost it."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "As built, with a T-SQL step being written.",
                  isEchoToday: true, designWidth: 640, designHeight: 560) { _ in
                LabAJStepSheet(look: .today)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls; NS2, NS4 and NS5 draw the sheet 760pt wide.",
                  isWide: true, designWidth: 820, designHeight: 560) { values in
                LabAJStepSheet(look: Look.from(values))
            },
        ],
        questions: [
            .init(id: "edit", title: "Editing a step",
                  question: "Double-clicking a step opens the same sheet titled Edit Step. Should it also show the step's last run?",
                  choices: [
                      .init(id: "same", name: "ES0 · The same sheet, nothing more"),
                      .init(id: "lastRun", name: "ES1 · A line under the title: Last run 26 Sep 23:00 · Succeeded · 14 min"),
                  ],
                  recommended: "lastRun",
                  why: "You usually edit a step because of how it last ran; the line saves a trip to History."),
        ],
        exhibitTopic: ("Which sheet?", "Is the Proposal the New Step sheet to build?", "proposal",
                       "The command fills the sheet with its settings on one line and what happens next as a sentence, no hairlines, Parse, and a prominent Add Step."),
        presets: [
            .init(id: "recommended", name: "My recommendation",
                  values: ["structure": Structure.editorFirst.rawValue, "edges": Edges.plain.rawValue, "command": Command.parse.rawValue,
                           "completion": Completion.offered.rawValue, "primary": Primary.prominent.rawValue],
                  isRecommended: true),
            .init(id: "sectionsAsCards", name: "Your three sections", summary: "NS1's sections as cards, no hairlines.",
                  values: ["structure": Structure.cards.rawValue, "edges": Edges.plain.rawValue, "command": Command.parse.rawValue,
                           "completion": Completion.offered.rawValue, "primary": Primary.prominent.rawValue]),
            .init(id: "inspector", name: "Inspector", summary: "The editor full height, settings at the right.",
                  values: ["structure": Structure.inspector.rawValue, "edges": Edges.plain.rawValue, "command": Command.parse.rawValue,
                           "completion": Completion.offered.rawValue, "primary": Primary.prominent.rawValue]),
            .init(id: "flow", name: "In the job's flow", summary: "The steps and their arrows beside the form.",
                  values: ["structure": Structure.flow.rawValue, "edges": Edges.plain.rawValue, "command": Command.parse.rawValue,
                           "completion": Completion.offered.rawValue, "primary": Primary.prominent.rawValue]),
            .init(id: "wide", name: "Wide", summary: "Settings and command side by side.",
                  values: ["structure": Structure.twoPane.rawValue, "command": Command.parse.rawValue, "completion": Completion.offered.rawValue,
                           "primary": Primary.prominent.rawValue]),
        ]
    )
}
