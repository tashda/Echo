import SwiftUI
import AppKit
import HatchCore
import HatchGit
import HatchSync
import HatchAgent
import HatchImport

// Shared helpers and thin adapters around the modules other agents are still writing.
// If a module's API changes, only this file should need to change.

// MARK: AppState conveniences (prefixed hx so they cannot collide with other files)

extension AppState {
    /// The project a screen works on: the selected one, otherwise the first.
    var hxProject: Project? { selectedProject ?? projects.first }

    func hxSetting(_ key: String) -> String? {
        let value: String? = try? store.setting(key)
        if let value, !value.isEmpty { return value }
        return nil
    }

    func hxSaveSetting(_ key: String, _ value: String) {
        perform("Save setting") { try store.setSetting(key, value) }
    }
}

// MARK: Small shared views

struct HXChip: View {
    let text: String
    let turn: Turn

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(Theme.color(for: turn))
            .background(Theme.background(for: turn), in: Capsule())
    }
}

struct HXStatusChip: View {
    let status: Status

    var body: some View {
        StatusChip(status: status)
    }
}

struct HXHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title2.weight(.semibold))
            if !subtitle.isEmpty {
                Text(subtitle).font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

struct HXEmpty: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 28)).foregroundStyle(.tertiary)
            Text(title).font(.headline)
            Text(detail).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

/// A quiet rounded container used for the cards on several screens.
struct HXCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
    }
}

func hxAgo(_ date: Date) -> String {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .short
    return f.localizedString(for: date, relativeTo: Date())
}

func hxClock(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds))
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%d:%02d", m, s)
}

func hxTokens(_ n: Int) -> String {
    if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
    if n >= 1000 { return String(format: "%.0fk", Double(n) / 1000) }
    return String(n)
}

// MARK: Running programs

enum HXShell {
    struct Output {
        var status: Int32
        var text: String
    }

    /// Runs a program and waits. Returns nil when it cannot be started.
    static func run(_ launch: String, _ args: [String], cwd: String? = nil, mergeStderr: Bool = false) -> Output? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launch)
        p.arguments = args
        if let cwd { p.currentDirectoryURL = URL(fileURLWithPath: cwd) }
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = mergeStderr ? pipe : FileHandle.nullDevice
        p.standardInput = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return Output(status: p.terminationStatus, text: String(decoding: data, as: UTF8.self))
    }

    /// Runs a shell command line with the user's login shell (so PATH has Xcode, Homebrew and so on).
    static func shell(_ command: String, cwd: String?) -> Output? {
        run("/bin/zsh", ["-lc", command], cwd: cwd, mergeStderr: true)
    }
}

// MARK: HatchCore.Previews (HatchGit.PreviewBuilder)

struct HXPreviewOutcome: Sendable {
    var previewId: Int?
    var name: String = ""
    var branch: String?
    var worktreePath: String?
    var mergedIds: [Int] = []
    var conflictTicket: Int?
    var conflictAgainst: Int?
    var conflictFiles: [String] = []
    var buildOK: Bool = false
    var buildLog: String = ""
    var errorText: String?
}

enum HXPreviewAdapter {
    /// Merges the chosen tickets into a throwaway branch, then runs the repo's build command once in that worktree.
    static func build(store: HatchStore, repo: Repo, ticketIds: [Int]) -> HXPreviewOutcome {
        var outcome = HXPreviewOutcome()
        var tickets: [Ticket] = []
        for id in ticketIds {
            if let t = try? store.ticket(id: id) { tickets.append(t) }
        }
        do {
            let manager = WorkspaceManager(store: store)
            let builder = PreviewBuilder(workspaces: manager)
            let result = try builder.build(repo: repo, tickets: tickets)
            outcome.previewId = result.preview.id
            outcome.name = result.preview.name
            outcome.branch = result.preview.branch
            outcome.worktreePath = result.worktreePath
            outcome.mergedIds = result.mergedTicketIds
            if let c = result.conflict {
                outcome.conflictTicket = c.ticketId
                outcome.conflictAgainst = c.againstTicketId
                outcome.conflictFiles = c.files
                return outcome
            }
            if let path = result.worktreePath, let cmd = repo.buildCommand, !cmd.isEmpty {
                let out = HXShell.shell(cmd, cwd: path)
                outcome.buildOK = (out?.status == 0)
                let text = out?.text ?? "Could not start the build command."
                outcome.buildLog = String(text.suffix(4000))
                try? store.setPreview(result.preview.id, state: "merged", log: outcome.buildLog, built: outcome.buildOK)
            } else {
                outcome.buildOK = true
            }
        } catch {
            outcome.errorText = "\(error)"
        }
        return outcome
    }

    static func discard(store: HatchStore, preview: HatchCore.Preview, repo: Repo) -> String? {
        do {
            let manager = WorkspaceManager(store: store)
            let builder = PreviewBuilder(workspaces: manager)
            try builder.discard(preview, repo: repo)
            return nil
        } catch {
            return "\(error)"
        }
    }
}

// MARK: Merge into the integration branch (J5), using HatchGit.MergePlan and MergeExecutor

enum HXMergeAdapter {
    struct Step: Sendable {
        var title: String
        var ok: Bool
        var detail: String
    }

    /// The plan as plain lines: design system first (merge, tag), then the app into the integration branch.
    static func planLines(store: HatchStore, project: Project, tickets: [Ticket]) -> [String] {
        do {
            let plan = try MergePlan.build(project: project, tickets: tickets, store: store)
            return plan.steps.map { $0.description }
        } catch {
            return ["Could not build the merge plan: \(error)"]
        }
    }

