import SwiftUI
import SQLServerKit

/// Sheet for creating or viewing a SQL Server Agent proxy account.
/// Allows managing credential, subsystem grants, and login access.
struct AgentProxyEditorSheet: View {
    @State var proxyName: String
    @State var credentialName: String
    @State var enabled: Bool
    @State private var subsystems: [String] = []
    @State private var loginGrants: [String] = []
    @State private var newLogin: String = ""
    @State private var newSubsystem: String = "CmdExec"
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var isLoading = false

    let isEditing: Bool
    let availableLogins: [String]
    let onSave: (String, String, Bool) async -> String?
    let onGrantLogin: (String, String) async -> String?
    let onRevokeLogin: (String, String) async -> String?
    let onGrantSubsystem: (String, String) async -> String?
    let onRevokeSubsystem: (String, String) async -> String?
    let loadSubsystems: (String) async -> [String]
    let loadLogins: (String) async -> [String]
    let onCancel: () -> Void

    private static let allSubsystems = [
        "CmdExec", "PowerShell", "SSIS", "ANALYSISCOMMAND", "ANALYSISQUERY", "ActiveScripting"
    ]

    init(
        proxyName: String = "",
        credentialName: String = "",
        enabled: Bool = true,
        isEditing: Bool = false,
        availableLogins: [String] = [],
        onSave: @escaping (String, String, Bool) async -> String?,
        onGrantLogin: @escaping (String, String) async -> String? = { _, _ in nil },
        onRevokeLogin: @escaping (String, String) async -> String? = { _, _ in nil },
        onGrantSubsystem: @escaping (String, String) async -> String? = { _, _ in nil },
        onRevokeSubsystem: @escaping (String, String) async -> String? = { _, _ in nil },
        loadSubsystems: @escaping (String) async -> [String] = { _ in [] },
        loadLogins: @escaping (String) async -> [String] = { _ in [] },
        onCancel: @escaping () -> Void
    ) {
        self._proxyName = State(initialValue: proxyName)
        self._credentialName = State(initialValue: credentialName)
        self._enabled = State(initialValue: enabled)
        self.isEditing = isEditing
        self.availableLogins = availableLogins
        self.onSave = onSave
        self.onGrantLogin = onGrantLogin
        self.onRevokeLogin = onRevokeLogin
        self.onGrantSubsystem = onGrantSubsystem
        self.onRevokeSubsystem = onRevokeSubsystem
        self.loadSubsystems = loadSubsystems
        self.loadLogins = loadLogins
        self.onCancel = onCancel
    }

    private var isValid: Bool {
        !proxyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !credentialName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isSaving
    }

    var body: some View {
        SheetLayout(
            title: isEditing ? "Proxy Details" : "New Proxy",
            primaryAction: isEditing ? "Done" : "Create",
            canSubmit: isValid,
            isSubmitting: isSaving,
            errorMessage: errorMessage,
            onSubmit: { await performSave() },
            onCancel: { onCancel() }
        ) {
            Form {
                generalSection
                if isEditing {
                    subsystemsSection
                    loginsSection
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 480, idealWidth: 520, minHeight: isEditing ? 480 : 300)
        .task {
            if isEditing {
                isLoading = true
                subsystems = await loadSubsystems(proxyName)
                loginGrants = await loadLogins(proxyName)
                isLoading = false
            }
        }
    }

    // MARK: - Sections

    private var generalSection: some View {
        Section("General") {
            if isEditing {
                LabeledContent("Name") {
                    Text(proxyName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            } else {
                TextField("Name", text: $proxyName, prompt: Text("e.g. SSIS_Proxy"))
            }
            TextField("Credential", text: $credentialName, prompt: Text("e.g. SSIS_Credential"))
            Toggle("Enabled", isOn: $enabled)
                .toggleStyle(.switch)
        }
    }

    private var subsystemsSection: some View {
        Section("Subsystem Grants") {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if subsystems.isEmpty {
                Text("No subsystem grants")
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .font(TypographyTokens.detail)
            } else {
                ForEach(subsystems, id: \.self) { sub in
                    HStack {
                        Text(sub)
                            .font(TypographyTokens.standard)
                        Spacer()
                        Button(role: .destructive) {
                            Task { await revokeSubsystem(sub) }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(ColorTokens.Status.error)
                    }
                }
            }

            HStack {
                Picker("Subsystem", selection: $newSubsystem) {
                    ForEach(Self.allSubsystems.filter { !subsystems.contains($0) }, id: \.self) { sub in
                        Text(sub).tag(sub)
                    }
                }
                .labelsHidden()

                Button {
                    Task { await grantSubsystem(newSubsystem) }
                } label: {
                    Label("Grant", systemImage: "plus.circle")
                }
                .controlSize(.small)
                .disabled(subsystems.contains(newSubsystem))
            }
        }
    }

    private var loginsSection: some View {
        Section("Login Access") {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if loginGrants.isEmpty {
                Text("No login grants")
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .font(TypographyTokens.detail)
            } else {
                ForEach(loginGrants, id: \.self) { login in
                    HStack {
                        Text(login)
                            .font(TypographyTokens.standard)
                        Spacer()
                        Button(role: .destructive) {
                            Task { await revokeLogin(login) }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(ColorTokens.Status.error)
                    }
                }
            }

            HStack {
                if availableLogins.isEmpty {
                    TextField("Login", text: $newLogin, prompt: Text("e.g. domain\\user"))
                } else {
                    Picker("Login", selection: $newLogin) {
                        Text("Select login").tag("")
                        ForEach(availableLogins.filter { !loginGrants.contains($0) }, id: \.self) { login in
                            Text(login).tag(login)
                        }
                    }
                    .labelsHidden()
                }

                Button {
                    Task { await grantLogin(newLogin) }
                } label: {
                    Label("Grant", systemImage: "plus.circle")
                }
                .controlSize(.small)
                .disabled(newLogin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // MARK: - Actions

    private func performSave() async {
        isSaving = true
        let error = await onSave(
            proxyName.trimmingCharacters(in: .whitespacesAndNewlines),
            credentialName.trimmingCharacters(in: .whitespacesAndNewlines),
            enabled
        )
        isSaving = false
        errorMessage = error
    }

    private func grantSubsystem(_ subsystem: String) async {
        let error = await onGrantSubsystem(proxyName, subsystem)
        if let error { errorMessage = error; return }
        subsystems.append(subsystem)
        subsystems.sort()
    }

    private func revokeSubsystem(_ subsystem: String) async {
        let error = await onRevokeSubsystem(proxyName, subsystem)
        if let error { errorMessage = error; return }
        subsystems.removeAll { $0 == subsystem }
    }

    private func grantLogin(_ login: String) async {
        let trimmed = login.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let error = await onGrantLogin(proxyName, trimmed)
        if let error { errorMessage = error; return }
        loginGrants.append(trimmed)
        loginGrants.sort()
        newLogin = ""
    }

    private func revokeLogin(_ login: String) async {
        let error = await onRevokeLogin(proxyName, login)
        if let error { errorMessage = error; return }
        loginGrants.removeAll { $0 == login }
    }
}
