import SwiftUI

/// Round 33.2 · SQL Server Agent Jobs: New Step. Echo today (AgentJobStepEditorSheet): a
/// SheetLayoutCustomFooter, 480×340 minimum, one grouped section titled "New Step" (the sheet's
/// title again) with Name, Type (12 subsystems), Database, and the command in a plain TextEditor with
/// a hard-coded 6pt corner and an expand button that opens CommandEditorView. No On success / On
/// failure or retries (SSMS's Advanced page). The enabled Add Step is `.bordered`, where
/// VISUAL_GUIDELINES › Sheets wants `.borderedProminent`.
@MainActor
enum AgentJobStepSheetRound {
    enum Structure: String, CaseIterable {
        case today = "NS0 · One section titled New Step (today)"
        case sections = "NS1 · Three sections: Step, Command, When it finishes"
        case twoPane = "NS2 · Wide: settings on the left, the command on the right"
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
        var structure: Structure, command: Command, completion: Completion, primary: Primary
        static let today = Look(structure: .today, command: .today, completion: .none, primary: .bordered)
        @MainActor static func from(_ v: RoundValues) -> Look {
            Look(structure: .init(rawValue: v["structure"]) ?? .sections, command: .init(rawValue: v["command"]) ?? .parse,
                 completion: .init(rawValue: v["completion"]) ?? .offered, primary: .init(rawValue: v["primary"]) ?? .prominent)
        }
    }

    static let spec = RoundSpec(
        controls: [
            .of("structure", "Layout", Structure.self, default: .sections,
                question: "Compare the sheet's layouts. Which reads best for a step you will come back to edit?",
                recommend: .sections,
                why: "Three titled sections follow the order you think in (what, run what, then what) and match the other grouped sheets. NS2 earns its width only for long scripts, which the full editor already covers."),
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
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls.",
                  designWidth: 640, designHeight: 560) { values in
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
                       "Three sections, a real SQL editor with Parse, success and failure actions, and a prominent Add Step."),
        presets: [
            .init(id: "recommended", name: "My recommendation",
                  values: ["structure": Structure.sections.rawValue, "command": Command.parse.rawValue,
                           "completion": Completion.offered.rawValue, "primary": Primary.prominent.rawValue],
                  isRecommended: true),
            .init(id: "wide", name: "Wide", summary: "Settings and command side by side.",
                  values: ["structure": Structure.twoPane.rawValue, "command": Command.parse.rawValue, "completion": Completion.offered.rawValue,
                           "primary": Primary.prominent.rawValue]),
        ]
    )
}

/// The sheet: title, form, footer.
private struct LabAJStepSheet: View {
    let look: AgentJobStepSheetRound.Look
    @State private var name = "Rebuild indexes"

    var body: some View {
        VStack(spacing: SpacingTokens.none) {
            Text(look.structure == .today ? "New Step" : "New Step · IndexOptimize - USER_DATABASES")
                .font(TypographyTokens.headline).frame(maxWidth: .infinity).padding(SpacingTokens.sm)
            Divider()
            if look.structure == .twoPane {
                HStack(alignment: .top, spacing: SpacingTokens.none) {
                    form(includeCommand: false).frame(width: 280)
                    Divider()
                    commandField.padding(SpacingTokens.md)
                }
            } else {
                form(includeCommand: true)
            }
            Divider()
            footer
        }
        .background(ColorTokens.Background.primary)
        .clipShape(.rect(cornerRadius: SpacingTokens.md, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
        .padding(SpacingTokens.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Workspace.canvas)
    }

    private func form(includeCommand: Bool) -> some View {
        Form {
            Section(look.structure == .today ? "New Step" : "Step") {
                TextField("Name", text: $name, prompt: Text("e.g. Run cleanup query"))
                Picker("Type", selection: .constant("T-SQL")) { Text("T-SQL").tag("T-SQL"); Text("PowerShell").tag("PowerShell") }
                Picker("Database", selection: .constant("master")) { Text("master").tag("master") }
                if look.structure == .today, includeCommand { LabeledContent("Command") { commandField } }
            }
            if look.structure != .today, includeCommand {
                Section("Command") { commandField }
            }
            if look.completion == .offered {
                Section("When it finishes") {
                    Picker("On success", selection: .constant("Go to the next step")) { Text("Go to the next step").tag("Go to the next step") }
                    Picker("On failure", selection: .constant("Quit the job reporting failure")) {
                        Text("Quit the job reporting failure").tag("Quit the job reporting failure")
                    }
                    LabeledContent("Retry") {
                        Text("0 times, 1 minute apart").foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var commandField: some View {
        let sql = ["EXECUTE dbo.IndexOptimize", "  @Databases = 'USER_DATABASES',", "  @FragmentationLevel1 = 5,", "  @LogToTable = 'Y'"]
        if look.command == .today {
            HStack(alignment: .top) {
                Text(sql.joined(separator: "\n")).font(TypographyTokens.body.monospaced())
                    .frame(maxWidth: .infinity, minHeight: SpacingTokens.xxxl + SpacingTokens.md, alignment: .topLeading)
                    .padding(SpacingTokens.xxs)
                    .background(ColorTokens.Background.primary, in: .rect(cornerRadius: SpacingTokens.xxs2))
                    .overlay(RoundedRectangle(cornerRadius: SpacingTokens.xxs2).strokeBorder(ColorTokens.Text.quaternary.opacity(0.4), lineWidth: 0.5))
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
        } else {
            VStack(alignment: .trailing, spacing: SpacingTokens.xxs) {
                LabWKEditor(lines: sql)
                    .frame(minHeight: SpacingTokens.xxxl * 2)
                    .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: SpacingTokens.xs, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous).strokeBorder(ColorTokens.Separator.primary, lineWidth: 0.5))
                HStack {
                    if look.command == .parse {
                        Label("No errors", systemImage: "checkmark.circle.fill").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.success)
                        Spacer()
                        Button("Parse") {}.controlSize(.small)
                    } else { Spacer() }
                    Button("Open in Editor", systemImage: "arrow.up.left.and.arrow.down.right") {}.controlSize(.small)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel") {}
            if look.primary == .prominent {
                Button("Add Step") {}.buttonStyle(.borderedProminent)
            } else {
                Button("Add Step") {}.buttonStyle(.bordered)
            }
        }
        .padding(SpacingTokens.sm)
        .background(.bar)
    }
}
