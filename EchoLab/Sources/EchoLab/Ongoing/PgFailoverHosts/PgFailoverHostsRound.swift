import SwiftUI

/// Round 23 · PostgreSQL: several servers and failover. postgres-wire now takes a list of servers
/// (libpq's `host=a,b`), connects to the first that fits "Connect to" (`target_session_attrs`: any,
/// primary, standby, prefer standby, read-write, read-only), and moves the pool to another server
/// when its server goes away or turns into a standby. Echo's sheet has one Server field, and a
/// pasted `postgres://db1,db2/app` URL is not understood. Touches CON-2.3 (Server), CON-4.1 and
/// CON-4.3 (the disclosure), CON-6.2 (Test) and the footer's server chip.
@MainActor
enum PgFailoverHostsRound {
    enum Hosts: String, CaseIterable {
        case rows = "FH1 · '+ Add Server': one row per server"
        case commas = "FH2 · Commas in the Server field (db1, db2:5433)"
        case disclosure = "FH3 · A Servers list in Security and timeouts"
    }
    enum Target: String, CaseIterable {
        case plain = "FT1 · Plain words (Any server, Primary, Standby…)"
        case libpq = "FT2 · libpq's words (any, read-write, prefer-standby…)"
    }
    enum TargetPlace: String, CaseIterable {
        case withServers = "FW1 · Under the servers, once there are two"
        case disclosure = "FW2 · Always, in Security and timeouts"
    }
    enum Balance: String, CaseIterable {
        case hidden = "FL1 · Not shown (a pasted URL can still set it)"
        case toggle = "FL2 · A 'Spread connections across servers' switch"
    }
    enum Moved: String, CaseIterable {
        case chipAndNotice = "FS1 · Footer chip names the server, and a notification when it changes"
        case notice = "FS2 · A notification only"
        case none = "FS3 · Nothing; Test names the server"
    }

    private static let width: CGFloat = 540
    private static let height: CGFloat = 560

