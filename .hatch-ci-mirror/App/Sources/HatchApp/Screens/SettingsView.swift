import SwiftUI
import AppKit
import HatchCore

/// Settings: paths, agent limit, the apps Hatch launches, and where the GitHub token comes from.
struct SettingsView: View {
    @EnvironmentObject var state: AppState

    @State private var maxAgents = 3
    @State private var tokenStatus = "Checking..."
    @State private var claudeStatus = "Checking..."
    @State private var loaded = false

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
                LabeledContent("Token") { Text(tokenStatus) }
                Text("Hatch uses GITHUB_TOKEN if it is set, otherwise the token from the gh command line tool.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, minHeight: 480)
        .onAppear { load() }
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
