import SwiftUI

/// Round 23 · PostgreSQL: encrypted client key. Companies that sign in with a client certificate
/// often protect its private key with a password. postgres-wire now opens such a key (libpq's
/// `sslpassword`); Echo has nowhere to type it, so an encrypted key fails at Test with "If it is
/// protected by a password, set the key password." Touches CON-4.3 (PostgreSQL rows) and CON-6.2.
@MainActor
enum PgClientKeyPasswordRound {
    enum When: String, CaseIterable {
        case encryptedOnly = "KW1 · Only when the chosen key is encrypted"
        case always = "KW2 · Always, under Client Key"
        case atConnect = "KW3 · Not in the sheet; asked when connecting"
    }
    enum Storage: String, CaseIterable {
        case keychain = "KK1 · Saved in the Keychain, like the password"
        case ask = "KK2 · Asked every time you connect"
        case remember = "KK3 · A 'Remember in Keychain' checkbox"
    }
    enum KeyLabel: String, CaseIterable {
        case password = "KL1 · Key Password"
        case passphrase = "KL2 · Key Passphrase"
    }
    enum Rows: String, CaseIterable {
        case labelled = "KR1 · Label left, file name and Choose… right"
        case paths = "KR2 · Today's path fields"
    }
    enum Sample: String, CaseIterable {
        case encrypted = "Encrypted key, password entered"
        case wrong = "Encrypted key, wrong password"
        case plain = "Key without a password"
    }

    private static let width: CGFloat = 540
    private static let height: CGFloat = 480

    static let spec = RoundSpec(
        controls: [
            .of("when", "When shown", When.self, default: .encryptedOnly,
                question: "Switch the sample between an encrypted key and a plain one. When should the key password row appear?",
                recommend: .encryptedOnly,
                why: "Echo can tell from the key file's first line whether it is encrypted, so the row appears exactly when it is needed, like the CA row appears only for Verify modes (CON-4.3). Always showing it invites a password for keys that have none; asking at connect breaks Test and saved connections."),
            .of("storage", "Kept", Storage.self, default: .keychain,
                question: "Save and reopen the connection in your head. Where should the key password live?",
                recommend: .keychain,
                why: "It protects a file that is already on this Mac, the same as the connection password Echo keeps in the Keychain; asking every time makes every reconnect and tab open a prompt. KK3 adds a control for a choice few people make; a company that forbids storing it can still leave the field empty and get KW3's prompt."),
            .of("label", "Label", KeyLabel.self, default: .password,
                question: "Read the row. Is it clear which password this is?",
                recommend: .password,
                why: "libpq and the driver call it the key password (sslpassword), and 'Key' next to it already says it is not the sign-in password. OpenSSL says pass phrase, but Echo uses password everywhere else."),
            .of("rows", "Certificate rows", Rows.self, default: .labelled,
                question: "Compare the certificate rows with the rest of the sheet. Should they get labels like every other row?",
                recommend: .labelled,
                why: "Today the row's name is the field's placeholder, so it disappears once a path is chosen and a long path is cut off; every other row has its label on the left. Showing the file name keeps the row short; the full path is in the tooltip."),
            .of("sample", "Sample", Sample.self, default: .encrypted),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Paths only. An encrypted key fails at Test.",
                  isEchoToday: true, designWidth: width, designHeight: height) { _ in
                PgConnSheet {
                    PgConnSection {
                        PgConnDisclosure(summary: "TLS verify full · 30 s")
                        PgConnRow(title: "SSL Mode", info: true) { PgConnMenu(text: "Verify Full - SSL required, verify certificate and hostname") }
                        PgConnPathField(label: "CA Certificate Path", path: "/Users/alice/certs/corp-root-ca.pem")
                        PgConnPathField(label: "Client Certificate", path: "/Users/alice/certs/alice.crt")
                        PgConnPathField(label: "Client Key", path: "/Users/alice/certs/alice.key")
                        PgConnRow(title: "Connection Timeout") { PgConnValue(text: "30 seconds", prompt: true) }
                    }
                    PgConnTestBar(result: "Could not read the client key at /Users/alice/certs/alice.key. If it is protected by a password, set the key password.")
                }
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls.",
                  designWidth: width, designHeight: height) { values in
                PgClientKeyProposal(
                    when: When(rawValue: values["when"]) ?? .encryptedOnly,
                    storage: Storage(rawValue: values["storage"]) ?? .keychain,
                    label: KeyLabel(rawValue: values["label"]) ?? .password,
                    rows: Rows(rawValue: values["rows"]) ?? .labelled,
                    sample: Sample(rawValue: values["sample"]) ?? .encrypted)
            },
        ],
        questions: [
            .init(id: "wrongPassword", title: "A wrong key password",
                  question: "Test fails because the key password is wrong. Where should that show?",
                  choices: [
                      .init(id: "inline", name: "KE1 · Under the Key Password row, and in the result line"),
                      .init(id: "line", name: "KE2 · In the result line only"),
                  ],
                  recommended: "inline",
                  why: "The driver tells a wrong password apart from an unreadable file, so Echo can point at the one row to fix, the way the sheet's other field errors show (CON-5)."),
            .init(id: "p12", title: "Certificates from IT as .p12 or .pfx",
                  question: "IT departments usually hand out one .p12/.pfx file with the certificate and key. What should Echo accept?",
                  choices: [
                      .init(id: "pem", name: "PF1 · PEM files only; a .p12 gets a message with the command to convert it"),
                      .init(id: "p12", name: "PF2 · Also .p12/.pfx: one file for both rows, unlocked by the same password",
                            summary: "A small driver change: SwiftNIO SSL reads PKCS#12."),
                      .init(id: "keychain", name: "PF3 · Also a certificate from the Keychain (macOS only, larger change)"),
                  ],
                  recommended: "p12",
                  why: "It is the format people actually receive, and the driver's TLS library already reads it, so the key password row does double duty. The Keychain is the most Mac-like, but the key never leaves it, which needs a different TLS path; worth its own round if asked for."),
        ],
        exhibitTopic: ("Can you sign in with it?", "Set up the encrypted key in the Proposal, then compare it with Echo today.",
                       "proposal",
                       "It asks for the key password only when the key needs one and keeps it like the sign-in password; today an encrypted key cannot be used at all."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "KW1, KK1, KL1, KR1.",
                  values: ["when": When.encryptedOnly.rawValue, "storage": Storage.keychain.rawValue,
                           "label": KeyLabel.password.rawValue, "rows": Rows.labelled.rawValue], isRecommended: true),
            .init(id: "minimal", name: "Smallest change", summary: "KW2, KK1, KL1, KR2: one more path-style row.",
                  values: ["when": When.always.rawValue, "storage": Storage.keychain.rawValue,
                           "label": KeyLabel.password.rawValue, "rows": Rows.paths.rawValue]),
        ]
    )
}

