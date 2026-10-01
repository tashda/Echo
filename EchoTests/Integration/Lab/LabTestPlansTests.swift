import Foundation
import Testing

/// Every suite that uses lab servers is in the LabTests plan (CI's lab job runs only that plan),
/// and every SQL Server one is in SQLServerVersions (the nightly version matrix). Reads the
/// sources and plans next to this file, so a new lab suite cannot be left out by accident.
@Suite("Lab test plans")
struct LabTestPlansTests {
    private static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    /// What marks a suite as a lab suite: the SQL Server base classes, a `.server(...)` suite trait,
    /// or a shared or started lab server.
    private static let labMarkers = [
        #": MSSQL(Dedicated)?LabTestCase \{"#,
        #"@Suite\([^\n]*\.server\("#,
        #"\.server\(LabRecipes\."#,
        #"LabSharedServers\.shared\.server\("#,
        #"try await labServer\("#,
        #"ServerLabCLI\.up\("#,
    ]

    /// Lab suites by name, with the file each is in.
    static func labSuites() throws -> [String: String] {
        let testsFolder = repository.appending(path: "EchoTests")
        let files = FileManager.default.enumerator(at: testsFolder, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
        var suites: [String: String] = [:]
        for file in files where !file.path.contains("/Integration/Support/") && !file.path.contains("/Integration/Lab/LabSharedServers") {
            let source = try String(contentsOf: file, encoding: .utf8)
            guard labMarkers.contains(where: { source.range(of: $0, options: .regularExpression) != nil }) else { continue }
            let declarations = try Regex(#"(?m)^(?:@MainActor\s+)?(?:final\s+)?(?:class|struct)\s+(\w+Tests)\b"#)
            for match in source.matches(of: declarations) {
                if let name = match.output[1].substring { suites[String(name)] = file.lastPathComponent }
            }
        }
        return suites
    }

    static func selectedTests(of plan: String) throws -> Set<String> {
        let data = try Data(contentsOf: repository.appending(path: "\(plan).xctestplan"))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let targets = try #require(json["testTargets"] as? [[String: Any]])
        return Set(targets.flatMap { $0["selectedTests"] as? [String] ?? [] })
    }

    @Test func everyLabSuiteIsInTheLabTestsPlan() throws {
        let suites = try Self.labSuites()
        #expect(suites.count >= 50, "found only \(suites.count) lab suites; the markers no longer match")
        let missing = Set(suites.keys).subtracting(try Self.selectedTests(of: "LabTests"))
        #expect(missing.isEmpty, "add to LabTests.xctestplan: \(missing.sorted().map { "\($0) (\(suites[$0] ?? ""))" })")
    }

    @Test func everySQLServerLabSuiteIsInSQLServerVersions() throws {
        let sqlServer = try Self.labSuites().keys.filter { $0.hasPrefix("MSSQL") }
        let missing = Set(sqlServer).subtracting(try Self.selectedTests(of: "SQLServerVersions"))
        #expect(missing.isEmpty, "add to SQLServerVersions.xctestplan: \(missing.sorted())")
    }
}
