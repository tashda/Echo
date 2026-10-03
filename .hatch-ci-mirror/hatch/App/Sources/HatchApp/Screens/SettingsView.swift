import SwiftUI
import AppKit
import HatchCore
import HatchSync

/// Settings: paths, agent limit, the apps Hatch launches, and where the GitHub token comes from.
struct SettingsView: View {
    @EnvironmentObject var state: AppState

    @State private var maxAgents = 3
    @State private var tokenStatus = "Checking..."
    @State private var claudeStatus = "Checking..."
    @State private var loaded = false
    @StateObject private var account = GitHubAccountModel()
    @State private var tokenText = ""

    var body: some View {
        Form {
            Section("Files") {
                LabeledContent("Hatch home") { Text(state.paths.root.path).textSelection(.enabled) }
                LabeledContent("Database") { Text(state.paths.database.path).textSelection(.enabled) }
            }
            Section("Agents") {
                Stepper(value: $maxAgents, in: 1...12) { Text("Max agents at once: \(maxAgents)") }
                    .onChange(of: maxAgents) { _, newValue in
                        if loaded { state.hxSaveSetting("max_agents", String(newValue)) }
                    }
                HXPathRow(title: "claude CLI", key: "claude_path", placeholder: "Found automatically", chooseApp: false)
                Text(claudeStatus).font(.caption).foregroundStyle(.secondary)
            }
            Section("Apps Hatch opens") {
                HXPathRow(title: "Preview app copy", key: "preview_app_path", placeholder: "Path to Echo (Preview).app", chooseApp: true)
                HXPathRow(title: "Hatch Stage", key: "stage_executable", placeholder: "Path to the Stage executable", chooseApp: false)
                HXPathRow(title: "Spec app", key: "spec_app_path", placeholder: "Optional: the project's Spec app", chooseApp: true)
            }
            Section("GitHub") {
                LabeledContent("Account") { Text(accountLine) }
                if let error = account.error {
                    Text(error).font(.callout).foregroundStyle(Theme.critical)
                }
                HStack {
                    SecureField("Paste a token", text: $tokenText).textFieldStyle(.roundedBorder)
                    Button { account.connect(token: tokenText); tokenText = "" } label: { Label("Connect", systemImage: "link") }
                        .buttonStyle(.glassProminent)
                        .disabled(tokenText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .controlSize(.large)
                HStack {
                    Link(destination: URL(string: "https://github.com/settings/tokens/new?scopes=repo&description=Hatch")!) {
                        Label("Create a token on GitHub", systemImage: "arrow.up.right.square")
                    }
                    Spacer()
                    if account.source == .stored {
                        Button { account.signOut() } label: { Label("Remove token", systemImage: "xmark") }.buttonStyle(.glass)
                    }
                    Button { account.refresh() } label: { Label("Check again", systemImage: "arrow.clockwise") }.buttonStyle(.glass)
                }
                Text("A token with the repo scope lets Hatch create private repositories and sync tickets. It is kept in the macOS Keychain. Without one, Hatch uses GITHUB_TOKEN or the gh command line tool. Tickets repositories are always created private.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, minHeight: 480)
        .onAppear { load(); account.refresh() }
    }

    private var accountLine: String {
        if account.busy && account.user == nil { return "Checking…" }
        guard let user = account.user else { return account.source == .none ? "Not connected" : "Token found, but not accepted" }
        let from: String
        switch account.source {
        case .stored: from = "token in Keychain"
        case .environment: from = "GITHUB_TOKEN"
        case .ghTool: from = "gh tool"
        case .none: from = ""
        }
        return "@\(user.login) · \(from)"
    }

    private func load() {
        if let s = state.hxSetting("max_agents"), let n = Int(s) {
            maxAgents = n
        } else {
            maxAgents = (try? state.store.maxAgents(projectId: state.projectFilterId)) ?? 3
        }
        loaded = true
        let configured = state.hxSetting("claude_path")
        Task {
            let status = await Task.detached { () -> (String, String) in
                (HXSettingsProbe.tokenStatus(), HXSettingsProbe.claudeStatus(configured: configured))
            }.value
            tokenStatus = status.0
            claudeStatus = status.1
        }
    }
}

enum HXSettingsProbe {
    static func tokenStatus() -> String {
        if let env = ProcessInfo.processInfo.environment["GITHUB_TOKEN"], !env.isEmpty {
            return "From the GITHUB_TOKEN environment variable"
        }
        if let out = HXShell.shell("gh auth token", cwd: nil), out.status == 0,
           !out.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "From the gh command line tool"
        }
        return "No token found. Run gh auth login, or set GITHUB_TOKEN."
    }

    static func claudeStatus(configured: String?) -> String {
        if let path = HXAskAdapter.locateClaude(setting: configured) { return "Using \(path)" }
        return "claude CLI not found. Install Claude Code or set its path."
    }
}

/// One path setting with a text field and a Choose button.
struct HXPathRow: View {
    @EnvironmentObject var state: AppState
    let title: String
    let key: String
    let placeholder: String
    let chooseApp: Bool

    @State private var text = ""
    @State private var loaded = false

    var body: some View {
        HStack {
            Text(title).frame(width: 130, alignment: .leading)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit { commit() }
            Button("Choose...") { choose() }
        }
        .onAppear {
            if !loaded {
                text = state.hxSetting(key) ?? ""
                loaded = true
            }
        }
        .onDisappear { commit() }
    }

    private func commit() {
        guard loaded else { return }
        if text != (state.hxSetting(key) ?? "") { state.hxSaveSetting(key, text) }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = chooseApp
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            text = url.path
            commit()
        }
    }
}
