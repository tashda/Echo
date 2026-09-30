import SwiftUI

/// Round 21 · Postgres: script results. A PostgreSQL script now runs statement by statement and
/// uses the multi-result view SQL Server batches use ("Batch 1 (2)" tabs). How should several
/// statements' results read? Touches FTR-1, FTR-2.3, FTR-2.5 and EDT-3.1.
@MainActor
enum PgScriptResultsRound {
    enum Layout: String, CaseIterable {
        case batchTabs = "SR1 · Batch tabs (today)"
        case statementTabs = "SR2 · Tabs named by statement"
        case stacked = "SR3 · Stacked sections"
        case sidebar = "SR4 · Statement list at the left"
        case timeline = "SR5 · One timeline"
    }
    enum Label: String, CaseIterable {
        case batch = "SL1 · Batch N (today)"
        case statement = "SL2 · Statement N"
        case firstWords = "SL3 · The statement's first words"
        case table = "SL4 · The table it reads"
    }
    enum Commands: String, CaseIterable {
        case messagesOnly = "SC1 · Messages only (today)"
        case entries = "SC2 · Entries with their tag"
        case hidden = "SC3 · Hidden"
    }
    enum Progress: String, CaseIterable {
        case batchLines = "SP1 · Started and completed lines (today)"
        case perStatement = "SP2 · One line per statement"
        case errorsOnly = "SP3 · Errors only"
    }
    enum Link: String, CaseIterable {
        case none = "SK1 · None (today)"
        case highlight = "SK2 · A result highlights its statement"
    }

    private static let width: CGFloat = 680
    private static let height: CGFloat = 520

