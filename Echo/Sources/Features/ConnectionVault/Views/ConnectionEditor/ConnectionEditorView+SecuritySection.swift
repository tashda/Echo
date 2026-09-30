import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

// MARK: - Security Section

extension ConnectionEditorView {
    /// The Security rows, shown inside the Security and timeouts disclosure.
    var securityRows: some View {
        Group {
            if selectedDatabaseType == .postgresql {
                PropertyRow(title: "SSL Mode", info: "PostgreSQL SSL mode. Controls whether and how TLS is used.") {
                    Picker("", selection: $tlsMode) {
                        ForEach(TLSMode.allCases, id: \.self) { mode in
                            Text(mode.description).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                .onChange(of: tlsMode) { _, newValue in
                    useTLS = newValue.requiresTLS
                }

                if tlsMode == .verifyCA || tlsMode == .verifyFull {
                    caCertificatePathPicker
                }

                if tlsMode != .disable {
                    clientCertificateSection
                }
            } else if selectedDatabaseType == .microsoftSQL {
                // SQL Server: encryption is always available — the dropdown alone
                // controls behavior, matching the SSMS connection dialog. There is
                // no "Use SSL/TLS" gate because TDS PRELOGIN handles negotiation:
                // Optional lets the server upgrade us to TLS if it requires it;
                // Mandatory/Strict insists on TLS regardless.
                PropertyRow(title: "Encryption", info: "Every mode encrypts the password and the session. Mandatory and Strict check that the certificate is trusted and names this server; Strict (TDS 8.0, SQL Server 2022 and later, Azure SQL) starts TLS before anything else.") {
                    Picker("", selection: $mssqlEncryptionMode) {
                        ForEach(MSSQLEncryptionMode.allCases, id: \.self) { mode in
                            Text(mode.description).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                PropertyRow(title: "Trust Server Certificate", info: mssqlEncryptionMode == .strict
                    ? "Under Strict the certificate is always checked."
                    : "Skip server certificate validation. Use for self-signed certificates or internal-CA certificates not in the system trust store.") {
                    // Round 22, ST1: Strict always checks, so the switch is off and dimmed.
                    Toggle("", isOn: $trustServerCertificate)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(mssqlEncryptionMode == .strict)
                }
                .onChange(of: mssqlEncryptionMode) { _, mode in
                    if mode == .strict { trustServerCertificate = false }
                }

                if mssqlEncryptionMode != .strict {
                    // Round 22, LT2: for servers without their TLS 1.2 update.
                    PropertyRow(title: "Allow TLS 1.0", info: "For SQL Server 2008 R2 to 2014 without their TLS 1.2 update. TLS 1.0 and 1.1 are outdated and weak; leave this off unless the server cannot be updated.") {
                        Toggle("", isOn: $allowLegacyTLS)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }

                PropertyRow(title: "Read-Only Intent", info: "Signal read-only application intent for AlwaysOn Availability Group secondary replica routing.") {
                    Toggle("", isOn: $readOnlyIntent)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                if !trustServerCertificate || mssqlEncryptionMode == .strict {
                    PropertyRow(title: "Host Name In Certificate", info: "Override the hostname used to validate the server certificate. Set this when connecting via IP, alias, or CNAME that differs from the name on the certificate.") {
                        TextField("", text: $hostNameInCertificate, prompt: Text("e.g. prod-sql-01.contoso.com"))
                            .textFieldStyle(.roundedBorder)
                    }

                    caCertificatePathPicker
                }
            } else {
                PropertyRow(title: "Use SSL/TLS") {
                    Toggle("", isOn: $useTLS)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
        }
    }

    private var clientCertificateSection: some View {
        Group {
            certFilePathPicker(
                label: "Client Certificate",
                path: Binding(
                    get: { sslCertPath ?? "" },
                    set: { sslCertPath = $0.isEmpty ? nil : $0 }
                )
            )
            certFilePathPicker(
                label: "Client Key",
                path: Binding(
                    get: { sslKeyPath ?? "" },
                    set: { sslKeyPath = $0.isEmpty ? nil : $0 }
                )
            )
        }
        .help("PEM-encoded client certificate and private key for mutual TLS (mTLS) authentication.")
    }

    private func certFilePathPicker(label: String, path: Binding<String>) -> some View {
        HStack {
            TextField(label, text: path)
            Button("Browse") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.init(filenameExtension: "pem")!, .init(filenameExtension: "crt")!, .init(filenameExtension: "key")!, .item]
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                if panel.runModal() == .OK, let url = panel.url {
                    path.wrappedValue = url.path
                }
            }
        }
    }

    private var caCertificatePathPicker: some View {
        HStack {
            TextField("CA Certificate Path", text: Binding(
                get: { sslRootCertPath ?? "" },
                set: { sslRootCertPath = $0.isEmpty ? nil : $0 }
            ))
            Button("Browse") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.init(filenameExtension: "pem")!, .init(filenameExtension: "crt")!, .item]
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                if panel.runModal() == .OK, let url = panel.url {
                    sslRootCertPath = url.path
                }
            }
        }
        .help("Path to PEM-encoded root CA certificate for server verification.")
    }
}
