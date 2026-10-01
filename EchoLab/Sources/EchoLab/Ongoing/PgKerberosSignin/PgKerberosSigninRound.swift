import SwiftUI

/// Round 23 · PostgreSQL: Kerberos sign-in. postgres-wire now signs in with the user's Kerberos
/// ticket whenever the server asks for it (GSSAPI, on macOS and Linux; service `postgres` unless
/// set). Echo already leaves the PostgreSQL password optional, so a Kerberos server works today if
/// you leave it empty, but the sheet never says so: nothing names Kerberos, shows whose ticket is
/// used, or sets the service name, and a missing ticket fails with GSS's own words.
/// Touches CON-3.1 and CON-3.2 (Sign In), CON-4.3 (PostgreSQL rows) and CON-6.2 (Test).
@MainActor
enum PgKerberosSigninRound {
    enum Placement: String, CaseIterable {
        case mechanism = "KP1 · Mechanism menu: Password or Kerberos"
        case automatic = "KP2 · No menu: leave the password empty"
        case toggle = "KP3 · A 'Use Kerberos ticket' switch"
    }
    enum Naming: String, CaseIterable {
        case kerberos = "KN1 · Kerberos"
        case singleSignOn = "KN2 · Kerberos (single sign-on)"
        case windows = "KN3 · Windows integrated"
    }
    enum Ticket: String, CaseIterable {
        case shown = "KT1 · Show whose ticket, and when it expires"
        case hidden = "KT2 · No line; problems show at Test"
    }
    enum Service: String, CaseIterable {
        case disclosure = "KS1 · In Security and timeouts, only for Kerberos"
        case signIn = "KS2 · In Sign In, under the mechanism"
        case urlOnly = "KS3 · Not shown (connection URL's krbsrvname only)"
    }
    enum Username: String, CaseIterable {
        case prefill = "KU1 · Filled in from the ticket (alice), editable"
        case empty = "KU2 · Left for you to type"
    }
    enum Sample: String, CaseIterable {
        case valid = "Ticket for alice@CORP.EXAMPLE.COM"
        case expired = "Ticket expired"
        case none = "No ticket"
    }

    private static let width: CGFloat = 520
    private static let height: CGFloat = 470

