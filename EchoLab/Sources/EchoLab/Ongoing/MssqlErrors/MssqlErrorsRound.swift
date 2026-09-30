import SwiftUI

/// Round 22 · SQL Server: errors and messages. sqlserver-nio now reports every server error with
/// its number, severity, state, line and procedure, keeps all messages of the batch in order, and
/// tells a COMMIT that SQL Server refused apart from one whose outcome is unknown because the
/// connection dropped. Echo today shows only "Query execution failed: <text>". Touches EDT-3.3
/// (run note), FTR-2.3 (Messages) and FTR-2.6 (status pill); the in-editor mark follows the
/// Postgres error-location page of round 21.
@MainActor
enum MssqlErrorsRound {
    enum Header: String, CaseIterable {
        case ssms = "EM1 · SSMS line: Msg 547, Level 16, State 0, Line 3"
        case compact = "EM2 · Compact: Error 547 · line 3"
        case today = "EM3 · Message only (today)"
    }
    enum LineLink: String, CaseIterable {
        case link = "LL1 · 'Line 3' selects the line in the editor"
        case plain = "LL2 · Plain text"
    }

    private static let width: CGFloat = 620
    private static let height: CGFloat = 420

    static let spec = RoundSpec(
        controls: [
            .of("header", "Error header", Header.self, default: .ssms,
                question: "Read the Messages pane in both. Which header lets you look the error up and find the statement?",
                recommend: .ssms,
                why: "It is the exact line SSMS and sqlcmd print, so it matches documentation, search results and what colleagues paste. The number finds the error, the level says how serious it is, and the line says where. The compact form hides severity; message-only hides everything but the text."),
            .of("link", "Line", LineLink.self, default: .link,
                question: "Click 'Line 3'. Should it take you to the statement?",
                recommend: .link,
                why: "In a long script the line number is the only way to find the statement; one click is quicker than counting. It matches the Postgres error location page."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "One line: 'Query execution failed:' and the first error's text. The PRINT output before it, the line, the number and the second error are lost.",
                  isEchoToday: true, designWidth: width, designHeight: height) { _ in
                MssqlErrorsExhibit(header: .today, link: .plain)
            },
            .init(id: "proposal", title: "Proposal", summary: "Every message of the batch, in order, each with its header.",
                  designWidth: width, designHeight: height) { values in
                MssqlErrorsExhibit(header: Header(rawValue: values["header"]) ?? .ssms,
                                   link: LineLink(rawValue: values["link"]) ?? .link)
            },
        ],
        questions: [
            .init(id: "all", title: "Several errors from one statement",
                  question: "SQL Server often sends two errors for one failure (547, then 3621 'The statement has been terminated'). Show both?",
                  choices: [
                      .init(id: "all", name: "AM1 · All messages, in the order the server sent them"),
                      .init(id: "first", name: "AM2 · Only the first error"),
                  ],
                  recommended: "all",
                  why: "The second message says the statement was stopped (not the batch), which decides whether later statements ran. SSMS shows both."),
            .init(id: "unknown", title: "COMMIT with an unknown outcome",
                  question: "If the connection drops while COMMIT is in flight, nobody knows whether the transaction was saved. What should Echo say?",
                  choices: [
                      .init(id: "explain", name: "CU1 · 'The connection was lost during COMMIT. The transaction may or may not have been saved; check the data before running it again.'"),
                      .init(id: "generic", name: "CU2 · 'Connection lost' (like any other drop)"),
                  ],
                  recommended: "explain",
                  why: "Running the script again after a commit that did succeed writes everything twice. The driver can tell this case apart, so Echo should say so; a generic message invites the retry."),
            .init(id: "fatal", title: "Errors that end the session",
                  question: "Severity 20 and above ends the session on the server (for example a KILL). How should that read?",
                  choices: [
                      .init(id: "lost", name: "FE1 · As a lost connection (round 22 cancel page), with the server's message"),
                      .init(id: "error", name: "FE2 · As a normal error"),
                  ],
                  recommended: "lost",
                  why: "The tab's temporary tables, SET options and open transaction are gone; treating it as a normal error lets you run the next statement in a session that no longer exists."),
            .init(id: "editor", title: "Mark in the editor",
                  question: "Should the statement with the error be marked in the editor the way the Postgres error-location page decides?",
                  choices: [
                      .init(id: "same", name: "ED1 · Yes, the same design for both engines"),
                      .init(id: "none", name: "ED2 · No mark for SQL Server"),
                  ],
                  recommended: "same",
                  why: "SQL Server reports a line, not a character position, so the mark covers the line; everything else can follow the Postgres decision, so there is one rule to learn."),
        ],
        exhibitTopic: ("Easier to act on?", "Compare the Messages panes. Which one tells you what failed, how badly and where?",
                       "proposal",
                       "It keeps the number, severity, line and the second message that Echo today drops."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "EM1, LL1.",
                  values: ["header": Header.ssms.rawValue, "link": LineLink.link.rawValue], isRecommended: true),
        ]
    )
}

struct MssqlErrorsExhibit: View {
    typealias R = MssqlErrorsRound
    let header: R.Header
    let link: R.LineLink
    @State private var selectedLine: Int?

    private let firstError = "The INSERT statement conflicted with the FOREIGN KEY constraint \"FK_orders_customer\". The conflict occurred in database \"Sales\", table \"dbo.customer\", column 'id'."

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            PgEditorCard(lines: ["PRINT 'Loading orders';",
                                 "BEGIN TRANSACTION;",
                                 "INSERT INTO dbo.orders (customer_id, total) VALUES (999, 10);",
                                 "COMMIT;"],
                         highlightedLine: selectedLine)
                .frame(height: 150)
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                if header == .today {
                    Text("Query execution failed: \(firstError)")
                        .font(TypographyTokens.detailMono).foregroundStyle(ColorTokens.Status.error)
                } else {
                    Text("Loading orders").font(TypographyTokens.detailMono)
                    message(number: 547, level: 16, state: 0, line: 3, text: firstError)
                    message(number: 3621, level: 0, state: 0, line: 3, text: "The statement has been terminated.")
                }
                Spacer(minLength: SpacingTokens.none)
            }
            .padding(SpacingTokens.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .workspaceCard()
            PgFooter(segment: "Messages", database: "sql01 · Sales") {
                PgPill(tint: ColorTokens.Status.error) { PgStatusLabel(text: "Failed", color: ColorTokens.Status.error) }
            }
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas)
    }

    @ViewBuilder
    private func message(number: Int, level: Int, state: Int, line: Int, text: String) -> some View {
        let colour = level >= 11 ? ColorTokens.Status.error : ColorTokens.Text.primary
        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            HStack(spacing: SpacingTokens.xxs) {
                switch header {
                case .ssms:
                    Text("Msg \(number), Level \(level), State \(state),")
                    lineText(line, label: "Line \(line)")
                case .compact:
                    Text("Error \(number) ·")
                    lineText(line, label: "line \(line)")
                case .today:
                    EmptyView()
                }
            }
            .font(TypographyTokens.detailMono)
            .foregroundStyle(colour)
            Text(text).font(TypographyTokens.detailMono).foregroundStyle(colour)
        }
    }

    @ViewBuilder
    private func lineText(_ line: Int, label: String) -> some View {
        if link == .link {
            Button(label) { selectedLine = line - 1 }
                .buttonStyle(.link)
                .font(TypographyTokens.detailMono)
        } else {
            Text(label)
        }
    }
}
