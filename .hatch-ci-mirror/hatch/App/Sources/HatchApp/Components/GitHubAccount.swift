import SwiftUI
import Security
import HatchCore
import HatchSync

/// The GitHub token Hatch stores, in the macOS Keychain. Nothing else is written to disk.
enum HXKeychain {
    private static let service = "app.hatch.github"
    private static let account = "token"

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    static func read() -> String? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    @discardableResult
    static func write(_ token: String) -> Bool {
        delete()
        var q = query
        q[kSecValueData as String] = Data(token.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
    }

    static func delete() { SecItemDelete(query as CFDictionary) }
}

enum HXGitHub {
    /// The client every part of the app uses: the Keychain token first, then GITHUB_TOKEN, then the gh tool.
    static func client() -> GitHubClient { GitHubClient(token: HXKeychain.read()) }
}

/// Who Hatch is signed in as, which repositories it can see, and the actions that link or create the tickets repository.
@MainActor
final class GitHubAccountModel: ObservableObject {
    struct Probe: Sendable {
        var source: GitHubTokenSource
        var user: GitHubUser?
        var repos: [GitHubRepoSummary]
        var error: String?
    }

    @Published var user: GitHubUser?
    @Published var source: GitHubTokenSource = .none
    @Published var repos: [GitHubRepoSummary] = []
    @Published var busy = false
    @Published var error: String?

    func refresh() {
        busy = true
        Task {
            let probe = await Task.detached { () -> Probe in
                let source = GitHubClient.tokenSource(stored: HXKeychain.read())
                guard source != .none else { return Probe(source: source, user: nil, repos: [], error: nil) }
                let client = HXGitHub.client()
                do {
                    let me = try client.currentUser()
                    let repos = try client.listRepositories()
                    return Probe(source: source, user: me, repos: repos, error: nil)
                } catch {
                    return Probe(source: source, user: nil, repos: [], error: Self.describe(error))
                }
            }.value
            source = probe.source
            user = probe.user
            repos = probe.repos
            error = probe.error
            busy = false
        }
    }

    func connect(token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !HXKeychain.write(trimmed) { error = "The Keychain would not store the token."; return }
        refresh()
    }

    func signOut() {
        HXKeychain.delete()
        refresh()
    }

    /// Links `fullName` as a tickets repository, creating it (private) when asked. Reports back on the main actor.
    func prepareTicketsRepo(_ fullName: String, create: Bool, done: @escaping (Result<TicketsRepoReport, Error>) -> Void) {
        busy = true
        Task {
            let result = await Task.detached { () -> Result<TicketsRepoReport, Error> in
                Result { try HXGitHub.client().prepareTicketsRepo(fullName, createIfMissing: create) }
            }.value
            busy = false
            if case .success = result { refresh() }
            done(result)
        }
    }

    nonisolated static func describe(_ error: Error) -> String {
        if let t = error as? TrackerError {
            switch t {
            case .noToken: return "No token found."
            case .unauthorized: return "GitHub did not accept this token. It may have expired, or it lacks the repo scope."
            default: return "\(t)"
            }
        }
        return "\(error)"
    }
}

/// "Choose from GitHub…": every repository the token can see, private ones marked.
struct HXRepoPickerMenu: View {
    @ObservedObject var account: GitHubAccountModel
    let onPick: (GitHubRepoSummary) -> Void

    var body: some View {
        Menu {
            if account.repos.isEmpty {
                Text(account.user == nil ? "Connect GitHub in Settings first" : "No repositories found")
            }
            ForEach(account.repos) { repo in
                Button { onPick(repo) } label: {
                    Label(repo.fullName, systemImage: repo.isPrivate ? "lock" : "globe")
                }
            }
        } label: {
            Label("Choose from GitHub", systemImage: "list.bullet")
        }
        .menuIndicator(.hidden)
        .disabled(account.user == nil)
        .task { if account.user == nil && !account.busy { account.refresh() } }
    }
}

/// Create a new private repository for the tickets (or link one that exists). Never creates a public one.
struct HXCreateTicketsRepoSheet: View {
    @ObservedObject var account: GitHubAccountModel
    let projectName: String
    let onLinked: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var owner = ""
    @State private var name = ""
    @State private var message: String?
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create a private tickets repository").font(.title3.weight(.semibold))
            Text("Hatch creates it private and adds its labels. Your tickets are stored as issues there.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                TextField("Owner", text: $owner).textFieldStyle(.roundedBorder).frame(width: 160)
                Text("/")
                TextField("Name", text: $name).textFieldStyle(.roundedBorder)
            }
            Text("Use your own account name, or an organisation where you can create repositories.")
                .font(.caption).foregroundStyle(.secondary)
            if let message {
                Text(message).font(.callout).foregroundStyle(failed ? Theme.critical : Color.secondary)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.glass)
                Button { create() } label: { Label("Create", systemImage: "plus") }
                    .buttonStyle(.glassProminent)
                    .disabled(owner.isEmpty || name.isEmpty || account.busy)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .padding(20)
        .frame(width: 460)
        .onAppear {
            if owner.isEmpty { owner = account.user?.login ?? "" }
            if name.isEmpty { name = projectName.lowercased().filter { $0.isLetter || $0.isNumber } + "-tickets" }
        }
    }

    private func create() {
        let full = "\(owner)/\(name)"
        message = "Creating \(full)…"; failed = false
        account.prepareTicketsRepo(full, create: true) { result in
            switch result {
            case .success(let report):
                if report.isPublic {
                    message = "\(full) exists and is public. Tickets would be visible to everyone. Choose or create a private one."
                    failed = true
                } else {
                    onLinked(full)
                    dismiss()
                }
            case .failure(let error):
                message = GitHubAccountModel.describe(error); failed = true
            }
        }
    }
}
