import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

// MARK: - Security Section

extension ConnectionEditorView {
    var securitySection: some View {
        Section("Security") {
            if selectedDatabaseType == .postgresql {
                Picker("SSL Mode", selection: $tlsMode) {
                    ForEach(TLSMode.allCases, id: \.self) { mode in
                        Text(mode.description).tag(mode)
                    }
                }
                .help("PostgreSQL SSL mode. Controls whether and how TLS is used.")
                .onChange(of: tlsMode) { _, newValue in
                    useTLS = newValue.requiresTLS
                }

                if tlsMode == .verifyCA || tlsMode == .verifyFull {
                    caCertificatePathPicker
                }

                if tlsMode != .disable {
                    clientCertificateSection
                }
            } else {
                Toggle("Use SSL/TLS", isOn: $useTLS)

                if useTLS && selectedDatabaseType == .microsoftSQL {
                    Toggle("Trust Server Certificate", isOn: $trustServerCertificate)
                        .help("Skip server certificate validation. Use for self-signed certificates in development environments.")

                    Picker("Encryption Mode", selection: $mssqlEncryptionMode) {
                        ForEach(MSSQLEncryptionMode.allCases, id: \.self) { mode in
                            Text(mode.description).tag(mode)
                        }
                    }
                    .help("Controls how encryption is negotiated with SQL Server.")

                    Toggle("Read-Only Intent", isOn: $readOnlyIntent)
                        .help("Signal read-only application intent for AlwaysOn Availability Group secondary replica routing.")

                    if !trustServerCertificate {
                        caCertificatePathPicker
                    }
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
            Button("Browse...") {
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
            Button("Browse...") {
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