    static let spec = RoundSpec(
        controls: [
            .of("hosts", "Servers", Hosts.self, default: .rows,
                question: "Add a standby server in the Proposal. Which way of listing servers is clear and easy to edit?",
                recommend: .rows,
                why: "One row per server keeps the sheet's 'server : port' shape, gives each its own port and a remove button, and a pasted list or URL simply fills the rows. Commas are what libpq wants but are easy to mistype and cut off in the field; a list in the disclosure hides the one setting that decides where you connect."),
            .of("target", "Connect to words", Target.self, default: .plain,
                question: "Open the Connect to menu. Does each item say which server you get?",
                recommend: .plain,
                why: "'Primary' and 'Standby' are the words DBAs and cloud consoles use; libpq's strings are precise but read like settings. The two read-write and read-only variants are kept for pasted URLs rather than the menu, since they differ from primary and standby only on unusual servers."),
            .of("targetPlace", "Connect to place", TargetPlace.self, default: .withServers,
                question: "Remove the second server. Should Connect to stay?",
                recommend: .withServers,
                why: "It only matters when there is a choice of servers, and it belongs next to them. With one server it would mean 'refuse to connect unless it is the primary', which almost no one wants from a desktop client; a URL can still ask for it."),
            .of("balance", "Load balancing", Balance.self, default: .hidden,
                question: "Decide whether spreading connections belongs in the sheet.",
                recommend: .hidden,
                why: "Load balancing matters for fleets of app servers; one person's Echo opens a handful of connections, and a random server makes 'which one am I on?' harder. A pasted URL with load_balance_hosts still turns it on."),
            .of("moved", "After a failover", Moved.self, default: .chipAndNotice,
                question: "Look at the 'After a failover' exhibit. How should you learn that Echo moved to another server?",
                recommend: .chipAndNotice,
                why: "After a failover your next statement runs on another machine, so it should be visible all the time and announced once, the way round 21 decided a lost connection is told (Messages and a notification). This needs a small driver hook so the pool reports the server it moved to."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "One server. A pasted multi-server URL is not understood.",
                  isEchoToday: true, designWidth: width, designHeight: height) { _ in
                PgConnSheet {
                    PgConnServerSection(host: "db1.corp.example.com")
                    PgConnSection(header: "Sign In") {
                        PgConnRow(title: "Method") { PgConnMenu(text: "Set Manually") }
                        PgConnRow(title: "Username") { PgConnValue(text: "alice") }
                        PgConnRow(title: "Password") { PgConnValue(text: "set", secure: true) }
                    }
                    PgConnSection {
                        PgConnDisclosure(summary: "TLS prefer · 30 s", expanded: false)
                    }
                    PgConnTestBar(result: "Could not connect to db1.corp.example.com:5432: connection refused.")
                }
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. db1 is the primary, db2 a standby.",
                  designWidth: width, designHeight: height) { values in
                PgFailoverProposal(
                    hosts: Hosts(rawValue: values["hosts"]) ?? .rows,
                    target: Target(rawValue: values["target"]) ?? .plain,
                    targetPlace: TargetPlace(rawValue: values["targetPlace"]) ?? .withServers,
                    balance: Balance(rawValue: values["balance"]) ?? .hidden)
            },
            .init(id: "moved", title: "After a failover", summary: "db1 went down; Echo reconnected to db2, now the primary.",
                  designWidth: width, designHeight: 230) { values in
                PgFailoverMovedExhibit(moved: Moved(rawValue: values["moved"]) ?? .chipAndNotice)
            },
        ],
        questions: [
            .init(id: "test", title: "Test with several servers",
                  question: "Pressing Test with two servers. What should it check?",
                  choices: [
                      .init(id: "each", name: "TS1 · Every server, one line each (db1 ✓ primary · db2 ✓ standby)"),
                      .init(id: "first", name: "TS2 · Only what connecting would do: the first server that fits"),
                  ],
                  recommended: "each",
                  why: "A standby with a wrong password or a closed firewall is only found when you need it most; testing each costs one quick connection per server and the result line still ends with where Echo would connect."),
            .init(id: "openTabs", title: "Query tabs during a failover",
                  question: "A query tab's own connection was on db1 when it went down. What happens to the tab?",
                  choices: [
                      .init(id: "lost", name: "FR1 · 'Connection lost' as round 21 decided; Reconnect goes to the new primary"),
                      .init(id: "silent", name: "FR2 · Reconnect to the new primary without asking"),
                  ],
                  recommended: "lost",
                  why: "The tab's transaction, temp tables and settings were on db1 and are gone; reconnecting silently would hide that. The driver retries only calls that never reached a server, so Echo's explorer and metadata move on their own."),
            .init(id: "paste", title: "Pasting a URL with several servers",
                  question: "Should Server accept postgres://db1,db2:5433/app?target_session_attrs=primary?",
                  choices: [
                      .init(id: "fill", name: "PU1 · Yes: fill a row per server and set Connect to"),
                      .init(id: "no", name: "PU2 · No, one server only (today)"),
                  ],
                  recommended: "fill",
                  why: "It is the form cloud consoles and DBAs hand out for HA clusters, and the driver understands it; today the paste is silently ignored."),
        ],
        exhibitTopic: ("Ready for a cluster?", "Set up db1 and db2 in the Proposal and look at 'After a failover', then compare with Echo today.",
                       "proposal",
                       "It lists both servers, says which one you want and shows which one you are on; today Echo can reach only one, and a failover is a dead connection."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "FH1, FT1, FW1, FL1, FS1.",
                  values: ["hosts": Hosts.rows.rawValue, "target": Target.plain.rawValue,
                           "targetPlace": TargetPlace.withServers.rawValue, "balance": Balance.hidden.rawValue,
                           "moved": Moved.chipAndNotice.rawValue], isRecommended: true),
            .init(id: "libpq", name: "Like libpq", summary: "FH2, FT2, FW2, FL2: every option, in libpq's terms.",
                  values: ["hosts": Hosts.commas.rawValue, "target": Target.libpq.rawValue,
                           "targetPlace": TargetPlace.disclosure.rawValue, "balance": Balance.toggle.rawValue,
                           "moved": Moved.notice.rawValue]),
        ]
    )
}

struct PgFailoverProposal: View {
    let hosts: PgFailoverHostsRound.Hosts
    let target: PgFailoverHostsRound.Target
    let targetPlace: PgFailoverHostsRound.TargetPlace
    let balance: PgFailoverHostsRound.Balance

    private var targetText: String { target == .plain ? "Primary" : "primary" }

