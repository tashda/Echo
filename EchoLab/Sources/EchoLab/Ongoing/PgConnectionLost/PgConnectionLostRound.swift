import SwiftUI

/// Round 21 · Postgres: connection lost. A tab's pinned connection can drop (network, server
/// restart, idle timeout). Echo now knows at once and knows whether a transaction was lost; it never
/// reconnects silently. Touches NTF-1.1 to 1.4, FTR-2.6 and EDT-3.3.
@MainActor
enum PgConnectionLostRound {
    enum Where: String, CaseIterable {
        case messages = "CL1 · Error in Messages (today)"
        case toast = "CL2 · Notification"
        case banner = "CL3 · Banner on the editor"
        case footer = "CL4 · Footer status and run note"
    }
    enum When: String, CaseIterable {
        case nextRun = "CW1 · On the next run (today)"
        case atOnce = "CW2 · The moment it drops"
    }
    enum Reconnect: String, CaseIterable {
        case nextRun = "RC1 · The next run reconnects (today)"
        case button = "RC2 · A Reconnect button"
        case automatic = "RC3 · Reconnect at once, keep a note"
    }
    enum Wording: String, CaseIterable {
        case technical = "WD1 · The server's words"
        case plain = "WD2 · What it means for your work"
    }

    private static let width: CGFloat = 600
    private static let height: CGFloat = 420

    static let spec = RoundSpec(
        controls: [
            .of("where", "Where", Where.self, default: .banner,
                question: "Press 'Drops, in a transaction'. Where do you notice it, and is it clear which tab it concerns?",
                recommend: .banner,
                why: "Losing a transaction's work belongs to that tab, so the tab's editor says it and stays until you act. A notification can be missed and floats over whichever tab you are in; Messages is hidden behind a segment; the footer is too small for 'your work was rolled back'."),
            .of("when", "When", When.self, default: .atOnce,
                question: "Compare the two while doing nothing in the tab. Should Echo tell you before you run anything?",
                recommend: .atOnce,
                why: "Echo now sees the drop as it happens; waiting for the next run means you find out only when you try to COMMIT, which is the worst moment."),
            .of("reconnect", "Reconnect", Reconnect.self, default: .button,
                question: "After the drop, get the tab working again. Which way feels safe?",
                recommend: .button,
                why: "Reconnecting is a new session: SET, temporary tables and the transaction are gone, so it should be a visible step. Reconnecting by itself hides that; relying on the next run makes that run behave differently from the one before."),
            .of("wording", "Wording", Wording.self, default: .plain,
                question: "Read the message in both wordings. Which one tells you what to do?",
                recommend: .plain,
                why: "'server closed the connection unexpectedly' is true but doesn't say that the UPDATEs since BEGIN are gone. The plain wording says the consequence and keeps the server's words under Details."),
            .of("speed", "Speed", LabSpeed.self, default: .standard),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Nothing until the next run, which fails with the error in Messages; the run after that reconnects.",
                  isEchoToday: true, designWidth: width, designHeight: height) { _ in
                PgLostExhibit(options: .today)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Drop the connection with or without a transaction open.",
                  designWidth: width, designHeight: height) { values in
                PgLostExhibit(options: PgLostOptions(values: values))
            },
        ],
        questions: [
            .init(id: "idle", title: "No transaction open",
                  question: "The connection drops while no transaction is open (nothing was lost).",
                  choices: [
                      .init(id: "quiet", name: "I1 · Quietly: footer says Disconnected, reconnects on the next run"),
                      .init(id: "same", name: "I2 · The same banner as when work was lost"),
                  ],
                  recommended: "quiet",
                  why: "Nothing was lost, so interrupting would teach people to dismiss the banner that matters. Only SET and temporary tables are gone, which the footer's word covers."),
            .init(id: "rerun", title: "After reconnecting",
                  question: "The statement you tried to run failed because the connection was gone.",
                  choices: [
                      .init(id: "offer-read", name: "RR1 · Offer 'Run again' for SELECT only"),
                      .init(id: "offer-all", name: "RR2 · Offer 'Run again' for anything"),
                      .init(id: "never", name: "RR3 · Never offer"),
                  ],
                  recommended: "offer-read",
                  why: "Re-running a SELECT is harmless; re-running an UPDATE outside the lost transaction applies it on its own, which is rarely what you meant."),
            .init(id: "history", title: "Notification history",
                  question: "Should the drop also be recorded in the notification history (NTF-3)?",
                  choices: [.init(id: "yes", name: "H1 · Yes"), .init(id: "no", name: "H2 · No")],
                  recommended: "yes",
                  why: "The history records every event (NTF-3.7); a lost transaction is exactly what you want to find later."),
        ],
        exhibitTopic: ("Tell about lost connections?", "Drop the connection in both. Is the proposal clearer about what was lost?",
                       "proposal",
                       "Today you learn about it only when a later run fails, and nothing says the transaction's work is gone."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "CL3, CW2, RC2, WD2.",
                  values: ["where": Where.banner.rawValue, "when": When.atOnce.rawValue, "reconnect": Reconnect.button.rawValue, "wording": Wording.plain.rawValue],
                  isRecommended: true),
            .init(id: "today", name: "Like Echo today", summary: "CL1, CW1, RC1, WD1.",
                  values: ["where": Where.messages.rawValue, "when": When.nextRun.rawValue, "reconnect": Reconnect.nextRun.rawValue, "wording": Wording.technical.rawValue]),
        ]
    )
}

