import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

// MARK: - Security and Behaviour (round MC, SL1)

/// What was "Security & limits" is two short sections: Security, then Behaviour. Each is one
/// disclosure whose label is a single line (the title, and a summary of the values on the
/// trailing side), with one line of explanation under it instead of ⓘ buttons. Pickers offer short
/// choices; what is rarely changed sits under More. SQLite has no Security section.
extension ConnectionEditorView {

    // MARK: Security

    @ViewBuilder
    var securitySection: some View {
        if selectedDatabaseType != .sqlite {
            Section {
                DisclosureGroup(isExpanded: $securityExpanded) {
                    securityRows
                } label: {
                    disclosureLabel("Security", summary: securitySummary)
                }
            } footer: {
                if securityExpanded {
                    sectionFooter(securityFooter)
                }
            }
        }
    }

    @ViewBuilder
    private var securityRows: some View {
        switch selectedDatabaseType {
        case .microsoftSQL: mssqlSecurityRows
        case .postgresql: postgresSecurityRows
        case .mysql: mysqlSecurityRows
        case .sqlite: EmptyView()
        }
    }

    /// The closed disclosure's line: "Mandatory · verified", "TLS: Prefer", "TLS on".
    private var securitySummary: String {
        switch selectedDatabaseType {
        case .microsoftSQL:
            return "\(mssqlEncryptionMode.shortName) · \(mssqlVerifiesCertificate ? "verified" : "not verified")"
        case .postgresql:
            return "TLS: \(tlsMode.shortName)"
        case .mysql:
            return useTLS ? "TLS on" : "TLS off"
        case .sqlite:
            return ""
        }
    }

    private var securityFooter: String {
        switch selectedDatabaseType {
        case .microsoftSQL: "Strict uses TDS 8 and always verifies the certificate."
        case .postgresql: "Verify CA and Verify Full check the server's certificate. A client certificate signs you in with it."
        case .mysql: "With a CA certificate, Echo checks the server's certificate against it."
        case .sqlite: ""
        }
    }

    // MARK: SQL Server

    /// Strict always checks the certificate; the other modes check it unless it is trusted as is.
    private var mssqlVerifiesCertificate: Bool {
        mssqlEncryptionMode == .strict || !trustServerCertificate
    }