    static let spec = RoundSpec(
        controls: [
            .of("layout", "Layout", Layout.self, default: .statementTabs,
                question: "Run the script, then look at each result. Which layout lets you find the second SELECT's rows fastest?",
                recommend: .statementTabs,
                why: "Tabs keep one full-size grid (the grid you know) and the names say which statement each belongs to. Stacked sections shrink every grid; a list at the left costs width the grid needs; a timeline is good for reading but bad for working with big results."),
            .of("label", "Label", Label.self, default: .firstWords,
                question: "Read the tab names. Which tells you what each result is without clicking?",
                recommend: .firstWords,
                why: "'SELECT … FROM customers' names the result; 'Batch 2' and 'Statement 2' make you count. The table name alone is ambiguous when two statements read the same table."),
            .of("commands", "Commands", Commands.self, default: .entries,
                question: "The script has a CREATE, an INSERT and an UPDATE. Where should 'INSERT 0 2' and 'UPDATE 3' be?",
                recommend: .entries,
                why: "How many rows an UPDATE touched matters as much as a SELECT's rows; a small entry with its tag keeps it in order with the results. Messages-only hides it behind a segment; hiding it loses it."),
            .of("progress", "Messages", Progress.self, default: .perStatement,
                question: "Open Messages after the run. Which is useful?",
                recommend: .perStatement,
                why: "One line per statement ('3 · UPDATE 3 · 12 ms') is the log you want; 'Batch 3 of 5 started' / 'completed' doubles the lines and says nothing about the outcome."),
            .of("link", "Link to the editor", Link.self, default: .highlight,
                question: "Select a result. Should its statement light up in the editor?",
                recommend: .highlight,
                why: "The statement band already exists (EDT-3.1); lighting it for the selected result connects the two halves of the tab at no cost."),
            .of("speed", "Speed", LabSpeed.self, default: .standard),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "The multi-batch view: 'Batch N (rows)' tabs, commands only in Messages, started/completed lines.",
                  isEchoToday: true, designWidth: width, designHeight: height) { _ in
                PgScriptExhibit(options: .today)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Toggle the failing statement to see errors.",
                  designWidth: width, designHeight: height) { values in
                PgScriptExhibit(options: PgScriptOptions(values: values))
            },
        ],
        questions: [
            .init(id: "onError", title: "When a statement fails",
                  question: "Statement 3 of 5 fails. What happens to 4 and 5?",
                  choices: [
                      .init(id: "stop", name: "E1 · Stop, and say which statement failed"),
                      .init(id: "continue", name: "E2 · Continue (today, like psql)"),
                      .init(id: "setting", name: "E3 · Stop by default, a setting to continue"),
                  ],
                  recommended: "setting",
                  why: "Later statements often depend on the failed one (the INSERT that failed, then the UPDATE that assumes it), so stopping is the safe default; people who run independent maintenance statements can turn it off."),
            .init(id: "oneTransaction", title: "All or nothing",
                  question: "Should a script be runnable as one transaction (all of it or none of it)?",
                  choices: [
                      .init(id: "menu", name: "OT1 · 'Run as one transaction' in the Run menu, off by default"),
                      .init(id: "always", name: "OT2 · Always, unless the script has its own BEGIN"),
                      .init(id: "never", name: "OT3 · No, write BEGIN and COMMIT yourself"),
                  ],
                  recommended: "menu",
                  why: "Each statement committing on its own is what every other tool does and what people expect; an explicit menu choice gives all-or-nothing without surprising anyone."),
        ],
        exhibitTopic: ("Script results", "Run the script in both. Is the proposal easier to read and work with?",
                       "proposal",
                       "Each result is named after its statement, command outcomes sit in order with the results, and Messages reads as a log."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "SR2, SL3, SC2, SP2, SK2.",
                  values: ["layout": Layout.statementTabs.rawValue, "label": Label.firstWords.rawValue, "commands": Commands.entries.rawValue,
                           "progress": Progress.perStatement.rawValue, "link": Link.highlight.rawValue],
                  isRecommended: true),
            .init(id: "reading", name: "For reading", summary: "SR5 timeline with everything in order.",
                  values: ["layout": Layout.timeline.rawValue, "label": Label.firstWords.rawValue, "commands": Commands.entries.rawValue,
                           "progress": Progress.perStatement.rawValue, "link": Link.highlight.rawValue]),
            .init(id: "today", name: "Like Echo today", summary: "SR1, SL1, SC1, SP1, SK1.",
                  values: ["layout": Layout.batchTabs.rawValue, "label": Label.batch.rawValue, "commands": Commands.messagesOnly.rawValue,
                           "progress": Progress.batchLines.rawValue, "link": Link.none.rawValue]),
        ]
    )
}

struct PgScriptOptions: Equatable {
    typealias R = PgScriptResultsRound
    var layout: R.Layout = .batchTabs
    var label: R.Label = .batch
    var commands: R.Commands = .messagesOnly
    var progress: R.Progress = .batchLines
    var link: R.Link = .none

    static let today = PgScriptOptions()
    init() {}

    @MainActor init(values: RoundValues) {
        layout = .init(rawValue: values["layout"]) ?? .statementTabs
        label = .init(rawValue: values["label"]) ?? .firstWords
        commands = .init(rawValue: values["commands"]) ?? .entries
        progress = .init(rawValue: values["progress"]) ?? .perStatement
        link = .init(rawValue: values["link"]) ?? .highlight
    }
}

/// One statement of the sample script and what it produced.
struct PgScriptStatement: Identifiable {
    let id: Int
    let sql: String
    let table: String
    let tag: String
    let rows: [[String?]]?
    let columns: [String]
    var error: String?
    var skipped = false
}

struct PgScriptExhibit: View {
    let options: PgScriptOptions
    @State private var selected = 0
    @State private var failing = false
    @State private var segment = "Results"