/// Today's certificate row: a text field whose placeholder is the name, and Browse.
struct PgConnPathField: View {
    let label: String
    let path: String

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Text(path.isEmpty ? label : path).font(TypographyTokens.formValue)
                .foregroundStyle(path.isEmpty ? ColorTokens.Text.tertiary : ColorTokens.Text.primary)
                .lineLimit(1).truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Browse") {}.controlSize(.small)
        }
    }
}

struct PgClientKeyProposal: View {
    let when: PgClientKeyPasswordRound.When
    let storage: PgClientKeyPasswordRound.Storage
    let label: PgClientKeyPasswordRound.KeyLabel
    let rows: PgClientKeyPasswordRound.Rows
    let sample: PgClientKeyPasswordRound.Sample

    private var encrypted: Bool { sample != .plain }
    private var rowTitle: String { label == .password ? "Key Password" : "Key Passphrase" }
    private var showsRow: Bool {
        switch when {
        case .encryptedOnly: encrypted
        case .always: true
        case .atConnect: false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            PgConnSheet {
                PgConnSection {
                    PgConnDisclosure(summary: "TLS verify full · client certificate · 30 s")
                    PgConnRow(title: "SSL Mode", info: true) { PgConnMenu(text: "Verify Full - SSL required, verify certificate and hostname") }
                    fileRow("CA Certificate", "corp-root-ca.pem", path: "/Users/alice/certs/corp-root-ca.pem")
                    fileRow("Client Certificate", "alice.crt", path: "/Users/alice/certs/alice.crt")
                    fileRow("Client Key", encrypted ? "alice.key · encrypted" : "alice.key", path: "/Users/alice/certs/alice.key")
                    if showsRow {
                        PgConnRow(title: rowTitle, info: true, highlighted: true) {
                            if storage == .ask {
                                PgConnValue(text: "Asked when connecting", prompt: true)
                            } else {
                                PgConnValue(text: encrypted ? "set" : "Only for encrypted keys", prompt: !encrypted, secure: encrypted)
                            }
                        }
                        if storage == .remember {
                            PgConnRow(title: "Remember in Keychain") { PgConnSwitch(isOn: false) }
                        }
                        if sample == .wrong {
                            PgConnNote(text: "The key password is wrong.", icon: "exclamationmark.circle.fill", color: ColorTokens.Status.error)
                        }
                    }
                    PgConnRow(title: "Connection Timeout") { PgConnValue(text: "30 seconds", prompt: true) }
                }
                testBar
            }
            if when == .atConnect && encrypted {
                PgKeyPasswordPrompt(title: rowTitle)
            }
        }
    }

    @ViewBuilder private var testBar: some View {
        switch sample {
        case .wrong:
            PgConnTestBar(result: "Could not read the client key: the key password is wrong.")
        case .encrypted where when == .atConnect:
            PgConnTestBar(result: "Asking for the key password…", kind: .info)
        default:
            PgConnTestBar(result: "Connected to db1.corp.example.com as alice (client certificate) · 38 ms", kind: .success)
        }
    }

    @ViewBuilder private func fileRow(_ title: String, _ file: String, path: String) -> some View {
        if rows == .labelled {
            PgConnRow(title: title, info: true) {
                HStack(spacing: SpacingTokens.xs) {
                    Image(systemName: "doc").foregroundStyle(ColorTokens.Text.secondary)
                    PgConnValue(text: file).help(path)
                    Button("Choose…") {}.controlSize(.small)
                }
            }
        } else {
            PgConnPathField(label: title, path: path)
        }
    }
}

/// KW3: the password asked for when connecting.
struct PgKeyPasswordPrompt: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Unlock alice.key").font(TypographyTokens.formLabel.weight(.semibold))
            Text("db1.corp.example.com needs your client certificate. Enter the password that protects its key.")
                .font(TypographyTokens.formDescription).foregroundStyle(ColorTokens.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(title).font(TypographyTokens.formLabel)
                Spacer()
                PgConnValue(text: "", prompt: true).frame(width: 160, alignment: .leading)
                    .padding(SpacingTokens.xxs).background(ColorTokens.Text.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.extraSmall))
            }
            HStack { Spacer(); Button("Cancel") {}.controlSize(.small); Button("Connect") {}.controlSize(.small).buttonStyle(.borderedProminent) }
        }
        .padding(SpacingTokens.sm)
        .frame(minWidth: 300)
        .workspaceCard()
    }
}