    @ViewBuilder
    private var mssqlSecurityRows: some View {
        Picker("Encryption", selection: $mssqlEncryptionMode) {
            ForEach(MSSQLEncryptionMode.allCases, id: \.self) { mode in
                Text(mode.shortName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: mssqlEncryptionMode) { _, mode in
            // Round 22, ST1: Strict always checks.
            if mode == .strict { trustServerCertificate = false }
        }

        Toggle("Verify certificate", isOn: Binding(
            get: { mssqlVerifiesCertificate },
            set: { trustServerCertificate = !$0 }
        ))
        .toggleStyle(.switch)
        .disabled(mssqlEncryptionMode == .strict)

        DisclosureGroup("More") {
            if mssqlVerifiesCertificate {
                InsetRow("Host name in certificate", labelWidth: nil) {
                    TextField("", text: $hostNameInCertificate, prompt: Text("Same as the server"))
                }
                certificateFileRow("CA certificate", path: $sslRootCertPath, extensions: ["pem", "crt", "cer"])
            }
            if mssqlEncryptionMode != .strict {
                // Round 22, LT2: for servers without their TLS 1.2 update.
                Toggle("Allow TLS 1.0", isOn: $allowLegacyTLS)
                    .toggleStyle(.switch)
            }
        }
    }

    // MARK: PostgreSQL

    @ViewBuilder
    private var postgresSecurityRows: some View {
        Picker("TLS", selection: $tlsMode) {
            ForEach(TLSMode.allCases, id: \.self) { mode in
                Text(mode.shortName).tag(mode)
            }
        }
        .pickerStyle(.menu)
        .onChange(of: tlsMode) { _, newValue in
            useTLS = newValue.requiresTLS
        }

        // Round 23: the certificate rows and the key password.
        postgresCertificateRows
    }

    // MARK: MySQL

    @ViewBuilder
    private var mysqlSecurityRows: some View {
        Toggle("Use TLS", isOn: $useTLS)
            .toggleStyle(.switch)
        if useTLS {
            certificateFileRow("CA certificate", path: mysqlCACertificate, extensions: ["pem", "crt", "cer"])
        }
    }

    /// MySQL checks the server against a CA certificate only in a verify mode, so choosing one
    /// turns verification on and clearing it turns it off again.
    private var mysqlCACertificate: Binding<String?> {
        Binding(
            get: { sslRootCertPath },
            set: { newValue in
                sslRootCertPath = newValue
                if newValue != nil {
                    if tlsMode != .verifyCA && tlsMode != .verifyFull { tlsMode = .verifyCA }
                } else if tlsMode == .verifyCA || tlsMode == .verifyFull {
                    tlsMode = .prefer
                }
            }
        )
    }

    // MARK: - Behaviour

    var behaviourSection: some View {
        Section {
            DisclosureGroup(isExpanded: $behaviourExpanded) {
                behaviourRows
            } label: {
                disclosureLabel("Behaviour", summary: behaviourSummary)
            }
        } footer: {
            if behaviourExpanded {
                sectionFooter(behaviourFooter)
            }
        }
    }

    @ViewBuilder
    private var behaviourRows: some View {
        if selectedDatabaseType == .sqlite {
            queryHistoryToggle
            queryTimeLimitRow
            unguardedWritesRow
        } else {
            connectTimeoutRow
            if selectedDatabaseType == .microsoftSQL {
                Toggle("Read-only", isOn: $readOnlyIntent)
                    .toggleStyle(.switch)
            }
            queryHistoryToggle
            DisclosureGroup("More") {
                queryTimeLimitRow
                unguardedWritesRow
            }
        }
    }

    /// The closed disclosure's line: "30 s · history on", or for SQLite "History on".
    private var behaviourSummary: String {
        let history = keepsQueryHistory ? "on" : "off"
        if selectedDatabaseType == .sqlite { return "History \(history)" }
        return "\(Int(connectionTimeout)) s · history \(history)"
    }

    private var behaviourFooter: String {
        selectedDatabaseType == .microsoftSQL
            ? "Read-only asks an availability group for a readable secondary."
            : "An empty time limit uses the one in Settings; 0 means none."
    }

    private var connectTimeoutRow: some View {
        LabeledContent("Connect timeout") {
            HStack(spacing: SpacingTokens.xxs) {
                TextField("", value: $connectionTimeout, format: .number.grouping(.never), prompt: Text("30"))
                    .labelsHidden()
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .frame(width: BehaviourRowMetrics.valueWidth)
                Text("s")
                    .foregroundStyle(ColorTokens.Text.secondary)
                Stepper("Connect timeout", value: $connectionTimeout, in: 1...600, step: 5)
                    .labelsHidden()
            }
        }
    }

    private var queryHistoryToggle: some View {
        Toggle("Keep query history", isOn: $keepsQueryHistory)
            .toggleStyle(.switch)
    }

    /// Round 21, TW2: empty uses Settings › Databases › Query time limit; 0 means no limit.
    private var queryTimeLimitRow: some View {
        LabeledContent("Query time limit") {
            HStack(spacing: SpacingTokens.xxs) {
                TextField("", value: $queryTimeLimit, format: .number.grouping(.never), prompt: Text("Default"))
                    .labelsHidden()
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .frame(width: BehaviourRowMetrics.valueWidth)
                if queryTimeLimit != nil {
                    Text("s")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
    }

    private var unguardedWritesRow: some View {
        Picker("Confirm unguarded writes", selection: $confirmUnguardedWrites) {
            Text("Default").tag(Bool?.none)
            Text("Always").tag(Bool?.some(true))
            Text("Never").tag(Bool?.some(false))
        }
        .pickerStyle(.menu)
    }

    // MARK: - Shared

    /// A disclosure label on one line: the title, then the summary on the trailing side.
    private func disclosureLabel(_ title: String, summary: String) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Text(title)
                .foregroundStyle(ColorTokens.Text.primary)
                .layoutPriority(1)
            Spacer(minLength: SpacingTokens.xs)
            Text(summary)
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func sectionFooter(_ text: String) -> some View {
        Text(text)
            .font(TypographyTokens.formDescription)
            .foregroundStyle(ColorTokens.Text.secondary)
    }

    /// A file row: the file's name (or None), Clear when set, and Choose….
    func certificateFileRow(_ title: String, path: Binding<String?>, extensions: [String]) -> some View {
        LabeledContent(title) {
            HStack(spacing: SpacingTokens.xs) {
                if let value = path.wrappedValue, !value.isEmpty {
                    Label(URL(fileURLWithPath: value).lastPathComponent, systemImage: "doc")
                        .font(TypographyTokens.formValue)
                        .foregroundStyle(ColorTokens.Text.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(value)
                    Button("Clear") { path.wrappedValue = nil }
                        .controlSize(.small)
                } else {
                    Text("None")
                        .font(TypographyTokens.formValue)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
                Button("Choose…") { chooseCertificateFile(into: path, extensions: extensions) }
                    .controlSize(.small)
            }
        }
    }

    private func chooseCertificateFile(into path: Binding<String?>, extensions: [String]) {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = extensions.compactMap { UTType(filenameExtension: $0) } + [.item]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            path.wrappedValue = url.path
        }
        #endif
    }
}

enum BehaviourRowMetrics {
    /// Wide enough for "Default" or a four-digit number of seconds.
    static let valueWidth: CGFloat = 56
}
