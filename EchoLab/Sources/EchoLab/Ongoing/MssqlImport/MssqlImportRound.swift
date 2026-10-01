import SwiftUI

/// Round 25 · SQL Server: importing a file. sqlserver-nio now sends imports with the TDS bulk load
/// (what bcp and SqlBulkCopy use) instead of multi-row INSERT statements. The bulk load has options
/// the Import Data sheet does not offer today (check constraints, fire triggers, empty cells as the
/// column default, table lock), and the sheet says nothing about what a failed import left behind:
/// batches before the failure stay in the table. No Spec element covers the import sheet yet.
/// Already fixed without asking: the progress bar never moved for SQL Server imports.
@MainActor
enum MssqlImportRound {
    enum Options: String, CaseIterable {
        case section = "IO1 · An Options section, every option visible"
        case disclosure = "IO2 · Options behind a More options disclosure"
        case today = "IO3 · Echo today: Identity Insert only"
    }
    enum EmptyCells: String, CaseIterable {
        case choice = "EC1 · A choice in the sheet, NULL by default"
        case null = "EC2 · Always NULL (today)"
        case columnDefault = "EC3 · Always the column's default"
    }
    enum Failure: String, CaseIterable {
        case undo = "FA1 · Undo everything: one transaction"
        case keep = "FA2 · Keep the rows already imported, and say how many"
    }
    enum Moment: String, CaseIterable {
        case ready = "Ready"
        case importing = "Importing"
        case done = "Done"
        case fallback = "Done, with INSERT statements"
        case failed = "Failed at row 31,406"
    }

    private static let width: CGFloat = 640
    private static let height: CGFloat = 600

    static let spec = RoundSpec(
        controls: [
            .of("moment", "Moment", Moment.self, default: .ready),
            .of("options", "Options", Options.self, default: .section,
                question: "Look at the proposal at Ready. How should the bulk load's options appear in the sheet?",
                recommend: .section,
                why: "Five rows in one grouped section, each with a safe default, is how Echo's sheets show settings; hidden behind a disclosure they are missed exactly when they matter (a trigger that should not fire on a reload). IO3 leaves no way to skip triggers or use column defaults."),
            .of("empty", "Empty cells", EmptyCells.self, default: .choice,
                question: "An empty cell in the file becomes NULL today. Set Empty cells to each choice; which should Echo do?",
                recommend: .choice,
                why: "Both are right for different files: NULL keeps the file's meaning, the column default fills created_at or status the way an INSERT without the column would. NULL stays the default so nothing changes for today's imports. EC3 would silently change today's results."),
            .of("failure", "When an import fails", Failure.self, default: .undo,
                question: "Set Moment to Failed. When row 31,406 cannot be converted, what should the table look like afterwards?",
                recommend: .undo,
                why: "A half-imported file is the hardest state to clean up: you have to find where it stopped and delete or skip exactly those rows. One transaction leaves the table as it was, so fixing the file and importing again just works. It costs locks and log space for the whole import, which is fine for the files people import from a desktop tool. Today the rows stay and the sheet does not say so."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "Batch Size 1,000 and Identity Insert. The progress bar stays at 0 until the end; a failure keeps the batches before it without saying so.",
                  isEchoToday: true, designWidth: width, designHeight: height) { values in
                MssqlImportSheet(today: true, moment: Moment(rawValue: values["moment"]) ?? .ready,
                                 options: .today, empty: .null, failure: .keep)
            },
            .init(id: "proposal", title: "Proposal", summary: "Accepted (IO1, EC1, FA1, BS1, ME1) and built into Echo in 2a235de8.",
                  designWidth: width, designHeight: height) { values in
                MssqlImportSheet(today: false, moment: Moment(rawValue: values["moment"]) ?? .ready,
                                 options: Options(rawValue: values["options"]) ?? .section,
                                 empty: EmptyCells(rawValue: values["empty"]) ?? .choice,
                                 failure: Failure(rawValue: values["failure"]) ?? .undo)
            },
        ],
        questions: [
            .init(id: "batch", title: "Batch size",
                  question: "Each batch is one bulk load. What should the Batch Size field start at?",
                  choices: [
                      .init(id: "10k", name: "BS1 · 10,000 rows"),
                      .init(id: "1k", name: "BS2 · 1,000 rows (today)"),
                      .init(id: "all", name: "BS3 · The whole file in one batch", summary: "What SqlBulkCopy does by default."),
                  ],
                  recommended: "10k",
                  why: "A batch costs a round trip, so 1,000 makes a 50,000-row file ten times chattier than it needs to be. One batch for the whole file gives no progress and holds it all in one request. 10,000 rows is a few megabytes per batch and still moves the bar on typical files."),
            .init(id: "method", title: "When the bulk load cannot be used",
                  question: "Tables with geometry, geography, hierarchyid, sql_variant, text, ntext, image, json or vector columns are imported with INSERT statements instead, which is slower. Should the sheet say so? Set Moment to Done, with INSERT statements.",
                  choices: [
                      .init(id: "fallback", name: "ME1 · Only when INSERT statements were used"),
                      .init(id: "always", name: "ME2 · Always name the method"),
                      .init(id: "never", name: "ME3 · Never"),
                  ],
                  recommended: "fallback",
                  why: "The method only matters when it explains a slow import. Naming it every time adds jargon to the common case; never naming it leaves a slow import unexplained."),
        ],
        exhibitTopic: ("Build it?", "Step through Moment in both. Does the proposal say what will happen and what happened better than Echo today?",
                       "proposal",
                       "It offers the options the bulk load has, its progress moves, and a failure says what is in the table afterwards. Echo today shows none of that."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "IO1, EC1, FA1.",
                  values: ["options": Options.section.rawValue, "empty": EmptyCells.choice.rawValue, "failure": Failure.undo.rawValue],
                  isRecommended: true),
        ]
    )
}

