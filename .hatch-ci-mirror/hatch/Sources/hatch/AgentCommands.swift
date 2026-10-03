import Foundation
import HatchCore
import HatchGit
import HatchSync
import HatchAgent
import HatchAPI
import HatchImport

/// Commands that use the other modules. Agents run take, offer, ready; people run vet, sync, serve and the imports.
enum AgentCommands {
    static let all: [String: Handler] = [
        "take": take, "offer": offer, "ready": ready, "vet": vet,
        "sync": sync, "serve": serve, "import-labs": importLabs, "spec": spec, "workspace": workspace, "preview": preview,
    ]

    /// Runs a shell command in a folder and returns (ok, last lines of output, seconds).
    static func shell(_ command: String, in dir: String, timeout: TimeInterval = 1800) -> (ok: Bool, tail: String, seconds: Double) {
        let p = Process(), pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: "/bin/sh"); p.arguments = ["-c", command]; p.currentDirectoryURL = URL(fileURLWithPath: dir)
        p.standardOutput = pipe; p.standardError = pipe
        let start = Date()
        do { try p.run() } catch { return (false, "could not start: \(error)", 0) }
        var data = Data()
        let reader = DispatchQueue(label: "hatch.shell"); let group = DispatchGroup(); group.enter()
        reader.async { data = pipe.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        let deadline = Date().addingTimeInterval(timeout)
        while p.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.2) }
        if p.isRunning { p.terminate() }
        group.wait()
        let text = String(decoding: data, as: UTF8.self)
        let tail = text.split(separator: "\n").suffix(25).joined(separator: "\n")
        return (p.terminationStatus == 0, tail, Date().timeIntervalSince(start))
    }

    // hatch take #151 [--agent "Agent on #151"]  -> claims the ticket, creates workspaces, prints the brief
    static func take(_ c: Context) throws {
        let t = try c.ticket(c.args.pos(1))
        let agent = c.args.option("agent") ?? "Agent on \(t.displayNumber)"
        let task = try c.store.take(t.id, agent: agent)
        let wanted: [RepoRole] = task.kind == .prepare ? [.specimens] : (task.kind == .build || task.kind == .fix ? [.app, .designSystem] : [])
        var spaces: [String] = [], notes: [String] = []
        if !wanted.isEmpty && !c.args.flag("no-workspace") {
            let manager = WorkspaceManager(store: c.store)
            for repo in try c.store.repos(projectId: task.ticket.projectId) where wanted.contains(repo.role) {
                guard repo.localPath != nil else { notes.append("No local clone configured for the \(repo.role.rawValue) repository, so no workspace was made for it."); continue }
                let ws = try manager.create(ticket: task.ticket, repo: repo)
                spaces.append("\(repo.role.rawValue): \(ws.path)  (branch \(ws.branch))")
            }
        }
        let brief = try BriefBuilder.brief(store: c.store, ticketId: t.id, agent: agent, kind: task.kind)
        var text = brief
        if !spaces.isEmpty { text += "\n\nYour workspaces (work only inside these folders):\n" + spaces.map { "  " + $0 }.joined(separator: "\n") }
        if !notes.isEmpty { text += "\n\n" + notes.joined(separator: "\n") }
        c.out.emit(["ticket": .string(t.displayNumber), "task": .string(task.kind.rawValue), "workspaces": .array(spaces.map { .string($0) }), "brief": .string(brief)], text: text)
    }

    // hatch offer #151 manifest.json | --sketch sketch.json | --answer "text"
    static func offer(_ c: Context) throws {
        let t = try c.ticket(c.args.pos(1))
        let service = OfferService(store: c.store, agent: t.takenBy ?? "agent")
        let result: OfferResult
        if let answer = c.args.option("answer") { result = try service.offerAnswer(ticketId: t.id, answer: answer) }
        else if let sketch = c.args.option("sketch") {
            let data = try Data(contentsOf: URL(fileURLWithPath: sketch))
            let manifest = try JSONDecoder().decode(SketchManifest.self, from: data)
            result = try service.offer(ticketId: t.id, sketch: manifest, baseDirectory: URL(fileURLWithPath: sketch).deletingLastPathComponent())
        } else {
            guard let file = c.args.pos(2) else { throw CLIError("Usage: hatch offer #151 manifest.json   |   --sketch sketch.json   |   --answer \"text\"") }
            result = try service.offer(ticketId: t.id, json: try String(contentsOfFile: file, encoding: .utf8))
        }
        switch result {
        case .offered(let ticket, let revision, let warnings):
            let text = "Offered. \(ticket.displayNumber) is now \(ticket.status.displayName) (revision \(revision)); the owner will judge it." + (warnings.isEmpty ? "" : "\nWarnings:\n" + warnings.map { "  - \($0.message)" }.joined(separator: "\n"))
            c.out.emit(["offered": true, "status": .string(ticket.status.rawValue), "revision": .int(revision), "warnings": .array(warnings.map { .string($0.message) })], text: text)
        case .rejected(let issues):
            let text = "Not offered. Fix these and run hatch offer again:\n" + issues.map { "  - [\($0.code)] \($0.message)\n      fix: \($0.fix)" }.joined(separator: "\n")
            c.out.emit(["offered": false, "issues": .array(issues.map { ["code": .string($0.code), "message": .string($0.message), "fix": .string($0.fix)] })], text: text)
            if !c.out.json { exit(2) }
        }
    }

    // hatch ready #144 -> Hatch runs merge-base, build, tests and match check and moves the ticket itself
    static func ready(_ c: Context) throws {
        let t = try c.ticket(c.args.pos(1))
        guard t.status == .building || t.status == .fixing else { throw CLIError("\(t.displayNumber) is \(t.status.displayName); ready only applies while Building or Fixing.") }
        let project = try c.store.project(id: t.projectId)
        let manager = WorkspaceManager(store: c.store)
        let spaces = try manager.list(ticketId: t.id).filter { $0.state == "active" }
        guard !spaces.isEmpty else { throw CLIError("No workspace for \(t.displayNumber). Run hatch take first.") }
        let repos = try c.store.repos(projectId: t.projectId)
        var failures: [String] = [], lines: [String] = []
        func step(_ kind: String, ok: Bool, detail: String, seconds: Double = 0) throws {
            try c.store.record(t.id, actor: "hatch", kind: kind, payload: ["ok": .bool(ok), "detail": .string(detail), "seconds": .number(seconds)])
            lines.append("\(ok ? "ok  " : "FAIL") \(kind): \(detail)")
            if !ok { failures.append("\(kind): \(detail)") }
        }
        for ws in spaces {
            guard let repo = repos.first(where: { $0.id == ws.repoId }) else { continue }
            let cfg = project?.config?.repo(repo.role)
            switch try manager.mergeBaseIntoBranch(ws) {
            case .upToDate, .merged: break
            case .conflicts(let files): try step("merge-base", ok: false, detail: "\(repo.role.rawValue) conflicts with \(repo.defaultBranch) in \(files.joined(separator: ", ")). Resolve them in the workspace and run ready again.")
            }
            let status = try manager.status(ws)
            try step("commit", ok: status.dirtyFiles.isEmpty, detail: status.dirtyFiles.isEmpty ? "\(repo.role.rawValue): \(status.commitsAhead) commit(s) ahead" : "\(repo.role.rawValue) has uncommitted files: \(status.dirtyFiles.prefix(5).joined(separator: ", ")). Commit them first.")
            let drift = try ClaimsFromDiff(store: c.store).claimDrift(t, workspace: ws)
            if drift.hasDrift { try c.store.record(t.id, actor: "hatch", kind: "claim-drift", payload: ["files": .array(drift.unclaimedChanges.map { .string($0) })]); lines.append("note: changed files outside the claim: \(drift.unclaimedChanges.prefix(5).joined(separator: ", "))") }
            for (kind, cmd) in [("build", cfg?.buildCommand), ("tests", cfg?.testCommand), ("match-check", cfg?.matchCommand)] {
                guard let cmd, !cmd.isEmpty else { continue }
                let r = shell(cmd, in: ws.path)
                try step(kind, ok: r.ok, detail: r.ok ? "\(repo.role.rawValue) passed" : "\(repo.role.rawValue) failed:\n\(r.tail)", seconds: r.seconds)
                if !r.ok { break }
            }
        }
        if failures.isEmpty {
            let after = try c.store.move(t.id, to: .toVerify, actor: .hatch, reason: "build, tests and match check passed")
            c.out.emit(["ready": true, "status": .string(after.status.rawValue)], text: lines.joined(separator: "\n") + "\nAll checks passed. \(after.displayNumber) is now \(after.status.displayName); the owner will verify it in a Preview. You are done with this ticket.")
        } else {
            c.out.emit(["ready": false, "failures": .array(failures.map { .string($0) })], text: lines.joined(separator: "\n") + "\nNot ready. Fix the failures above in your workspace, commit, and run hatch ready again.")
            if !c.out.json { exit(2) }
        }
    }

    // hatch vet #151 [--claude path]  -> Iris checks a ticket in Checking (people or Hatch run this, it costs tokens)
    static func vet(_ c: Context) throws {
        let t = try c.ticket(c.args.pos(1))
        let runner = ClaudeCLIRunner(executable: c.args.option("claude") ?? "claude", model: c.args.option("model"))
        let outcome = try VettingService(store: c.store, runner: runner).vet(ticketId: t.id)
        switch outcome {
        case .vetted(let o): c.out.emit(["vetted": true, "questions": .int(o.questionsAsked), "suggestion": .bool(o.suggestionStored), "status": .string(o.status.rawValue)], text: "Iris checked \(t.displayNumber): \(o.questionsAsked) question(s), \(o.suggestionStored ? "a suggestion to review" : "no suggestion"). Status: \(o.status.displayName).")
        case .failed(let why): c.out.emit(["vetted": false, "error": .string(why)], text: "Iris could not check \(t.displayNumber): \(why)"); exit(1)
        }
    }

    static func tracker(_ c: Context) throws -> IssueTracker {
        if c.args.flag("dry-run") { return InMemoryTracker() }
        return GitHubClient()
    }

    // hatch sync [push|pull|all] [--repo owner/tickets] [--dry-run]
    static func sync(_ c: Context) throws {
        let p = try c.project()
        guard let repo = c.args.option("repo") ?? p.config?.ticketsRepo, !repo.isEmpty else {
            throw CLIError("This project has no tickets repository. Set one in Project settings, or pass --repo owner/name.")
        }
        let engine = SyncEngine(store: c.store, tracker: try tracker(c))
        let mode = c.args.pos(1) ?? "all"
        var parts: [String] = []
        if mode == "push" || mode == "all" { parts.append("push: \(try engine.pushPending(repo: repo))") }
        if mode == "pull" || mode == "all" { parts.append("pull: \(try engine.pull(repo: repo, projectId: p.id))") }
        let counts = try c.store.syncCounts()
        c.out.emit(["pending": .int(counts.pending), "failed": .int(counts.failed)], text: parts.joined(separator: "\n") + "\nQueue: \(counts.pending) pending, \(counts.failed) failed.")
    }

    // hatch serve  -> the local API for the Stage app
    static func serve(_ c: Context) throws {
        let server = StageServer(store: c.store, port: UInt16(c.args.option("port") ?? "0") ?? 0)
        try server.start()
        print("Hatch Stage API on http://127.0.0.1:\(server.port)  (token in \(HatchPaths.current().tokenFile.path))")
        RunLoop.main.run()
    }

    // hatch import-labs --file EchoLab/State/lab-state.json [--enqueue]
    static func importLabs(_ c: Context) throws {
        let p = try c.project()
        guard let file = c.args.option("file") else { throw CLIError("Usage: hatch import-labs --file <lab-state.json> [--catalog <EchoLab/Sources/EchoLab folder>] [--enqueue]") }
        var options = ImportOptions(enqueueSync: c.args.flag("enqueue"))
        if let cat = c.args.option("catalog") { options = ImportOptions(enqueueSync: options.enqueueSync, catalog: LabCatalog.load(echoLabSources: URL(fileURLWithPath: cat))) }
        let report = try LabImporter.importState(file: URL(fileURLWithPath: file), project: p, store: c.store, options: options)
        c.out.emit(["report": .string("\(report)")], text: "\(report)")
    }

    // hatch spec index [--dir .hatch/spec]  |  hatch spec export --from <Areas dir> --to <dir>
    static func spec(_ c: Context) throws {
        switch c.args.pos(1) {
        case "index":
            let dir = c.args.option("dir") ?? ".hatch/spec"
            let r = try SpecIndexer.index(directory: URL(fileURLWithPath: dir), project: try c.project(), store: c.store)
            c.out.emit(["result": .string("\(r)")], text: "\(r)")
        case "export":
            guard let from = c.args.option("from"), let to = c.args.option("to") else { throw CLIError("Usage: hatch spec export --from <Areas folder> --to <folder>") }
            let areas = SpecExporter.extractAll(areasDirectory: URL(fileURLWithPath: from))
            let files = try SpecExporter.write(areas, to: URL(fileURLWithPath: to))
            c.out.emit(["areas": .int(areas.count)], text: "Wrote \(files.count) spec file(s) for \(areas.count) areas.")
        default: throw CLIError("Usage: hatch spec index|export ...")
        }
    }

    // hatch workspace list|remove #151
    static func workspace(_ c: Context) throws {
        let manager = WorkspaceManager(store: c.store)
        switch c.args.pos(1) {
        case "list":
            let spaces = try manager.list().filter { $0.state == "active" }
            c.out.emit(.array(spaces.map { ["ticket": .int($0.ticketId), "path": .string($0.path), "branch": .string($0.branch)] }), text: spaces.isEmpty ? "No active workspaces." : spaces.map { "\($0.branch)  \($0.path)" }.joined(separator: "\n"))
        case "remove":
            let t = try c.ticket(c.args.pos(2))
            for ws in try manager.list(ticketId: t.id) { try manager.remove(ws, deleteBranch: c.args.flag("all")) }
            c.out.emit(["removed": .string(t.displayNumber)], text: "Removed the workspaces of \(t.displayNumber).")
        default: throw CLIError("Usage: hatch workspace list|remove #151 [--all]")
        }
    }

    // hatch preview #144 #146 ...  -> merges the tickets' branches into a throwaway Preview branch
    static func preview(_ c: Context) throws {
        let tickets = try c.args.positionals.dropFirst().map { try c.store.resolve($0) }
        guard let first = tickets.first else { throw CLIError("Usage: hatch preview #144 #146 ...") }
        guard let app = try c.store.repo(projectId: first.projectId, role: .app) else { throw CLIError("The project has no app repository configured.") }
        let result = try PreviewBuilder(workspaces: WorkspaceManager(store: c.store)).build(repo: app, tickets: tickets)
        if let conflict = result.conflict {
            let a = try c.store.ticket(id: conflict.ticketId)?.displayNumber ?? "?", b = try c.store.ticket(id: conflict.againstTicketId)?.displayNumber ?? "?"
            c.out.emit(["clean": false, "pair": [.string(a), .string(b)], "files": .array(conflict.files.map { .string($0) })], text: "\(a) conflicts with \(b) in \(conflict.files.joined(separator: ", ")). Options: drop one, stack them, or ask an agent to resolve.")
            exit(2)
        }
        c.out.emit(["clean": true, "preview": .string(result.preview.name), "path": .string(result.worktreePath ?? "")], text: "\(result.preview.name) merged cleanly at \(result.worktreePath ?? "?").")
    }
}