    var body: some View {
        PgConnSheet {
            serverSection
            PgConnSection(header: "Sign In") {
                PgConnRow(title: "Method") { PgConnMenu(text: "Set Manually") }
                PgConnRow(title: "Username") { PgConnValue(text: "alice") }
                PgConnRow(title: "Password") { PgConnValue(text: "set", secure: true) }
            }
            PgConnSection {
                PgConnDisclosure(summary: "2 servers · \(targetText) · TLS prefer · 30 s", expanded: hosts == .disclosure || targetPlace == .disclosure || balance == .toggle)
                if hosts == .disclosure {
                    PgConnRow(title: "Other Servers", info: true, highlighted: true) {
                        VStack(alignment: .trailing, spacing: SpacingTokens.xxs) {
                            PgConnValue(text: "db2.corp.example.com : 5432")
                            Button("Add Server…") {}.controlSize(.small)
                        }
                    }
                }
                if targetPlace == .disclosure { targetRow }
                if balance == .toggle {
                    PgConnRow(title: "Spread Connections Across Servers", info: true, highlighted: true) { PgConnSwitch(isOn: false) }
                }
            }
            PgConnTestBar(result: "db1 ✓ primary · db2 ✓ standby · connects to db1", kind: .success)
        }
    }

    @ViewBuilder private var serverSection: some View {
        switch hosts {
        case .rows:
            PgConnServerSection(host: "db1.corp.example.com") {
                PgConnRow(title: "", highlighted: true) {
                    HStack(spacing: SpacingTokens.xxs2) {
                        PgConnValue(text: "db2.corp.example.com")
                        Text(":").foregroundStyle(ColorTokens.Text.tertiary)
                        PgConnValue(text: "5432", prompt: true)
                        Image(systemName: "minus.circle.fill").foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
                Button { } label: { SwiftUI.Label("Add Server", systemImage: "plus") }
                    .buttonStyle(.borderless).font(TypographyTokens.formDescription)
                if targetPlace == .withServers { targetRow }
            }
        case .commas:
            PgConnServerSection(host: "db1.corp.example.com, db2.corp.example.com", port: "5432") {
                PgConnNote(text: "Separate servers with commas; add :port to a server that uses another port.")
                if targetPlace == .withServers { targetRow }
            }
        case .disclosure:
            PgConnServerSection(host: "db1.corp.example.com") {
                if targetPlace == .withServers { targetRow }
            }
        }
    }

    private var targetRow: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            PgConnRow(title: "Connect To", info: true, highlighted: true) { PgConnMenu(text: targetText) }
            PgConnNote(text: target == .plain
                ? "Menu: Any Server · Primary · Standby · Standby, or Any if None Is Up"
                : "Menu: any · read-write · read-only · primary · standby · prefer-standby")
        }
    }
}

/// What the workspace shows once Echo has moved to db2.
struct PgFailoverMovedExhibit: View {
    let moved: PgFailoverHostsRound.Moved

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            if moved != .none {
                HStack(alignment: .top, spacing: SpacingTokens.xs) {
                    Image(systemName: "arrow.triangle.swap").foregroundStyle(ColorTokens.Status.warning)
                    VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                        Text("Reporting moved to db2").font(TypographyTokens.formLabel.weight(.semibold))
                        Text("db1.corp.example.com stopped answering. Echo reconnected to db2.corp.example.com, the primary now. Query tabs that were on db1 lost their connection.")
                            .font(TypographyTokens.formDescription).foregroundStyle(ColorTokens.Text.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(SpacingTokens.sm)
                .frame(minWidth: 300, maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.Text.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.small))
            } else {
                Text("No notice. The next Test or the server's own name in a query shows where you are.")
                    .font(TypographyTokens.formDescription).foregroundStyle(ColorTokens.Text.tertiary)
                    .frame(minWidth: 300, alignment: .leading)
            }
            Spacer(minLength: SpacingTokens.none)
            HStack(spacing: SpacingTokens.xs) {
                chip("Reporting", icon: "cylinder.split.1x2")
                if moved == .chipAndNotice {
                    chip("db2 · primary", icon: "arrow.triangle.swap", tint: ColorTokens.Status.warning)
                        .help("Moved from db1 at 14:02")
                }
                chip("reporting", icon: "cylinder")
                Spacer()
                Text("Ready").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xxs2)
            .background(ColorTokens.Text.primary.opacity(0.04))
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
    }

    private func chip(_ text: String, icon: String, tint: Color = ColorTokens.Text.secondary) -> some View {
        SwiftUI.Label(text, systemImage: icon)
            .font(TypographyTokens.detail)
            .foregroundStyle(tint)
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, SpacingTokens.xxxs)
            .background(tint.opacity(0.1), in: Capsule())
    }
}