struct PgLostOptions: Equatable {
    var where_: PgConnectionLostRound.Where = .messages
    var when: PgConnectionLostRound.When = .nextRun
    var reconnect: PgConnectionLostRound.Reconnect = .nextRun
    var wording: PgConnectionLostRound.Wording = .technical

    static let today = PgLostOptions()
    init() {}

    @MainActor init(values: RoundValues) {
        where_ = .init(rawValue: values["where"]) ?? .banner
        when = .init(rawValue: values["when"]) ?? .atOnce
        reconnect = .init(rawValue: values["reconnect"]) ?? .button
        wording = .init(rawValue: values["wording"]) ?? .plain
    }
}

struct PgLostExhibit: View {
    let options: PgLostOptions

    private enum Phase: Equatable { case ok, droppedUnnoticed(lostWork: Bool), reported(lostWork: Bool), reconnected }
    @State private var phase: Phase = .ok
    @State private var inTransaction = true
    @State private var messages: [String] = ["BEGIN", "UPDATE 12"]
    @Environment(\.echoMotion) private var motion

    private var reportedLostWork: Bool? {
        if case .reported(let lost) = phase { return lost }
        return nil
    }

    private var headline: String {
        guard let lost = reportedLostWork else { return "" }
        switch options.wording {
        case .technical: return "server closed the connection unexpectedly"
        case .plain: return lost ? "The connection to shop was lost. The transaction was rolled back — nothing since BEGIN was saved." : "The connection to shop was lost."
        }
    }

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            PgTabStrip(tabs: [PgTab(id: 0, title: "Query 1"), PgTab(id: 1, title: "Query 2")], active: 0)
            PgEditorCard(lines: ["BEGIN;", "UPDATE products SET price = price * 1.1", "  WHERE category = 'books';", "COMMIT;"], highlightedLine: 3) { index in
                if index == 3, options.where_ == .footer, reportedLostWork != nil {
                    Text("   ! Connection lost").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.error)
                        .padding(.leading, SpacingTokens.xxl)
                }
            }
            .overlay(alignment: .top) {
                if options.where_ == .banner, let lost = reportedLostWork { banner(lost: lost) }
            }
            .overlay(alignment: .topTrailing) {
                if options.where_ == .toast, reportedLostWork != nil { toast.padding(SpacingTokens.xs) }
            }
            resultsCard
            PgSimBar(actions: [
                ("Drops, in a transaction", { drop(lostWork: true) }), ("Drops, idle", { drop(lostWork: false) }),
                ("Run COMMIT", { run() }), ("Reset", { phase = .ok; messages = ["BEGIN", "UPDATE 12"] }),
            ])
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas)
        .animation(motion.standard, value: phase)
    }

    private func banner(lost: Bool) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.sm) {
            Image(systemName: "bolt.horizontal.circle.fill").foregroundStyle(lost ? ColorTokens.Status.error : ColorTokens.Status.warning)
            VStack(alignment: .leading, spacing: SpacingTokens.nano) {
                Text(headline).font(TypographyTokens.labelBold).fixedSize(horizontal: false, vertical: true)
                if options.wording == .plain {
                    Text("Details: server closed the connection unexpectedly").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            Spacer(minLength: SpacingTokens.sm)
            if options.reconnect == .button { Button("Reconnect") { reconnect() }.controlSize(.small) }
            Button { phase = .ok } label: { Image(systemName: "xmark") }.buttonStyle(.plain).foregroundStyle(ColorTokens.Text.tertiary)
        }
        .padding(SpacingTokens.sm)
        .frame(minWidth: 300)
        .background((lost ? ColorTokens.Status.error : ColorTokens.Status.warning).opacity(0.12), in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.medium))
        .padding(SpacingTokens.xs)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var toast: some View {
        HStack(alignment: .top, spacing: SpacingTokens.xs) {
            Image(systemName: "bolt.horizontal.circle.fill").foregroundStyle(ColorTokens.Status.error)
            VStack(alignment: .leading, spacing: SpacingTokens.nano) {
                Text("Query 1: connection lost").font(TypographyTokens.labelBold)
                Text(headline).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).lineLimit(3)
                if options.reconnect == .button { Button("Reconnect") { reconnect() }.controlSize(.small) }
            }
        }
        .padding(SpacingTokens.sm)
        .frame(width: 260, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.large))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            ForEach(Array(messages.suffix(3).enumerated()), id: \.offset) { _, message in
                Text(message).font(TypographyTokens.detail)
                    .foregroundStyle(message.hasPrefix("ERROR") ? ColorTokens.Status.error : ColorTokens.Text.secondary)
            }
            Spacer(minLength: SpacingTokens.none)
            PgFooter(segment: "Messages") {
                switch phase {
                case .reported, .droppedUnnoticed where options.when == .atOnce:
                    PgPill(tint: ColorTokens.Status.error) {
                        PgStatusLabel(text: "Disconnected", color: ColorTokens.Status.error)
                        if options.where_ == .footer, options.reconnect == .button {
                            Button("Reconnect") { reconnect() }.buttonStyle(.plain).foregroundStyle(ColorTokens.accent)
                        }
                    }
                case .reconnected:
                    PgPill { PgStatusLabel(text: "Reconnected · new session", color: ColorTokens.Status.success) }
                default:
                    PgPill { PgStatusLabel(text: "Ready", color: ColorTokens.Status.success) }
                }
            }
        }
        .padding(.top, SpacingTokens.sm)
        .padding(.horizontal, SpacingTokens.sm)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .workspaceCard()
    }

    private func drop(lostWork: Bool) {
        if options.when == .atOnce {
            if options.reconnect == .automatic {
                messages.append(lostWork ? "Connection lost; the transaction was rolled back. Reconnected (new session)." : "Connection lost. Reconnected (new session).")
                phase = .reconnected
            } else {
                phase = .reported(lostWork: lostWork)
                if options.where_ == .messages { messages.append("ERROR: " + (lostWork ? "connection lost; the transaction was rolled back" : "connection lost")) }
            }
        } else {
            phase = .droppedUnnoticed(lostWork: lostWork)
        }
    }

    private func run() {
        switch phase {
        case .droppedUnnoticed(let lost):
            phase = .reported(lostWork: lost)
            messages.append("ERROR: " + (options.wording == .technical ? "server closed the connection unexpectedly" : "The connection was lost; the transaction was rolled back."))
        case .reported:
            if options.reconnect == .nextRun { messages.append("Reconnected. WARNING: there is no transaction in progress"); phase = .reconnected }
            else { messages.append("ERROR: not connected — press Reconnect") }
        default:
            messages.append("COMMIT")
        }
    }

    private func reconnect() {
        messages.append("Reconnected to shop (new session: SET and temporary tables are gone).")
        phase = .reconnected
    }
}