/// The Import Data sheet (`BulkImportSheet`) for orders.csv into dbo.orders: Source File, Target,
/// the options, Column Mapping, Progress and the footer, as its grouped form lays them out.
struct MssqlImportSheet: View {
    typealias R = MssqlImportRound
    let today: Bool
    let moment: R.Moment
    let options: R.Options
    let empty: R.EmptyCells
    let failure: R.Failure

    private let total = 48_210
    private var batchSize: Int { today ? 1_000 : 10_000 }
    private var batches: Int { (total + batchSize - 1) / batchSize }

    var body: some View {
        VStack(spacing: SpacingTokens.none) {
            PgConnSheet {
                PgConnSection(header: "Source File") {
                    PgConnRow(title: "File") { PgConnPath(text: "~/Downloads/orders.csv") }
                    PgConnRow(title: "Delimiter") { PgConnMenu(text: "Comma") }
                    PgConnNote(text: "48,210 rows detected")
                }
                PgConnSection(header: "Target") {
                    PgConnRow(title: "Schema") { PgConnValue(text: "dbo") }
                    PgConnRow(title: "Table") { PgConnValue(text: "orders") }
                    PgConnRow(title: "Batch Size") { PgConnValue(text: batchSize.formatted()) }
                    if options == .today {
                        PgConnRow(title: "Identity Insert") { PgConnSwitch(isOn: false) }
                    }
                }
                optionsSection
                PgConnSection(header: "Column Mapping") {
                    mapping("order_id", "id")
                    mapping("customer", "customer_id")
                    mapping("ordered", "ordered_at")
                    mapping("total", "total")
                    mapping("status", "status")
                }
                if moment != .ready {
                    PgConnSection(header: "Progress") { progress }
                }
            }
            footer
        }
    }

