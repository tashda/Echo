import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

/// The PostgreSQL rows Echo Labs round 23 added: several servers with Connect To (failover: FH1,
/// FT1, FW1), Kerberos (KP1, KT1, KS1, KU1), and client certificates with a key password (KW1, KK1,
/// KL1, KR1, KE1, PF2).
extension ConnectionEditorView {

    // MARK: - Servers

    /// Under the Server row: one row per extra server, Add Server, and Connect To once there are two.
    @ViewBuilder
    var additionalServerRows: some View {
        if selectedDatabaseType == .postgresql {
            ForEach(additionalHosts.indices, id: \.self) { index in
                PropertyRow(title: "") {
                    HStack(spacing: SpacingTokens.xxs2) {
                        TextField("", text: additionalHostBinding(index), prompt: Text("standby.example.com"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .additionalHost(index))
                        Text(":").foregroundStyle(ColorTokens.Text.tertiary)
                        TextField("", value: additionalPortBinding(index), format: .number.grouping(.never), prompt: Text(verbatim: "\(port)"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(width: SpacingTokens.xxl)
                        Button {
                            removeAdditionalHost(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(ColorTokens.Text.tertiary)
                        }
                        .buttonStyle(.plain)
                        .help("Remove this server")
                    }
                }
            }
            Button {
                additionalHosts.append(ConnectionHost(host: "", port: nil))
                focusedField = .additionalHost(additionalHosts.count - 1)
            } label: {
                Label("Add Server", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .font(TypographyTokens.formDescription)
            .help("Add a standby or another server of the same cluster. Echo connects to the first one that fits Connect To, and moves to another if it stops answering.")

            if !additionalHosts.isEmpty {
                PropertyRow(title: "Connect To", info: "Which server to use. Echo tries them in order and moves to another that fits when the server stops answering or, for Primary, becomes a standby.") {
                    Picker("", selection: $targetSessionAttributes) {
                        ForEach(connectToChoices, id: \.self) { choice in
                            Text(choice.displayName).tag(choice)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }
        }
    }

    /// The menu's four plain choices, plus a pasted URL's read-write or read-only when set.
    private var connectToChoices: [PostgresConnectTo] {
        PostgresConnectTo.menuCases.contains(targetSessionAttributes)
            ? PostgresConnectTo.menuCases
            : PostgresConnectTo.menuCases + [targetSessionAttributes]
    }

    private func additionalHostBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { additionalHosts.indices.contains(index) ? additionalHosts[index].host : "" },
            set: { if additionalHosts.indices.contains(index) { additionalHosts[index].host = $0 } }
        )
    }

    private func additionalPortBinding(_ index: Int) -> Binding<Int?> {
        Binding(
            get: { additionalHosts.indices.contains(index) ? additionalHosts[index].port : nil },
            set: { if additionalHosts.indices.contains(index) { additionalHosts[index].port = $0 } }
        )
    }

    private func removeAdditionalHost(at index: Int) {
        guard additionalHosts.indices.contains(index) else { return }
        focusedField = nil
        additionalHosts.remove(at: index)
    }

    // MARK: - Kerberos

    /// Under Username: whose ticket signs in and until when, or what to do without one (KT1, NT1).
    @ViewBuilder
    var kerberosTicketRow: some View {
        Group {
            switch kerberosTicket {
            case .valid(let principal, let expiresAt)?:
                ticketNote(expiresAt.map { "Signed in as \(principal) · ticket valid until \($0.formatted(date: .omitted, time: .shortened))" }
                           ?? "Signed in as \(principal)",
                           icon: "checkmark.seal.fill", color: ColorTokens.Status.success, offersViewer: false)
            case .expired(let principal)?:
                ticketNote(principal.map { "Your ticket for \($0) has expired. Renew it in Ticket Viewer." } ?? "Your Kerberos ticket has expired. Renew it in Ticket Viewer.",
                           icon: "clock.badge.exclamationmark", color: ColorTokens.Status.warning, offersViewer: true)
            case .none?:
                ticketNote("No Kerberos ticket. Get one in Ticket Viewer, or with kinit.",
                           icon: "exclamationmark.triangle.fill", color: ColorTokens.Status.warning, offersViewer: true)
            case .unavailable?, nil:
                EmptyView()
            }
        }
        .listRowSeparator(.hidden)
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Back from Ticket Viewer or a terminal with kinit.
            if authenticationMethod == .kerberos { refreshKerberosTicket() }
        }
        #endif
    }

    private func ticketNote(_ text: String, icon: String, color: Color, offersViewer: Bool) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Label {
                Text(text).foregroundStyle(ColorTokens.Text.secondary)
            } icon: {
                Image(systemName: icon).foregroundStyle(color)
            }
            .font(TypographyTokens.formDescription)
            Spacer(minLength: SpacingTokens.xs)
            if offersViewer {
                Button("Open Ticket Viewer") { KerberosTicketStatus.openTicketViewer() }
                    .controlSize(.small)
            }
        }
    }

    func refreshKerberosTicket() {
        kerberosTicket = KerberosTicketStatus.current()
    }

    /// Kerberos chosen: read the ticket and, with no user name yet, use the ticket's (KU1).
    func kerberosMethodChosen() {
        refreshKerberosTicket()
        if username.trimmingCharacters(in: .whitespaces).isEmpty, let name = kerberosTicket?.userName {
            username = name
        }
    }

    /// In Security and timeouts, only for Kerberos (KS1).
    @ViewBuilder
    var kerberosServiceRow: some View {
        if selectedDatabaseType == .postgresql && authenticationMethod == .kerberos {
            PropertyRow(title: "Kerberos Service", info: "The service in the server's Kerberos name (service/host). It is postgres unless your DBA set another.") {
                TextField("", text: $kerberosServiceName, prompt: Text("postgres"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - Certificates

    /// CA certificate (Verify modes), client certificate and key, and the key password when the
    /// key needs one; a .p12/.pfx file fills both certificate rows.
    @ViewBuilder
    var postgresCertificateRows: some View {
        if tlsMode == .verifyCA || tlsMode == .verifyFull {
            certificateFileRow("CA Certificate", info: "The certificate of the authority that signed the server's certificate (PEM).",
                               path: $sslRootCertPath, extensions: ["pem", "crt", "cer"])
        }
        if tlsMode != .disable {
            certificateFileRow("Client Certificate", info: "Your certificate for signing in with a certificate: a PEM file with a separate key, or a .p12/.pfx file that holds both.",
                               path: $sslCertPath, extensions: ["pem", "crt", "cer", "p12", "pfx"])
            if !ClientCertificateFiles.isBundle(sslCertPath) {
                certificateFileRow("Client Key", info: "The private key for the client certificate (PEM or DER).",
                                   path: $sslKeyPath, extensions: ["key", "pem", "der"])
            }
            if keyNeedsPassword {
                keyPasswordRow
            }
        }
    }

    private var keyPasswordRow: some View {
        Group {
            PropertyRow(title: "Key Password", info: "The password that protects the key\(ClientCertificateFiles.isBundle(sslCertPath) ? " file" : ""). Echo keeps it in your Keychain, like the connection's password.") {
                SecureField("", text: $keyPassword, prompt: Text(hasSavedKeyPassword && !keyPasswordDirty ? "••••••••" : "password"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .keyPassword)
                    .onChange(of: keyPassword) { _, newValue in
                        if !newValue.isEmpty { keyPasswordDirty = true }
                    }
            }
            if let issue = testResult?.keyPasswordIssue {
                Label(issue, systemImage: "exclamationmark.circle.fill")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Status.error)
                    .listRowSeparator(.hidden)
            }
        }
    }

    private func certificateFileRow(_ title: String, info: String, path: Binding<String?>, extensions: [String]) -> some View {
        PropertyRow(title: title, info: info) {
            HStack(spacing: SpacingTokens.xs) {
                if let value = path.wrappedValue, !value.isEmpty {
                    Label(URL(fileURLWithPath: value).lastPathComponent, systemImage: "doc")
                        .font(TypographyTokens.formValue)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(value)
                    Button {
                        path.wrappedValue = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove")
                } else {
                    Text("None").font(TypographyTokens.formValue).foregroundStyle(ColorTokens.Text.tertiary)
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

    /// Re-reads whether the key needs a password after a file changes.
    func refreshKeyNeedsPassword() {
        if ClientCertificateFiles.isBundle(sslCertPath) { sslKeyPath = nil }
        keyNeedsPassword = selectedDatabaseType == .postgresql
            && ClientCertificateFiles.keyNeedsPassword(certificatePath: sslCertPath, keyPath: sslKeyPath)
    }

    // MARK: - Saving and testing

    /// Copies the round 23 settings into a connection being saved or tested.
    func applyPostgresOptions(to connection: inout SavedConnection) {
        guard selectedDatabaseType == .postgresql else { return }
        connection.additionalHosts = additionalHosts
            .map { ConnectionHost(host: $0.host.trimmingCharacters(in: .whitespacesAndNewlines), port: $0.port) }
            .filter { !$0.host.isEmpty }
        connection.targetSessionAttributes = connection.additionalHosts.isEmpty ? .any : targetSessionAttributes
        connection.loadBalanceHosts = loadBalanceHosts && !connection.additionalHosts.isEmpty
        let service = kerberosServiceName.trimmingCharacters(in: .whitespacesAndNewlines)
        connection.kerberosServiceName = service.isEmpty || service == "postgres" ? nil : service
        if ClientCertificateFiles.isBundle(connection.sslCertPath) { connection.sslKeyPath = nil }
    }

    /// Saves a changed key password to the Keychain (KK1); removes it when no key needs one.
    func persistKeyPassword(for connectionID: UUID) {
        guard selectedDatabaseType == .postgresql else { return }
        if !keyNeedsPassword || sslCertPath == nil {
            ConnectionKeyPasswordStore.setPassword(nil, for: connectionID)
        } else if keyPasswordDirty {
            ConnectionKeyPasswordStore.setPassword(keyPassword, for: connectionID)
        }
    }

    /// The key password a test uses: the one typed, else the saved one.
    var keyPasswordForTest: String? {
        keyNeedsPassword && keyPasswordDirty ? keyPassword : nil
    }

    /// The disclosure summary's PostgreSQL part: "2 servers · Primary · TLS prefer · Kerberos · 30 s".
    func postgresSummary(timeout: String) -> String {
        var parts: [String] = []
        let servers = additionalHosts.filter { !$0.host.trimmingCharacters(in: .whitespaces).isEmpty }.count
        if servers > 0 {
            parts.append("\(servers + 1) servers")
            parts.append(targetSessionAttributes.shortName)
        }
        parts.append("TLS \(tlsMode.shortName.lowercased())")
        if authenticationMethod == .kerberos { parts.append("Kerberos") }
        if tlsMode != .disable, sslCertPath != nil { parts.append("client certificate") }
        parts.append(timeout)
        return parts.joined(separator: " · ")
    }
}
