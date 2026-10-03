import XCTest
import HatchCore
@testable import HatchGit

/// Real temporary repositories for every test; identity and config are pinned so the user's git setup cannot leak in.
class GitTestCase: XCTestCase {
    var tmp: String!
    var store: HatchStore!
    var project: Project!
    var git: ProcessGit!
    var manager: WorkspaceManager!
    var app: Repo!

    static let env = ["GIT_AUTHOR_NAME": "Test", "GIT_AUTHOR_EMAIL": "t@example.com", "GIT_COMMITTER_NAME": "Test",
                      "GIT_COMMITTER_EMAIL": "t@example.com", "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1"]

    override func setUpWithError() throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory()).resolvingSymlinksInPath().appendingPathComponent("hatchgit-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        git = ProcessGit(environment: Self.env)
        store = try HatchStore.inMemory()
        var repos: [RepoConfig] = []
        for (role, name) in [(RepoRole.app, "echo"), (.designSystem, "echo-ds"), (.specimens, "echo-specimens")] {
            let dir = try makeRepo(name)
            repos.append(RepoConfig(role: role, remote: "tashda/\(name)", branch: "dev", localPath: dir))
        }
        project = try store.upsertProject(key: "echo", name: "Echo", config: ProjectConfig(name: "Echo", ticketsRepo: "tashda/t", repos: repos))
        app = try store.repo(projectId: project.id, role: .app)
        manager = WorkspaceManager(store: store, git: git)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(atPath: tmp) }

    func repo(_ role: RepoRole) throws -> Repo { try store.repo(projectId: project.id, role: role)! }

    @discardableResult
    func g(_ args: [String], _ dir: String) throws -> String { try git.git(args, in: dir) }

    func write(_ dir: String, _ file: String, _ text: String) throws {
        let url = URL(fileURLWithPath: dir).appendingPathComponent(file)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func read(_ dir: String, _ file: String) -> String? {
        try? String(contentsOfFile: URL(fileURLWithPath: dir).appendingPathComponent(file).path, encoding: .utf8)
    }

    func makeRepo(_ name: String) throws -> String {
        let dir = tmp + "/projects/" + name
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try g(["init", "-q", "-b", "dev"], dir)
        try write(dir, "README.md", "hello\n")
        try write(dir, "a.txt", "line1\nline2\nline3\n")
        try write(dir, "b.txt", "b1\nb2\nb3\n")
        try g(["add", "-A"], dir)
        try g(["commit", "-q", "-m", "init"], dir)
        return dir
    }

    func makeTicket(_ title: String, gh: Int? = nil) throws -> Ticket {
        try store.createTicket(projectId: project.id, type: .tweak, title: title, ghNumber: gh)
    }

    /// Ticket with a workspace in `repo` that has one committed edit.
    func ticketWithEdit(_ title: String, gh: Int, file: String, text: String, repo: Repo? = nil) throws -> (Ticket, Workspace) {
        let r = try repo ?? app!
        let t = try makeTicket(title, gh: gh)
        let ws = try manager.create(ticket: t, repo: r)
        try write(ws.path, file, text)
        try manager.commit(ws, message: "edit \(file) for #\(gh)")
        return (t, ws)
    }

    /// A bare remote added as `origin` and seeded with the default branch.
    func addBareRemote(to repo: Repo) throws -> String {
        let bare = tmp + "/remotes/\(UUID().uuidString).git"
        try FileManager.default.createDirectory(atPath: bare, withIntermediateDirectories: true)
        try g(["init", "-q", "--bare", "-b", "dev"], bare)
        try g(["remote", "add", "origin", bare], repo.localPath!)
        try g(["push", "-q", "origin", "dev"], repo.localPath!)
        try g(["fetch", "-q", "origin"], repo.localPath!)
        return bare
    }
}