    private var statements: [PgScriptStatement] {
        var list = [
            PgScriptStatement(id: 0, sql: "CREATE TEMP TABLE picks (id int)", table: "picks", tag: "CREATE TABLE", rows: nil, columns: []),
            PgScriptStatement(id: 1, sql: "INSERT INTO picks VALUES (1), (2)", table: "picks", tag: "INSERT 0 2", rows: nil, columns: []),
            PgScriptStatement(id: 2, sql: "SELECT id, name FROM customers", table: "customers", tag: "SELECT 3",
                              rows: [["1", "Ada"], ["2", "Linus"], ["3", "Grace"]], columns: ["id", "name"]),
            PgScriptStatement(id: 3, sql: "UPDATE orders SET status = 'paid'", table: "orders", tag: "UPDATE 3", rows: nil, columns: []),
            PgScriptStatement(id: 4, sql: "SELECT order_id, total FROM orders", table: "orders", tag: "SELECT 2",
                              rows: [["1042", "19.90"], ["1043", "5.00"]], columns: ["order_id", "total"]),
        ]
        if failing {
            list[3].error = "column \"stats\" of relation \"orders\" does not exist"
            list[4].skipped = true
        }
        return list
    }

    /// The results shown as separate entries (tabs, sections, list rows).
    private var entries: [PgScriptStatement] {
        statements.filter { $0.rows != nil || $0.error != nil || (options.commands == .entries) }
            .filter { !$0.skipped || options.layout == .timeline }
    }

