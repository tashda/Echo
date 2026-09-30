import SwiftUI

/// Round 21 · Postgres: cancelling a query. ■ now stops the statement on the server
/// (pg_cancel_backend) before the task stops. This page is about what cancelling means — the wait,
/// the rows already fetched, a cancel the server doesn't answer, and what is reported. How Run looks
/// while running is round 20. Touches EDT-4.3, EDT-4.4 (behaviour only) and EDT-3.3.
@MainActor
enum PgCancelRound {
    enum Waiting: String, CaseIterable {
        case nothing = "CX1 · No in-between state (today)"
        case capsule = "CX2 · 'Stopping…' in Run"
        case footer = "CX3 · 'Stopping…' in the footer"
    }
    enum Partial: String, CaseIterable {
        case keepMarked = "CP1 · Keep the rows, marked as partial"
        case keep = "CP2 · Keep the rows (today)"
        case clear = "CP3 · Clear the grid"
    }
    enum Stuck: String, CaseIterable {
        case wait = "CS1 · Keep waiting"
        case offer = "CS2 · Offer Force Stop after 5 s"
        case automatic = "CS3 · Force stop after 10 s"
    }
    enum Report: String, CaseIterable {
        case messages = "CR1 · A line in Messages (today)"
        case note = "CR2 · Run note at the statement, and Messages"
        case notification = "CR3 · A notification"
    }

    private static let width: CGFloat = 600
    private static let height: CGFloat = 440

    static let spec = RoundSpec(
        controls: [
            .of("waiting", "While stopping", Waiting.self, default: .capsule,
                question: "Run, then press ■. Between pressing ■ and the server confirming, what should you see?",
                recommend: .capsule,
                why: "The server usually stops within a second but not instantly; saying 'Stopping…' where you pressed ■ confirms the click and stops a second press. Nothing in-between looks like the click missed; the footer is not where you are looking."),
            .of("partial", "Rows already fetched", Partial.self, default: .keepMarked,
                question: "Cancel a query after some rows arrived. What should happen to them?",
                recommend: .keepMarked,
                why: "The rows are real and often what you wanted to look at, but they are not the whole result: the footer's count says 'Stopped at 1,200 rows'. Keeping them unmarked invites mistaking them for the full result; clearing throws away what you waited for."),
            .of("stuck", "If the server doesn't stop", Stuck.self, default: .offer,
                question: "Tick 'Server doesn't answer', run and cancel. What should Echo do?",
                recommend: .offer,
                why: "Force Stop closes the connection, which also rolls back an open transaction, so it should be your choice; offering it after five seconds gets you out of a hung query. Waiting forever traps the tab; stopping by itself can lose a transaction."),
            .of("report", "Reported", Report.self, default: .note,
                question: "After cancelling, where do you look to confirm it stopped and when?",
                recommend: .note,
                why: "The run note already answers 'what happened to this statement' at the statement (EDT-3.3); 'Stopped after 3.2 s · 1,200 rows' belongs there. A notification is for things that happen while you look elsewhere, and you just pressed ■."),
            .of("speed", "Speed", LabSpeed.self, default: .standard),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "■ stops the task; the result settles when the server lets go; 'Query execution canceled' in Messages.",
                  isEchoToday: true, designWidth: width, designHeight: height) { _ in
                PgCancelExhibit(options: .today)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls.",
                  designWidth: width, designHeight: height) { values in
                PgCancelExhibit(options: PgCancelOptions(values: values))
            },
        ],
        questions: [
            .init(id: "shortcut", title: "Shortcut",
                  question: "Cancel is ⌥⌘. today. Should ⌘. also cancel?",
                  choices: [
                      .init(id: "add", name: "K1 · Add ⌘. (the macOS cancel), keep ⌥⌘."),
                      .init(id: "keep", name: "K2 · Keep ⌥⌘. only"),
                  ],
                  recommended: "add",
                  why: "⌘. is the standard macOS 'stop what you are doing' key; adding it costs nothing and ⌥⌘. keeps working for people who learned it."),
            .init(id: "transaction", title: "Cancelling inside a transaction",
                  question: "Postgres marks the transaction as failed when a statement in it is cancelled.",
                  choices: [
                      .init(id: "say", name: "TX1 · Say so in the note: 'The transaction now needs ROLLBACK'"),
                      .init(id: "silent", name: "TX2 · Say nothing extra"),
                  ],
                  recommended: "say",
                  why: "Without it the next statement fails with 'current transaction is aborted', which looks unrelated to the cancel."),
        ],
        exhibitTopic: ("Cancel feedback", "Cancel in both. Does the proposal tell you better that it stopped, and what you are looking at?",
                       "proposal",
                       "It confirms ■ at once, keeps the rows you waited for but says they are partial, and gives a way out when the server hangs."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "CX2, CP1, CS2, CR2.",
                  values: ["waiting": Waiting.capsule.rawValue, "partial": Partial.keepMarked.rawValue, "stuck": Stuck.offer.rawValue, "report": Report.note.rawValue],
                  isRecommended: true),
            .init(id: "today", name: "Like Echo today", summary: "CX1, CP2, CS1, CR1.",
                  values: ["waiting": Waiting.nothing.rawValue, "partial": Partial.keep.rawValue, "stuck": Stuck.wait.rawValue, "report": Report.messages.rawValue]),
        ]
    )
}

