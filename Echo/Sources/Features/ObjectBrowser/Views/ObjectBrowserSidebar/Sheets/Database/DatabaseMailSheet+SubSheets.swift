import SwiftUI
import SQLServerKit

// MARK: - Add Profile Sheet

struct AddProfileSheet: View {
    let onSave: (String, String?) async -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var description = ""

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("New Profile") {
                    TextField("Name", text: $name, prompt: Text("e.g. Server Alerts"))
                    TextField("Description", text: $description, prompt: Text("Optional description"))
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()
            MailSheetFooter(
                cancelAction: onCancel,
                saveLabel: "Create",
                isValid: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                await onSave(name.trimmingCharacters(in: .whitespacesAndNewlines),
                             description.isEmpty ? nil : description)
            }
        }
        .frame(minWidth: 400, minHeight: 200)
    }
}

// MARK: - Edit Profile Sheet

struct EditProfileSheet: View {
    let profile: SQLServerMailProfile
    let onSave: (String, String?) async -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var description: String

    init(
        profile: SQLServerMailProfile,
        onSave: @escaping (String, String?) async -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.profile = profile
        self.onSave = onSave
        self.onCancel = onCancel
        self._name = State(initialValue: profile.name)
        self._description = State(initialValue: profile.description ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Edit Profile") {
                    TextField("Name", text: $name, prompt: Text("e.g. Server Alerts"))
                    TextField("Description", text: $description, prompt: Text("Optional description"))
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()
            MailSheetFooter(
                cancelAction: onCancel,
                saveLabel: "Save",
                isValid: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                await onSave(name.trimmingCharacters(in: .whitespacesAndNewlines),
                             description.isEmpty ? nil : description)
            }
        }
        .frame(minWidth: 400, minHeight: 200)
    }
}

// MARK: - Add Account Sheet

struct AddAccountSheet: View {
    let onSave: (SQLServerMailAccountConfig) async -> Void
    let onCancel: () -> Void

    @State private var accountName = ""
    @State private var emailAddress = ""
    @State private var displayName = ""
    @State private var replyTo = ""
    @State private var description = ""
    @State private var serverName = ""
    @State private var port = "25"
    @State private var enableSSL = false
    @State private var authMode = 0 // 0=anonymous, 1=basic, 2=windows
    @State private var username = ""
    @State private var password = ""

    private var isValid: Bool {
        !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !serverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            accountForm(title: "New Account")

            Divider()
            MailSheetFooter(cancelAction: onCancel, saveLabel: "Create", isValid: isValid) {
                await onSave(buildConfig())
            }
        }
        .frame(minWidth: 480, minHeight: 420)
    }
}

// MARK: - Edit Account Sheet

struct EditAccountSheet: View {
    let account: SQLServerMailAccount
    let onSave: (SQLServerMailAccountConfig) async -> Void
    let onCancel: () -> Void

    @State private var accountName: String
    @State private var emailAddress: String
    @State private var displayName: String
    @State private var replyTo: String
    @State private var description: String
    @State private var serverName: String
    @State private var port: String
    @State private var enableSSL: Bool
    @State private var authMode: Int
    @State private var username: String
    @State private var password: String

    init(
        account: SQLServerMailAccount,
        onSave: @escaping (SQLServerMailAccountConfig) async -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.account = account
        self.onSave = onSave
        self.onCancel = onCancel
        self._accountName = State(initialValue: account.name)
        self._emailAddress = State(initialValue: account.emailAddress ?? "")
        self._displayName = State(initialValue: account.displayName ?? "")
        self._replyTo = State(initialValue: account.replyToAddress ?? "")
        self._description = State(initialValue: account.description ?? "")
        self._serverName = State(initialValue: account.serverName ?? "")
        self._port = State(initialValue: account.serverPort.map { String($0) } ?? "25")
        self._enableSSL = State(initialValue: account.enableSSL)
        self._authMode = State(initialValue: account.useDefaultCredentials ? 2 : 0)
        self._username = State(initialValue: "")
        self._password = State(initialValue: "")
    }

    private var isValid: Bool {
        !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !serverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            accountForm(title: "Edit Account")

            Divider()
            MailSheetFooter(cancelAction: onCancel, saveLabel: "Save", isValid: isValid) {
                await onSave(buildConfig())
            }
        }
        .frame(minWidth: 480, minHeight: 420)
    }
}

// MARK: - Send Test Email Sheet

struct SendTestSheet: View {
    let profiles: [SQLServerMailProfile]
    let onSend: (String, String, String?, String?) async -> Void
    let onCancel: () -> Void

    @State private var selectedProfile = ""
    @State private var recipients = ""
    @State private var subject = "Database Mail Test"
    @State private var messageBody = "This is a test email from Echo."

    private var isValid: Bool {
        !selectedProfile.isEmpty
        && !recipients.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Send Test Email") {
                    Picker("Profile", selection: $selectedProfile) {
                        Text("Select a profile").tag("")
                        ForEach(profiles) { profile in
                            Text(profile.name).tag(profile.name)
                        }
                    }
                    TextField("Recipients", text: $recipients, prompt: Text("e.g. admin@example.com"))
                    TextField("Subject", text: $subject, prompt: Text("Test email subject"))
                    TextField("Body", text: $messageBody, prompt: Text("Test email body"), axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()
            MailSheetFooter(cancelAction: onCancel, saveLabel: "Send", isValid: isValid) {
                await onSend(
                    selectedProfile,
                    recipients.trimmingCharacters(in: .whitespacesAndNewlines),
                    subject.isEmpty ? nil : subject,
                    messageBody.isEmpty ? nil : messageBody
                )
            }
        }
        .frame(minWidth: 460, minHeight: 320)
        .onAppear {
            if selectedProfile.isEmpty, let first = profiles.first {
                selectedProfile = first.name
            }
        }
    }
}