    private func name(_ statement: PgScriptStatement, position: Int) -> String {
        switch options.label {
        case .batch: return "Batch \(statement.id + 1)"
        case .statement: return "Statement \(statement.id + 1)"
        case .firstWords:
            let words = statement.sql.split(separator: " ")
            if statement.sql.hasPrefix("SELECT"), let from = words.firstIndex(of: "FROM"), from + 1 < words.count {
                return "SELECT … FROM \(words[from + 1])"
            }
            return words.prefix(3).joined(separator: " ")
        case .table: return statement.table
        }
    }

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            PgEditorCard(lines: statements.map { $0.sql + ";" },
                         highlightedLine: options.link == .highlight ? entries[pgSafe: selected]?.id : nil) { index in
                if statements[index].error != nil {
                    Rectangle().fill(ColorTokens.Status.error).frame(height: 1).offset(y: 9)
                }
            }
            .frame(height: 150)
            resultsCard
            HStack {
                Toggle("Statement 4 fails", isOn: $failing).toggleStyle(.checkbox).font(TypographyTokens.detail)
                Spacer()
            }
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas)
        .onChange(of: failing) { _, _ in selected = 0 }
    }

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            if segment == "Messages" {
                messages
            } else {
                switch options.layout {
                case .batchTabs, .statementTabs: tabbed
                case .stacked: stacked
                case .sidebar: sidebar
                case .timeline: timeline
                }
            }
            Spacer(minLength: SpacingTokens.none)
            HStack {
                Picker("", selection: $segment) {
                    Text("Results").tag("Results")
                    Text("Messages").tag("Messages")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 180)
                Spacer()
                PgPill { Text("5 statements · 38 ms") }
            }
            .padding(SpacingTokens.xs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
    }

    private var tabbed: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            HStack(spacing: SpacingTokens.xxs) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    Button { selected = index } label: {
                        HStack(spacing: SpacingTokens.xxs) {
                            if entry.error != nil { Image(systemName: "exclamationmark.circle.fill").foregroundStyle(ColorTokens.Status.error) }
                            Text(name(entry, position: index)).font(TypographyTokens.detail).lineLimit(1)
                            Text(entry.rows.map { "(\($0.count))" } ?? (entry.error == nil ? "· \(entry.tag)" : ""))
                                .font(TypographyTokens.compact).foregroundStyle(ColorTokens.Text.tertiary)
                        }
                        .padding(.horizontal, SpacingTokens.xs)
                        .padding(.vertical, SpacingTokens.xxs)
                        .background(selected == index ? ColorTokens.Text.primary.opacity(0.08) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.extraSmall))
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: SpacingTokens.none)
            }
            .padding(SpacingTokens.xs)
            .background(options.layout == .batchTabs ? ColorTokens.Background.secondary : Color.clear)
            if let entry = entries[pgSafe: selected] { detail(entry) }
        }
    }

    private var stacked: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    VStack(alignment: .leading, spacing: SpacingTokens.nano) {
                        Text(name(entry, position: index)).font(TypographyTokens.labelBold)
                        detail(entry)
                    }
                    .onTapGesture { selected = index }
                }
            }
            .padding(SpacingTokens.xs)
        }
        .labScrollSizing()
    }

    private var sidebar: some View {
        HStack(alignment: .top, spacing: SpacingTokens.none) {
            VStack(alignment: .leading, spacing: SpacingTokens.nano) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    Button { selected = index } label: {
                        HStack(spacing: SpacingTokens.xxs) {
                            Image(systemName: entry.error != nil ? "xmark.circle.fill" : "checkmark.circle")
                                .foregroundStyle(entry.error != nil ? ColorTokens.Status.error : ColorTokens.Status.success)
                            Text(name(entry, position: index)).lineLimit(1)
                            Spacer(minLength: SpacingTokens.none)
                        }
                        .font(TypographyTokens.detail)
                        .padding(SpacingTokens.xxs)
                        .background(selected == index ? ColorTokens.Text.primary.opacity(0.08) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.extraSmall))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 190)
            .padding(SpacingTokens.xs)
            Divider()
            if let entry = entries[pgSafe: selected] { detail(entry) }
        }
    }

    private var timeline: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                ForEach(statements) { statement in
                    HStack(alignment: .top, spacing: SpacingTokens.xs) {
                        Text("\(statement.id + 1)").font(TypographyTokens.detailMono).foregroundStyle(ColorTokens.Text.tertiary)
                        VStack(alignment: .leading, spacing: SpacingTokens.nano) {
                            Text(statement.sql).font(TypographyTokens.detailMono).foregroundStyle(ColorTokens.Text.secondary)
                            detail(statement)
                        }
                    }
                }
            }
            .padding(SpacingTokens.xs)
        }
        .labScrollSizing()
    }

    @ViewBuilder
    private func detail(_ statement: PgScriptStatement) -> some View {
        if statement.skipped {
            Text("Not run: an earlier statement failed").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                .padding(.horizontal, SpacingTokens.sm)
        } else if let error = statement.error {
            Label(error, systemImage: "exclamationmark.octagon.fill").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.error)
                .padding(.horizontal, SpacingTokens.sm)
        } else if let rows = statement.rows {
            PgGrid(columns: statement.columns, rows: rows)
        } else {
            Label(statement.tag, systemImage: "checkmark.circle").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                .padding(.horizontal, SpacingTokens.sm)
        }
    }

    private var messages: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.nano) {
            ForEach(messageLines, id: \.self) { line in
                Text(line).font(TypographyTokens.detailMono)
                    .foregroundStyle(line.contains("ERROR") || line.contains("failed") ? ColorTokens.Status.error : ColorTokens.Text.secondary)
            }
        }
        .padding(SpacingTokens.sm)
    }

    private var messageLines: [String] {
        let ran = statements.filter { !$0.skipped }
        switch options.progress {
        case .batchLines:
            return ran.flatMap { s -> [String] in
                ["Batch \(s.id + 1) of \(statements.count) started",
                 s.error != nil ? "Batch \(s.id + 1): ERROR: \(s.error!)" : "Batch \(s.id + 1) of \(statements.count) completed"]
            }
        case .perStatement:
            return ran.map { s in s.error != nil ? "\(s.id + 1) · ERROR: \(s.error!)" : "\(s.id + 1) · \(s.tag) · \(4 + s.id * 3) ms" }
                + (failing ? ["Stopped: statement 4 failed; statement 5 was not run."] : [])
        case .errorsOnly:
            return ran.compactMap { s in s.error.map { "\(s.id + 1) · ERROR: \($0)" } }
        }
    }
}

extension Array {
    subscript(pgSafe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
