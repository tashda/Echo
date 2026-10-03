import XCTest
import HatchCore
@testable import HatchImport

final class BootstrapTests: XCTestCase {
    func writeConfig(_ root: URL, _ config: ProjectConfig) throws {
        try config.save(to: ProjectBootstrap.configURL(projectRoot: root))
    }

    func testLoadRegistersProjectAndRepos() throws {
        let root = try tempDir("proj")
        try writeConfig(root, ProjectConfig(name: "Echo App", ticketsRepo: "tashda/hatch-tickets", repos: [
            RepoConfig(role: .app, remote: "tashda/echo", branch: "dev", testPlans: ["UnitTests", "LabTests"]),
            RepoConfig(role: .designSystem, remote: "tashda/echo-design-system", branch: "main", localPath: "/elsewhere"),
        ], areas: [AreaConfig(name: "Tabs", paths: ["Echo/Tabs/**"], specPrefix: "TABS")]))
        let store = try HatchStore.inMemory()
        let project = try ProjectBootstrap.load(projectRoot: root, store: store)
        XCTAssertEqual(project.key, "echo-app")
        XCTAssertEqual(project.config?.areas.first?.specPrefix, "TABS")
        let repos = try store.repos(projectId: project.id)
        XCTAssertEqual(repos.count, 2)
        let app = try XCTUnwrap(repos.first { $0.role == .app })
        XCTAssertEqual(app.testPlans, ["UnitTests", "LabTests"])
        XCTAssertEqual(app.localPath, root.path, "the app repo is where the file was found")
        XCTAssertEqual(repos.first { $0.role == .designSystem }?.localPath, "/elsewhere")
    }

    func testLoadTwiceAndWithExplicitKey() throws {
        let root = try tempDir("proj")
        try writeConfig(root, ProjectConfig(name: "Echo", ticketsRepo: "t/t", repos: [RepoConfig(role: .app, remote: "a/b", branch: "dev")]))
        let store = try HatchStore.inMemory()
        let a = try ProjectBootstrap.load(projectRoot: root, store: store, key: "echo")
        let b = try ProjectBootstrap.load(projectRoot: root, store: store, key: "echo")
        XCTAssertEqual(a.id, b.id)
        XCTAssertEqual(try store.projects().count, 1)
        XCTAssertEqual(try store.repos(projectId: a.id).count, 1)
    }

    func testLoadErrors() throws {
        let store = try HatchStore.inMemory()
        let empty = try tempDir("proj")
        XCTAssertThrowsError(try ProjectBootstrap.load(projectRoot: empty, store: store)) { XCTAssertTrue("\($0)".contains("project.json")) }
        try touch(empty, ".hatch/project.json", "{ not json")
        XCTAssertThrowsError(try ProjectBootstrap.load(projectRoot: empty, store: store)) { XCTAssertTrue("\($0)".contains("not a valid project file")) }
    }

