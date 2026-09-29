#if DEBUG
import SwiftUI

/// CN2's fields as a native grouped form, used in the Manage Connections detail pane (CN5).
/// Port follows the engine (CR2); missing fields are flagged inline when saving (CR1);
/// Security and timeouts fold into one disclosure with a summary and remember it (CR7).
struct LabRound14ConnectionForm: View {
    @Binding var connection: LabConnection
    let showsErrors: Bool

    @AppStorage("designLab.round14.securityExpanded") private var securityExpanded = false

    var body: some View {
        Form {
            Section {
                Picker("Database", selection: engineBinding) {
                    ForEach(LabEngine.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                if connection.engine == .sqlite {
                    LabeledContent("File") {
                        HStack {
                            TextField("", text: $connection.host, prompt: Text("~/Data/app.sqlite"))
                            Button("Choose") {}
                        }
                    }
                } else {
                    LabeledContent("Server") {
                        HStack(spacing: SpacingTokens.xxs2) {
                            TextField("", text: $connection.host, prompt: Text("db.example.com"))
                            Text(":").foregroundStyle(ColorTokens.Text.tertiary)
                            TextField("", text: $connection.port, prompt: Text(connection.engine.defaultPort))
                                .frame(width: SpacingTokens.xxxl)
                        }
                    }
                    if showsErrors && connection.host.isEmpty { inlineError("Enter the server’s host name or address.") }
                    TextField("Database", text: $connection.database, prompt: Text("Default"))
                }
            }

            if connection.engine != .sqlite {
                Section("Sign In") {
                    Picker("Method", selection: $connection.method) {
                        ForEach(connection.engine.signInMethods, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("User", text: $connection.user, prompt: Text("username"))
                    if showsErrors && connection.user.isEmpty { inlineError("Enter a user name.") }
                    SecureField("Password", text: $connection.password, prompt: Text("Required"))
                    Toggle("Remember in Keychain", isOn: $connection.remembersPassword)
                }

                Section {
                    DisclosureGroup(isExpanded: $securityExpanded) {
                        Picker("Encryption", selection: $connection.encryption) {
                            ForEach(connection.engine.encryptionModes, id: \.self) { Text($0).tag($0) }
                        }
                        Toggle("Trust server certificate", isOn: $connection.trustsCertificate)
                        TextField("Connect timeout", text: $connection.timeout, prompt: Text("30 seconds"))
                    } label: {
                        LabeledContent("Security and timeouts") {
                            Text(securitySummary).foregroundStyle(ColorTokens.Text.secondary)
                        }
                    }
                }
            }

            Section("Saved As") {
                TextField("Name", text: $connection.name, prompt: Text(connection.host.isEmpty ? "My connection" : connection.host))
                Picker("Folder", selection: $connection.folder) {
                    ForEach(LabConnection.folders, id: \.self) { Text($0).tag($0) }
                }
                LabeledContent("Colour") {
                    HStack(spacing: SpacingTokens.xs) {
                        ForEach(Array(LabConnection.colors.enumerated()), id: \.offset) { index, color in
                            Button { connection.colorIndex = index } label: {
                                Circle().fill(color)
                                    .frame(width: SpacingTokens.sm2, height: SpacingTokens.sm2)
                                    .padding(SpacingTokens.xxxs)
                                    .overlay(Circle().strokeBorder(color, lineWidth: connection.colorIndex == index ? SpacingTokens.xxxs / 1.5 : 0))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Colour \(index + 1)")
                            .accessibilityAddTraits(connection.colorIndex == index ? .isSelected : [])
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var securitySummary: String {
        let timeout = connection.timeout.isEmpty ? "30 s" : "\(connection.timeout) s"
        return "\(connection.encryption) · \(timeout)"
    }

    /// Switching engine resets the method and encryption to that engine's first choices.
    private var engineBinding: Binding<LabEngine> {
        Binding {
            connection.engine
        } set: { engine in
            connection.engine = engine
            connection.method = engine.signInMethods.first ?? ""
            connection.encryption = engine.encryptionModes.first ?? ""
            connection.port = ""
        }
    }

    private func inlineError(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Status.error)
    }
}
#endif