    @ViewBuilder
    private var optionsSection: some View {
        switch options {
        case .today:
            EmptyView()
        case .section:
            PgConnSection(header: "Options") { optionRows }
        case .disclosure:
            PgConnSection {
                HStack(spacing: SpacingTokens.xs) {
                    Image(systemName: "chevron.right").font(TypographyTokens.detail.weight(.semibold))
                        .foregroundStyle(ColorTokens.Text.secondary)
                    Text("More options").font(TypographyTokens.formLabel)
                    Spacer(minLength: SpacingTokens.md)
                    Text("Constraints and triggers on").font(TypographyTokens.formValue)
                        .foregroundStyle(ColorTokens.Text.secondary).lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder
    private var optionRows: some View {
        if empty == .choice {
            PgConnRow(title: "Empty cells") { PgConnMenu(text: "NULL") }
        }
        PgConnRow(title: "Keep identity values") { PgConnSwitch(isOn: false) }
        PgConnRow(title: "Check constraints") { PgConnSwitch(isOn: true) }
        PgConnRow(title: "Fire triggers") { PgConnSwitch(isOn: true) }
        PgConnRow(title: "Lock the table") { PgConnSwitch(isOn: false) }
        PgConnNote(text: "Locking the table is faster; other sessions wait until each batch is done.")
    }

    private func mapping(_ file: String, _ column: String) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Text(file).font(TypographyTokens.standard).frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "arrow.right").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            PgConnMenu(text: column).frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var progress: some View {
        switch moment {
        case .ready:
            EmptyView()
        case .importing:
            // Today the SQL Server import reports nothing until it finishes.
            let done = today ? 0 : 20_000
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                ProgressView(value: Double(done) / Double(total))
                HStack {
                    Text("\(done.formatted()) of \(total.formatted()) rows").font(TypographyTokens.detail)
                    Spacer()
                    Text("Batch \(today ? 0 : 2)/\(batches)").font(TypographyTokens.detail)
                }
                .foregroundStyle(ColorTokens.Text.secondary)
            }
        case .done, .fallback:
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                Label(today ? "Successfully imported 48210 rows in \(moment == .done ? "4.87" : "6.12")s"
                            : "Imported \(total.formatted()) rows in \(moment == .done ? "1.9" : "6.1") s",
                      systemImage: "checkmark.circle.fill")
                    .font(TypographyTokens.standard).foregroundStyle(ColorTokens.Status.success)
                if !today && moment == .fallback {
                    PgConnNote(text: "Imported with INSERT statements: the bulk load cannot fill the geometry column location.",
                               icon: "info.circle")
                }
            }
        case .failed:
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                Label(failureTitle, systemImage: "xmark.circle.fill")
                    .font(TypographyTokens.standard).foregroundStyle(ColorTokens.Status.error)
                    .fixedSize(horizontal: false, vertical: true)
                if !today {
                    PgConnNote(text: "Conversion failed when converting date and/or time from character string. (ordered: 31/12/2023)")
                }
            }
            .frame(minWidth: 300, alignment: .leading)
        }
    }

    private var failureTitle: String {
        if today { return "Conversion failed when converting date and/or time from character string." }
        switch failure {
        case .undo: return "Nothing was imported. dbo.orders is as it was."
        case .keep: return "Stopped after 30,000 rows. Those rows are in dbo.orders; the rest were not imported."
        }
    }

    private var footer: some View {
        HStack(spacing: SpacingTokens.xs) {
            Text(footerStatus).font(TypographyTokens.formDescription).foregroundStyle(ColorTokens.Text.secondary).lineLimit(1)
            Spacer(minLength: SpacingTokens.md)
            if moment == .importing { Button("Cancel") {}.controlSize(.small) }
            Button("Close") {}.controlSize(.small).disabled(moment == .importing)
            Button("Import") {}.controlSize(.small).disabled(moment == .importing)
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
    }

    private var footerStatus: String {
        switch moment {
        case .ready: return "5 column(s) mapped"
        case .importing:
            return today ? "Importing… 0 rows (0/49 batches) 2.1s" : "Importing… 20,000 of 48,210 rows"
        case .done, .fallback:
            return today ? "Completed: 48210 rows imported in \(moment == .done ? "4.87" : "6.12")s" : "Done"
        case .failed:
            return today ? "Failed: Conversion failed when converting date and/or time from character string." : "Failed"
        }
    }
}