struct PgCancelOptions: Equatable {
    var waiting: PgCancelRound.Waiting = .nothing
    var partial: PgCancelRound.Partial = .keep
    var stuck: PgCancelRound.Stuck = .wait
    var report: PgCancelRound.Report = .messages

    static let today = PgCancelOptions()
    init() {}

    @MainActor init(values: RoundValues) {
        waiting = .init(rawValue: values["waiting"]) ?? .capsule
        partial = .init(rawValue: values["partial"]) ?? .keepMarked
        stuck = .init(rawValue: values["stuck"]) ?? .offer
        report = .init(rawValue: values["report"]) ?? .note
    }
}

struct PgCancelExhibit: View {
    let options: PgCancelOptions

    private enum Phase: Equatable { case idle, running, stopping, stuck, stopped, finished }
    @State private var phase: Phase = .idle
    @State private var elapsed = 0.0
    @State private var rows = 0
    @State private var serverHangs = false
    @State private var messages: [String] = []
    @State private var task: Task<Void, Never>?
    @Environment(\.echoMotion) private var motion

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack {
                Spacer()
                runCapsule
            }
            PgEditorCard(lines: ["select o.*, c.name", "from orders o join customers c using (customer_id)", "order by o.created_at desc;"], highlightedLine: 2) { index in
                if index == 2, options.report == .note, phase == .stopped {
                    Text(noteText).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.warning)
                        .padding(.leading, 260)
                }
            }
            .frame(height: 120)
            resultsCard
            HStack {
                PgSimBar(actions: [(phase == .running || phase == .stopping || phase == .stuck ? "■ Cancel" : "▶ Run", { toggle() }), ("Reset", { reset() })])
                Toggle("Server doesn't answer", isOn: $serverHangs).toggleStyle(.checkbox).font(TypographyTokens.detail)
            }
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas)
        .overlay(alignment: .topTrailing) {
            if options.report == .notification, phase == .stopped {
                Label("Query 1 stopped after \(String(format: "%.1f", elapsed)) s", systemImage: "stop.circle.fill")
                    .font(TypographyTokens.detail)
                    .padding(SpacingTokens.sm)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.large))
                    .padding(.top, 48).padding(.trailing, SpacingTokens.sm)
            }
        }
        .animation(motion.standard, value: phase)
        .onDisappear { task?.cancel() }
    }

    private var noteText: String {
        "Stopped after \(String(format: "%.1f", elapsed)) s · \(rows.formatted()) rows"
    }

    @ViewBuilder
    private var runCapsule: some View {
        let label: (String, String, Color?) = {
            switch phase {
            case .idle, .finished: return ("play.fill", "", nil)
            case .running: return ("stop.fill", String(format: "%.1f s", elapsed), ColorTokens.Status.error)
            case .stopping, .stuck:
                return options.waiting == .capsule ? ("hourglass", "Stopping…", ColorTokens.Text.secondary) : ("stop.fill", String(format: "%.1f s", elapsed), ColorTokens.Status.error)
            case .stopped: return ("stop.circle", "Stopped", nil)
            }
        }()
        HStack(spacing: SpacingTokens.xxs) {
            Image(systemName: label.0)
            if !label.1.isEmpty { Text(label.1).monospacedDigit() }
        }
        .font(TypographyTokens.standard)
        .foregroundStyle(label.2 == nil ? ColorTokens.Text.primary : Color.white)
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xxs2)
        .background(label.2 ?? Color.clear, in: .capsule)
        .glassEffect(.regular, in: .capsule)
    }

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            if rows > 0, !(phase == .stopped && options.partial == .clear) {
                PgGrid(columns: ["order_id", "status", "name", "created_at"],
                       rows: (0..<4).map { i in ["\(1042 - i)", ["shipped", "paid", "new", "paid"][i], ["Ada", "Linus", "Grace", "Ken"][i], "2026-09-30 1\(i):04:12"] })
            } else {
                Text(phase == .stopped ? "Stopped. No rows are shown." : " ").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                    .padding(SpacingTokens.sm)
            }
            if options.stuck == .offer, phase == .stuck {
                HStack(spacing: SpacingTokens.xs) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(ColorTokens.Status.warning)
                    Text("The server hasn't stopped the query.").font(TypographyTokens.detail)
                    Spacer()
                    Button("Force Stop") { forceStop() }.controlSize(.small)
                        .help("Closes the connection. An open transaction is rolled back.")
                }
                .padding(.horizontal, SpacingTokens.sm)
            }
            Spacer(minLength: SpacingTokens.none)
            PgFooter {
                if options.waiting == .footer, phase == .stopping || phase == .stuck {
                    PgPill { ProgressView().controlSize(.mini); Text("Stopping…") }
                } else {
                    PgPill { PgStatusLabel(text: statusWord, color: statusColor) }
                }
                PgPill(tint: phase == .stopped && options.partial == .keepMarked ? ColorTokens.Status.warning : nil) {
                    Text(phase == .stopped && options.partial == .keepMarked ? "Stopped at \(rows.formatted()) rows" : "\(rows.formatted()) rows")
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .workspaceCard()
    }

    private var statusWord: String {
        switch phase {
        case .idle, .finished: "Ready"
        case .running, .stopping, .stuck: "Running"
        case .stopped: options.report == .messages ? "Ready" : "Stopped"
        }
    }

    private var statusColor: Color {
        switch phase {
        case .running, .stopping, .stuck: ColorTokens.Status.info
        case .stopped: ColorTokens.Status.warning
        default: ColorTokens.Status.success
        }
    }

    private func toggle() {
        switch phase {
        case .running: stop()
        case .stopping, .stuck: break
        default: start()
        }
    }

    private func start() {
        task?.cancel()
        phase = .running; elapsed = 0; rows = 0; messages = []
        task = Task { @MainActor in
            while !Task.isCancelled, phase == .running || phase == .stopping || phase == .stuck {
                try? await Task.sleep(for: .milliseconds(100))
                elapsed += 0.1
                if phase == .running { rows += 37 }
            }
        }
    }

    private func stop() {
        phase = .stopping
        Task { @MainActor in
            if serverHangs {
                try? await Task.sleep(for: .seconds(options.stuck == .automatic ? 10 : 5))
                guard phase == .stopping else { return }
                if options.stuck == .automatic { forceStop() } else if options.stuck == .offer { phase = .stuck }
            } else {
                try? await Task.sleep(for: .milliseconds(options.waiting == .nothing ? 900 : 700))
                guard phase == .stopping else { return }
                phase = .stopped
                messages.append("Query execution canceled")
            }
        }
    }

    private func forceStop() {
        phase = .stopped
        messages.append("Connection closed to stop the query")
    }

    private func reset() { task?.cancel(); phase = .idle; elapsed = 0; rows = 0; messages = [] }
}