    static let spec = RoundSpec(
        controls: [
            .of("placement", "Where", Placement.self, default: .mechanism,
                question: "Set up a Kerberos connection in the Proposal. Where should you say 'use my ticket'?",
                recommend: .mechanism,
                why: "It is how the sheet already offers SQL Server's Windows sign-in (CON-3.2: a Mechanism menu when the engine offers more than one), and choosing it hides the password so none is saved by mistake. KP2 adds nothing to click but only a note tells you Kerberos exists; KP3 is a second kind of control for the same idea."),
            .of("naming", "Name", Naming.self, default: .kerberos,
                question: "Read the mechanism's name. Would someone at a company with Active Directory recognise it?",
                recommend: .kerberos,
                why: "PostgreSQL's documentation, pgAdmin and DataGrip all say Kerberos, and it is also what AD uses underneath. 'Single sign-on' is friendlier but longer in a menu; 'Windows integrated' is wrong on a Mac or Linux KDC and is SQL Server's word."),
            .of("ticket", "Ticket line", Ticket.self, default: .shown,
                question: "Switch the sample between a valid, expired and missing ticket. Does the line tell you what will happen before you press Test?",
                recommend: .shown,
                why: "Almost every Kerberos failure is a missing or expired ticket; saying so before Test saves a round trip and names the fix. Reading the ticket is a local call and costs nothing. Without it you learn at Test, in the driver's words."),
            .of("service", "Service name", Service.self, default: .disclosure,
                question: "Find where the service name is set. Is it out of the way but findable?",
                recommend: .disclosure,
                why: "It is 'postgres' on nearly every server (libpq's krbsrvname) and only a DBA changes it, so it belongs with the rarely touched rows. In Sign In it takes a line from everyone; hiding it entirely strands the few servers that use another name."),
            .of("username", "User name", Username.self, default: .prefill,
                question: "Pick Kerberos with an empty User name. Should Echo fill it in?",
                recommend: .prefill,
                why: "PostgreSQL maps the ticket's name to a role, usually the name without the realm, so 'alice' is right most of the time; it stays editable for servers with a mapping. Leaving it empty means typing what Echo already knows."),
            .of("sample", "Sample", Sample.self, default: .valid),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Set Manually, user and password. An empty password already uses a ticket, but nothing says so.",
                  isEchoToday: true, designWidth: width, designHeight: height) { _ in
                PgConnSheet {
                    PgConnServerSection()
                    PgConnSection(header: "Sign In") {
                        PgConnRow(title: "Method") { PgConnMenu(text: "Set Manually") }
                        PgConnRow(title: "Username") { PgConnValue(text: "username", prompt: true) }
                        PgConnRow(title: "Password") { PgConnValue(text: "password", prompt: true) }
                    }
                    PgConnSection {
                        PgConnDisclosure(summary: "TLS prefer · 30 s", expanded: false)
                    }
                    PgConnTestBar(result: "Unspecified GSS failure. Minor code may provide more information (No Kerberos credentials available)")
                }
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls.",
                  designWidth: width, designHeight: height) { values in
                PgKerberosProposal(
                    placement: Placement(rawValue: values["placement"]) ?? .mechanism,
                    naming: Naming(rawValue: values["naming"]) ?? .kerberos,
                    ticket: Ticket(rawValue: values["ticket"]) ?? .shown,
                    service: Service(rawValue: values["service"]) ?? .disclosure,
                    username: Username(rawValue: values["username"]) ?? .prefill,
                    sample: Sample(rawValue: values["sample"]) ?? .valid)
            },
        ],
        questions: [
            .init(id: "noTicket", title: "Test without a ticket",
                  question: "Test runs with no ticket (or an expired one). What should the result line offer?",
                  choices: [
                      .init(id: "viewer", name: "NT1 · 'No Kerberos ticket' and an Open Ticket Viewer button",
                            summary: "macOS: Ticket Viewer. Linux: the line names kinit."),
                      .init(id: "plain", name: "NT2 · The driver's error text (today)"),
                  ],
                  recommended: "viewer",
                  why: "Getting a ticket is the fix every time, and Ticket Viewer is where a Mac user gets one; GSS's message ('No Kerberos credentials available') is accurate but tells no one what to do."),
            .init(id: "wrongMethod", title: "The server asks for a password instead",
                  question: "Kerberos is chosen but the server's pg_hba.conf asks for a password. What should happen?",
                  choices: [
                      .init(id: "explain", name: "KF1 · Fail: 'The server asks for a password, not Kerberos', with a Use Password button"),
                      .init(id: "prompt", name: "KF2 · Ask for the password in a dialog and connect"),
                  ],
                  recommended: "explain",
                  why: "Choosing Kerberos is a promise that no password is sent; a surprise password dialog would break it, and a saved connection would keep asking. One click switches the mechanism when the password is what's meant."),
            .init(id: "passwordMode", title: "A Password connection to a Kerberos server",
                  question: "Password is chosen, but the server asks for Kerberos. libpq and today's driver use the ticket anyway. Keep that?",
                  choices: [
                      .init(id: "useTicket", name: "PK1 · Yes, use the ticket (libpq does)"),
                      .init(id: "refuse", name: "PK2 · No, fail and point to the Mechanism menu"),
                  ],
                  recommended: "useTicket",
                  why: "Connections saved before this round have Password and would stop working on Kerberos servers where they work today. The server decides how you sign in; the menu decides what Echo stores."),
        ],
        exhibitTopic: ("Clear enough to set up?", "Set up a Kerberos connection in the Proposal, then compare it with Echo today.",
                       "proposal",
                       "It names Kerberos, shows whose ticket signs in and says what to do without one; today works only if you already know to leave the password empty."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "KP1, KN1, KT1, KS1, KU1.",
                  values: ["placement": Placement.mechanism.rawValue, "naming": Naming.kerberos.rawValue,
                           "ticket": Ticket.shown.rawValue, "service": Service.disclosure.rawValue,
                           "username": Username.prefill.rawValue], isRecommended: true),
            .init(id: "minimal", name: "Smallest change", summary: "KP2, KT2, KS3: a note under Password only.",
                  values: ["placement": Placement.automatic.rawValue, "naming": Naming.kerberos.rawValue,
                           "ticket": Ticket.hidden.rawValue, "service": Service.urlOnly.rawValue,
                           "username": Username.empty.rawValue]),
        ]
    )
}

