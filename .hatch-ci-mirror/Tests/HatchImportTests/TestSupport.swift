import XCTest
import HatchCore
@testable import HatchImport

enum Paths {
    static let echoRepo = URL(fileURLWithPath: "/home/user/Echo")
    static let labState = echoRepo.appendingPathComponent("EchoLab/State/lab-state.json")
    static let labSources = echoRepo.appendingPathComponent("EchoLab/Sources/EchoLab")
    static let areas = labSources.appendingPathComponent("Areas")
    static let hatchRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")
}

func requireEcho(_ url: URL = Paths.labState) throws {
    try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "The Echo checkout is not at \(Paths.echoRepo.path)")
}

func makeStore() throws -> (HatchStore, Project) {
    let store = try HatchStore.inMemory()
    let project = try store.upsertProject(key: "echo", name: "Echo", config: ProjectConfig(name: "Echo", ticketsRepo: "tashda/hatch-tickets"))
    return (store, project)
}

func tempDir(_ name: String = "hatch-import") throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func touch(_ root: URL, _ path: String, _ text: String = "// x\n") throws {
    let url = root.appendingPathComponent(path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try text.write(to: url, atomically: true, encoding: .utf8)
}

func iso(_ s: String) -> Date { ISO8601DateFormatter().date(from: s)! }
