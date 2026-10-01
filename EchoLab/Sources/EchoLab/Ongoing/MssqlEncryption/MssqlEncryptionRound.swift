import SwiftUI

/// Round 22 · SQL Server: encryption settings. The sheet's words no longer match what happens.
/// Today "Optional – Use encryption if available" (the default) sends no TLS configuration, and
/// the previous driver then sent the login, password included, without encryption. sqlserver-nio now
/// never sends credentials unencrypted: Optional encrypts the whole session without checking the
/// certificate, Mandatory encrypts and checks it (and checks that it names the server), and Strict
/// is TDS 8.0 with TLS before anything else. Touches CON-4.2 (SQL Server rows) and CON-6.2 (Test).
@MainActor
enum MssqlEncryptionRound {
    enum Default: String, CaseIterable {
        case mandatory = "ED1 · Mandatory for new connections"
        case optional = "ED2 · Optional (today)"
    }
    enum Wording: String, CaseIterable {
        case plain = "EW1 · Say what is checked"
        case ssms = "EW2 · SSMS's words only"
    }
    enum StrictTrust: String, CaseIterable {
        case disabled = "ST1 · Trust switch turns off and dims under Strict"
        case shown = "ST2 · Leave the switch; the test fails with an explanation"
    }

    private static let width: CGFloat = 560
    private static let height: CGFloat = 330

    static let spec = RoundSpec(
        controls: [
            .of("default", "Default", Default.self, default: .mandatory,
                question: "Open a new SQL Server connection in both. Which encryption should it start with?",
                recommend: .mandatory,
                why: "Mandatory is what ODBC 18, JDBC and SSMS 20 default to: it encrypts and proves the server is the one you meant. Optional also encrypts now, but without checking the certificate anyone on the path can pose as the server and read the password."),
            .of("wording", "Menu words", Wording.self, default: .plain,
                question: "Read the menu and the info text. Do they tell you what you get?",
                recommend: .plain,
                why: "The three modes differ in one thing people need to know, whether the certificate is checked; saying it in the menu avoids the info popover. SSMS's bare words are familiar but do not say it, and today's text is wrong for Optional."),
            .of("strictTrust", "Strict and Trust", StrictTrust.self, default: .disabled,
                question: "Choose Strict with Trust Server Certificate on. How should the sheet handle that?",
                recommend: .disabled,
                why: "Strict always checks the certificate (the driver refuses to skip it), so the switch cannot apply; dimming it with a note prevents a combination that can only fail. Leaving it on means finding out at Test."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Optional is the default and is described as 'use encryption if available'.",
                  isEchoToday: true, designWidth: width, designHeight: height) { _ in
                MssqlEncryptionExhibit(mode: "Optional - Use encryption if available",
                                       info: "Strict requires TDS 8.0 TLS-before-TDS (Azure SQL). Mandatory requires TLS but uses classic negotiation. Optional uses TLS only if the server requires it (default).",
                                       trustEnabled: true)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls.",
                  designWidth: width, designHeight: height) { values in
                let wording = Wording(rawValue: values["wording"]) ?? .plain
                let isDefaultMandatory = (Default(rawValue: values["default"]) ?? .mandatory) == .mandatory
                let strictTrust = StrictTrust(rawValue: values["strictTrust"]) ?? .disabled
                MssqlEncryptionExhibit(
                    mode: wording == .plain
                        ? (isDefaultMandatory ? "Mandatory – encrypt and check the certificate" : "Optional – encrypt, don't check the certificate")
                        : (isDefaultMandatory ? "Mandatory" : "Optional"),
                    info: wording == .plain
                        ? "Every mode encrypts the password and the session. Mandatory and Strict check that the certificate is trusted and names this server; Strict (TDS 8.0, SQL Server 2022 and later, Azure SQL) starts TLS before anything else."
                        : "Optional, Mandatory, or Strict (TDS 8.0).",
                    trustEnabled: true,
                    strictNote: strictTrust == .disabled
                        ? "Under Strict the certificate is always checked; Trust Server Certificate is off."
                        : nil)
            },
        ],
        questions: [
            .init(id: "legacyTLS", title: "SQL Server 2008 R2 without its TLS 1.2 update",
                  question: "The driver requires TLS 1.2. An unpatched SQL Server 2008 R2 only offers TLS 1.0. What should Echo do?",
                  choices: [
                      .init(id: "require", name: "LT1 · Require TLS 1.2, with an error that names the update to install"),
                      .init(id: "optIn", name: "LT2 · Add an 'Allow TLS 1.0' switch for that connection"),
                  ],
                  recommended: "require",
                  why: "TLS 1.0 is broken and banned by most security policies; the update (SQL Server 2008 R2 SP3 with KB3144114) has existed since 2016. This is verified on the Windows lab VM before shipping; if real servers need it, LT2 can follow as its own round."),
            .init(id: "testError", title: "When the certificate check fails at Test",
                  question: "Test fails because the certificate is not trusted or names another host. What should the result line offer?",
                  choices: [
                      .init(id: "explain", name: "TE1 · Say which check failed and offer 'Trust this certificate' or Host Name In Certificate"),
                      .init(id: "plain", name: "TE2 · The error text only (today)"),
                  ],
                  recommended: "explain",
                  why: "The driver now reports which check failed (untrusted, expired, other host name). Turning that into the one setting that fixes it avoids trial and error; blindly trusting stays a deliberate choice."),
        ],
        exhibitTopic: ("Clearer and safer?", "Compare the rows in both. Which one tells you what you get and starts safe?",
                       "proposal",
                       "It starts with a checked, encrypted connection and says in the menu what each mode checks; today's default and wording describe something the driver no longer does."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "ED1, EW1, ST1.",
                  values: ["default": Default.mandatory.rawValue, "wording": Wording.plain.rawValue,
                           "strictTrust": StrictTrust.disabled.rawValue], isRecommended: true),
        ]
    )
}

/// The SQL Server rows of the Security and timeouts disclosure (CON-4.2).
struct MssqlEncryptionExhibit: View {
    let mode: String
    let info: String
    let trustEnabled: Bool
    var strictNote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            row("Encryption") {
                HStack(spacing: SpacingTokens.xxs) {
                    Text(mode).font(TypographyTokens.formValue)
                    Image(systemName: "chevron.up.chevron.down").font(TypographyTokens.micro)
                }
                .padding(.horizontal, SpacingTokens.xs)
                .padding(.vertical, SpacingTokens.xxxs)
                .background(ColorTokens.Text.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.extraSmall))
            }
            Text(info).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 300, alignment: .leading)
            row("Trust Server Certificate") { Toggle("", isOn: .constant(false)).labelsHidden().toggleStyle(.switch).disabled(!trustEnabled) }
            if let strictNote {
                Text(strictNote).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 300, alignment: .leading)
            }
            row("Read-Only Intent") { Toggle("", isOn: .constant(false)).labelsHidden().toggleStyle(.switch) }
            row("Host Name In Certificate") {
                Text("e.g. prod-sql-01.contoso.com").font(TypographyTokens.formValue).foregroundStyle(ColorTokens.Text.tertiary)
            }
            row("CA Certificate Path") { Text("None").font(TypographyTokens.formValue).foregroundStyle(ColorTokens.Text.tertiary) }
            Spacer(minLength: SpacingTokens.none)
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
    }

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title).font(TypographyTokens.formLabel)
            Spacer(minLength: SpacingTokens.md)
            content()
        }
    }
}