    /// Runs the plan. The owner's own checkout is never touched (Hatch uses its own worktree).
    static func run(store: HatchStore, project: Project, tickets: [Ticket]) -> [Step] {
        do {
            let plan = try MergePlan.build(project: project, tickets: tickets, store: store)
            if plan.isEmpty { return [Step(title: "Nothing to merge", ok: false, detail: "None of the approved tickets has a workspace.")] }
            let executor = MergeExecutor(workspaces: WorkspaceManager(store: store))
            let run = try executor.run(plan)
            return run.results.map { r in
                Step(title: r.step.description, ok: r.ok, detail: r.ok ? "" : String(r.output.suffix(600)))
            }
        } catch {
            return [Step(title: "Merge failed", ok: false, detail: "\(error)")]
        }
    }

    /// Moves the integration branch into the base branch once CI is green.
    static func promote(store: HatchStore, repo: Repo, integration: String, ciPassed: Bool) -> Step {
        do {
            let executor = MergeExecutor(workspaces: WorkspaceManager(store: store))
            let result = try executor.promote(repo: repo, integration: integration, into: repo.defaultBranch, ciPassed: ciPassed)
            return Step(title: "Promoted \(integration) to \(repo.defaultBranch)", ok: true, detail: String(result.sha.prefix(8)))
        } catch {
            return Step(title: "Could not promote \(integration)", ok: false, detail: "\(error)")
        }
    }
}

// MARK: CI status from HatchSync (I6)

enum HXCIAdapter {
    /// One line the UI can show: "passing", "running", "failing: name", or why it is unknown.
    static func status(remote: String, ref: String) -> String {
        do {
            let engine = SyncEngine(store: try HatchStore.inMemory(), tracker: GitHubClient())
            let state = try engine.ciStatus(repo: remote, ref: ref)
            switch state {
            case .passed: return "passing"
            case .pending: return "running or not started"
            case .failed(let names): return "failing: " + names.joined(separator: ", ")
            }
        } catch {
            return "unknown (\(error))"
        }
    }
}

// MARK: Claude CLI (Ask panel)

enum HXAskAdapter {
    enum Failure: Error, CustomStringConvertible {
        case notFound
        case failed(String)

        var description: String {
            switch self {
            case .notFound: return "claude CLI not found"
            case .failed(let m): return m
            }
        }
    }

    /// The setting wins; otherwise the usual install places, then whatever the login shell finds.
    static func locateClaude(setting: String?) -> String? {
        let fm = FileManager.default
        if let s = setting, !s.isEmpty, fm.isExecutableFile(atPath: s) { return s }
        let home = NSHomeDirectory()
        let candidates = [
            home + "/.claude/local/claude",
            home + "/.local/bin/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
        ]
        for c in candidates where fm.isExecutableFile(atPath: c) { return c }
        if let out = HXShell.shell("command -v claude", cwd: nil), out.status == 0 {
            let path = out.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty, fm.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }

    struct Answer: Sendable {
        var text: String
        var tokensIn: Int
        var tokensOut: Int
    }

    /// Runs HatchAgent's ClaudeCLIRunner off the main thread.
    static func ask(prompt: String, claudePath: String) async throws -> Answer {
        let result: Result<Answer, Failure> = await Task.detached(priority: .userInitiated) { () -> Result<Answer, Failure> in
            let runner = ClaudeCLIRunner(executable: claudePath, workingDirectory: URL(fileURLWithPath: NSHomeDirectory()), timeout: 180)
            do {
                let out = try runner.run(prompt: prompt, options: AgentOptions())
                let text = out.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty { return .failure(.failed("claude returned an empty answer.")) }
                return .success(Answer(text: text, tokensIn: out.tokensIn, tokensOut: out.tokensOut))
            } catch {
                return .failure(.failed("\(error)"))
            }
        }.value
        switch result {
        case .success(let answer): return answer
        case .failure(let f): throw f
        }
    }
}

// MARK: Area scan (L2): HatchImport first, a simple folder scan as fallback.

enum HXAreasAdapter {
    static func suggestAreas(repoPath: String) -> [AreaConfig] {
        let fromModule = ProjectBootstrap.suggestAreas(repoRoot: URL(fileURLWithPath: repoPath))
        if !fromModule.isEmpty { return fromModule }
        return fallbackScan(repoPath: repoPath)
    }

    private static func fallbackScan(repoPath: String) -> [AreaConfig] {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: repoPath)

        func subdirs(_ url: URL) -> [String] {
            let names = (try? fm.contentsOfDirectory(atPath: url.path)) ?? []
            var out: [String] = []
            for n in names.sorted() where !n.hasPrefix(".") {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: url.appendingPathComponent(n).path, isDirectory: &isDir), isDir.boolValue { out.append(n) }
            }
            return out
        }

        var parents: [String] = ["Sources/Features", "Sources"]
        for top in subdirs(root) {
            parents.insert(top + "/Sources/Features", at: 0)
            parents.append(top + "/Sources")
        }
        for parent in parents {
            let url = root.appendingPathComponent(parent)
            let children = subdirs(url)
            if children.isEmpty { continue }
            return children.map { name in
                let letters = name.filter { $0.isLetter }
                let prefix = String(letters.prefix(5)).uppercased()
                return AreaConfig(name: name, paths: ["\(parent)/\(name)/**"], specPrefix: prefix.isEmpty ? nil : prefix)
            }
        }
        return []
    }
}