// MARK: - Grant Access Sheet

struct GrantAccessSheet: View {
    let profiles: [SQLServerMailProfile]
    let onGrant: (Int, String, Bool) async -> Void
    let onCancel: () -> Void

    @State private var selectedProfileID = 0
    @State private var principalName = "public"
    @State private var isDefault = false

    private var isValid: Bool {
        selectedProfileID > 0
        && !principalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Grant Profile Access") {
                    Picker("Profile", selection: $selectedProfileID) {
                        Text("Select a profile").tag(0)
                        ForEach(profiles) { profile in
                            Text(profile.name).tag(profile.profileID)
                        }
                    }
                    TextField("Principal", text: $principalName, prompt: Text("e.g. public"))
                    Toggle("Default profile", isOn: $isDefault)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()
            MailSheetFooter(cancelAction: onCancel, saveLabel: "Grant", isValid: isValid) {
                await onGrant(
                    selectedProfileID,
                    principalName.trimmingCharacters(in: .whitespacesAndNewlines),
                    isDefault
                )
            }
        }
        .frame(minWidth: 400, minHeight: 240)
        .onAppear {
            if selectedProfileID == 0, let first = profiles.first {
                selectedProfileID = first.profileID
            }
        }
    }
}

// MARK: - Shared Helpers

/// Reusable footer for Database Mail sub-sheets.
struct MailSheetFooter: View {
    let cancelAction: () -> Void
    let saveLabel: String
    let isValid: Bool
    let saveAction: () async -> Void

    var body: some View {
        HStack {
            Spacer()
            Button("Cancel", role: .cancel, action: cancelAction)
                .keyboardShortcut(.cancelAction)
            Button(saveLabel) {
                Task { await saveAction() }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!isValid)
        }
        .padding(SpacingTokens.md)
    }
}

extension AddAccountSheet {
    func accountForm(title: String) -> some View {
        Form {
            Section(title) {
                TextField("Account Name", text: $accountName, prompt: Text("e.g. Gmail SMTP"))
                TextField("Email Address", text: $emailAddress, prompt: Text("e.g. alerts@company.com"))
                TextField("Display Name", text: $displayName, prompt: Text("e.g. Server Alerts"))
                TextField("Reply-To", text: $replyTo, prompt: Text("e.g. noreply@company.com"))
                TextField("Description", text: $description, prompt: Text("Optional description"))
            }
            Section("SMTP Server") {
                TextField("Server", text: $serverName, prompt: Text("e.g. smtp.gmail.com"))
                TextField("Port", text: $port, prompt: Text("25"))
                Toggle("Use SSL", isOn: $enableSSL)
            }
            Section("Authentication") {
                Picker("Method", selection: $authMode) {
                    Text("Anonymous").tag(0)
                    Text("Basic Authentication").tag(1)
                    Text("Windows Authentication").tag(2)
                }
                if authMode == 1 {
                    TextField("Username", text: $username, prompt: Text("SMTP username"))
                    SecureField("Password", text: $password, prompt: Text("SMTP password"))
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    func buildConfig() -> SQLServerMailAccountConfig {
        SQLServerMailAccountConfig(
            accountName: accountName.trimmingCharacters(in: .whitespacesAndNewlines),
            emailAddress: emailAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            displayName: displayName.isEmpty ? nil : displayName,
            replyToAddress: replyTo.isEmpty ? nil : replyTo,
            description: description.isEmpty ? nil : description,
            serverName: serverName.trimmingCharacters(in: .whitespacesAndNewlines),
            port: Int(port) ?? 25,
            username: authMode == 1 ? username : nil,
            password: authMode == 1 ? password : nil,
            useDefaultCredentials: authMode == 2,
            enableSSL: enableSSL
        )
    }
}

extension EditAccountSheet {
    func accountForm(title: String) -> some View {
        Form {
            Section(title) {
                TextField("Account Name", text: $accountName, prompt: Text("e.g. Gmail SMTP"))
                TextField("Email Address", text: $emailAddress, prompt: Text("e.g. alerts@company.com"))
                TextField("Display Name", text: $displayName, prompt: Text("e.g. Server Alerts"))
                TextField("Reply-To", text: $replyTo, prompt: Text("e.g. noreply@company.com"))
                TextField("Description", text: $description, prompt: Text("Optional description"))
            }
            Section("SMTP Server") {
                TextField("Server", text: $serverName, prompt: Text("e.g. smtp.gmail.com"))
                TextField("Port", text: $port, prompt: Text("25"))
                Toggle("Use SSL", isOn: $enableSSL)
            }
            Section("Authentication") {
                Picker("Method", selection: $authMode) {
                    Text("Anonymous").tag(0)
                    Text("Basic Authentication").tag(1)
                    Text("Windows Authentication").tag(2)
                }
                if authMode == 1 {
                    TextField("Username", text: $username, prompt: Text("SMTP username"))
                    SecureField("Password", text: $password, prompt: Text("SMTP password"))
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    func buildConfig() -> SQLServerMailAccountConfig {
        SQLServerMailAccountConfig(
            accountName: accountName.trimmingCharacters(in: .whitespacesAndNewlines),
            emailAddress: emailAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            displayName: displayName.isEmpty ? nil : displayName,
            replyToAddress: replyTo.isEmpty ? nil : replyTo,
            description: description.isEmpty ? nil : description,
            serverName: serverName.trimmingCharacters(in: .whitespacesAndNewlines),
            port: Int(port) ?? 25,
            username: authMode == 1 ? username : nil,
            password: authMode == 1 ? password : nil,
            useDefaultCredentials: authMode == 2,
            enableSSL: enableSSL
        )
    }
}