    func testExampleProjectFileLoads() throws {
        let example = Paths.hatchRoot.appendingPathComponent("examples/echo-project.json")
        let config = try ProjectConfig.load(from: example)
        XCTAssertEqual(config.ticketsRepo, "tashda/hatch-tickets")
        XCTAssertEqual(config.repo(.app)?.remote, "tashda/echo")
        XCTAssertEqual(config.repo(.app)?.branch, "dev")
        XCTAssertEqual(config.repo(.app)?.testPlans, ["UnitTests", "LabTests"])
        XCTAssertEqual(config.repo(.designSystem)?.remote, "tashda/echo-design-system")
        XCTAssertEqual(config.repo(.specimens)?.remote, "tashda/echo-specimens")
        XCTAssertGreaterThanOrEqual(config.areas.count, 20)
        XCTAssertEqual(Set(config.areas.compactMap(\.specPrefix)).count, config.areas.count, "prefixes are unique")
        XCTAssertEqual(config.area(containing: "Echo/Sources/Features/ActivityMonitor/Views/Graph.swift")?.name, "Activity Monitor")
        let store = try HatchStore.inMemory()
        let root = try tempDir("proj")
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".hatch"), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: example, to: ProjectBootstrap.configURL(projectRoot: root))
        XCTAssertEqual(try ProjectBootstrap.load(projectRoot: root, store: store).key, "echo")
    }

    // MARK: Area suggestions

    func testSuggestAreasFromFeaturesFolder() throws {
        let root = try tempDir("repo")
        try touch(root, "App/Sources/Features/ObjectBrowser/Views/Tree.swift")
        try touch(root, "App/Sources/Features/ObjectBrowser/Model.swift")
        try touch(root, "App/Sources/Features/Notifications/Toast.swift")
        try touch(root, "App/Sources/Features/SQLServerAgent/Jobs.swift")
        try touch(root, "App/Sources/Features/Empty/.keep-nothing-here/.gitkeep", "")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("App/Sources/Features/Hollow"), withIntermediateDirectories: true)
        try touch(root, "App/Sources/Features/loose.swift")
        try touch(root, "App/.build/Features/Junk/x.swift")
        let areas = ProjectBootstrap.suggestAreas(repoRoot: root)
        XCTAssertEqual(areas.map(\.name), ["Notifications", "Object Browser", "SQL Server Agent"])
        XCTAssertEqual(areas.map(\.paths), [["App/Sources/Features/Notifications/**"], ["App/Sources/Features/ObjectBrowser/**"], ["App/Sources/Features/SQLServerAgent/**"]])
        XCTAssertEqual(areas.map(\.specPrefix), ["NTF", "OB", "SSA"])
        XCTAssertTrue(Glob.matches(areas[1].paths[0], "App/Sources/Features/ObjectBrowser/Views/Tree.swift"))
    }

    func testSuggestAreasFallsBackToPackageTargets() throws {
        let root = try tempDir("pkg")
        try touch(root, "Sources/HatchCore/A.swift")
        try touch(root, "Sources/HatchSync/B.swift")
        try touch(root, "Tests/HatchCoreTests/T.swift")
        let areas = ProjectBootstrap.suggestAreas(repoRoot: root)
        XCTAssertEqual(areas.map(\.name), ["Hatch Core", "Hatch Sync"])
        XCTAssertEqual(areas.map(\.specPrefix), ["HC", "HS"])
    }

    func testSuggestAreasOnEmptyAndMissingRoots() throws {
        XCTAssertEqual(ProjectBootstrap.suggestAreas(repoRoot: try tempDir("empty")), [])
        XCTAssertEqual(ProjectBootstrap.suggestAreas(repoRoot: URL(fileURLWithPath: "/nonexistent/repo")), [])
    }

    func testPrefixesStayUnique() {
        var used = Set<String>()
        let a = ProjectBootstrap.uniquePrefix(["Object", "Browser"], used: &used)
        let b = ProjectBootstrap.uniquePrefix(["Order", "Book"], used: &used)
        let c = ProjectBootstrap.uniquePrefix(["Editor"], used: &used)
        let d = ProjectBootstrap.uniquePrefix(["Editor"], used: &used)
        XCTAssertEqual([a, b, c, d], ["OB", "OB2", "EDT", "EDT2"])
        XCTAssertEqual(ProjectBootstrap.uniquePrefix(["Ab"], used: &used), "AB")
    }

    func testSplitWords() {
        XCTAssertEqual(ProjectBootstrap.splitWords("ActivityMonitor"), ["Activity", "Monitor"])
        XCTAssertEqual(ProjectBootstrap.splitWords("SQLServer"), ["SQL", "Server"])
        XCTAssertEqual(ProjectBootstrap.splitWords("data_migration"), ["Data", "Migration"])
        XCTAssertEqual(ProjectBootstrap.splitWords("About"), ["About"])
        XCTAssertEqual(ProjectBootstrap.splitWords(""), [])
    }

    func testSuggestAreasOnTheRealEchoTree() throws {
        try requireEcho(Paths.echoRepo.appendingPathComponent("Echo/Sources/Features"))
        let areas = ProjectBootstrap.suggestAreas(repoRoot: Paths.echoRepo)
        XCTAssertEqual(areas.count, 25, "the tree has 25 feature folders")
        XCTAssertTrue(areas.allSatisfy { $0.paths.count == 1 && $0.paths[0].hasPrefix("Echo/Sources/Features/") && $0.paths[0].hasSuffix("/**") })
        XCTAssertEqual(Set(areas.compactMap(\.specPrefix)).count, areas.count)
        let names = areas.map(\.name)
        for expected in ["Activity Monitor", "App Host", "Object Browser", "Query Workspace", "Schema Diagram", "Command Palette"] {
            XCTAssertTrue(names.contains(expected), expected)
        }
        let config = ProjectConfig(name: "Echo", ticketsRepo: "t/t", areas: areas)
        XCTAssertEqual(config.area(containing: "Echo/Sources/Features/QueryWorkspace/Views/Query/SQLTextView/X.swift")?.name, "Query Workspace")
    }
}