/// The proposal's Sign In section and disclosure.
struct PgKerberosProposal: View {
    let placement: PgKerberosSigninRound.Placement
    let naming: PgKerberosSigninRound.Naming
    let ticket: PgKerberosSigninRound.Ticket
    let service: PgKerberosSigninRound.Service
    let username: PgKerberosSigninRound.Username
    let sample: PgKerberosSigninRound.Sample

    private var name: String {
        switch naming {
        case .kerberos: "Kerberos"
        case .singleSignOn: "Kerberos (single sign-on)"
        case .windows: "Windows integrated"
        }
    }

    private var ticketNote: (String, String, Color) {
        switch sample {
        case .valid: ("Signed in as alice@CORP.EXAMPLE.COM · ticket valid until 18:40", "checkmark.seal.fill", ColorTokens.Status.success)
        case .expired: ("Your ticket for alice@CORP.EXAMPLE.COM expired at 09:12. Renew it in Ticket Viewer.", "clock.badge.exclamationmark", ColorTokens.Status.warning)
        case .none: ("No Kerberos ticket. Get one in Ticket Viewer, or with kinit.", "exclamationmark.triangle.fill", ColorTokens.Status.warning)
        }
    }

    var body: some View {
        PgConnSheet {
            PgConnServerSection()
            PgConnSection(header: "Sign In") {
                PgConnRow(title: "Method") { PgConnMenu(text: "Set Manually") }
                switch placement {
                case .mechanism:
                    PgConnRow(title: "Mechanism", highlighted: true) { PgConnMenu(text: name) }
                    userRow
                    ticketRows
                    serviceInSignIn
                case .automatic:
                    userRow
                    PgConnRow(title: "Password") { PgConnValue(text: "Leave empty for \(name)", prompt: true) }
                    PgConnNote(text: "With no password, Echo signs in with your \(name) ticket when the server asks for it.")
                    ticketRows
                    serviceInSignIn
                case .toggle:
                    PgConnRow(title: "Use \(naming == .windows ? "Windows sign-in" : "Kerberos Ticket")", highlighted: true) { PgConnSwitch(isOn: true) }
                    userRow
                    ticketRows
                    serviceInSignIn
                }
            }
            PgConnSection {
                PgConnDisclosure(summary: "TLS prefer · \(name.components(separatedBy: " (").first ?? name) · 30 s")
                PgConnRow(title: "SSL Mode", info: true) { PgConnMenu(text: "Prefer - Try SSL first, fall back to non-SSL") }
                if service == .disclosure {
                    PgConnRow(title: "Kerberos Service", info: true, highlighted: true) { PgConnValue(text: "postgres", prompt: true) }
                }
                PgConnRow(title: "Connection Timeout") { PgConnValue(text: "30 seconds", prompt: true) }
            }
        }
    }

    @ViewBuilder private var userRow: some View {
        PgConnRow(title: "Username") {
            PgConnValue(text: username == .prefill && sample != .none ? "alice" : "username", prompt: username == .empty || sample == .none)
        }
    }

    @ViewBuilder private var ticketRows: some View {
        if ticket == .shown {
            let note = ticketNote
            HStack(spacing: SpacingTokens.xs) {
                PgConnNote(text: note.0, icon: note.1, color: note.2)
                if sample != .valid { Button("Open Ticket Viewer") {}.controlSize(.small).fixedSize() }
            }
        }
    }

    @ViewBuilder private var serviceInSignIn: some View {
        if service == .signIn {
            PgConnRow(title: "Service", info: true, highlighted: true) { PgConnValue(text: "postgres", prompt: true) }
        }
    }
}
