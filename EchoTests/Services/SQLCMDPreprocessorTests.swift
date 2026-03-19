import Testing
import Foundation
@testable import Echo

@Suite("SQLCMDPreprocessor")
struct SQLCMDPreprocessorTests {

    // MARK: - Variable Substitution

    @Test func substitutesSingleVariable() {
        let result = SQLCMDPreprocessor.process(
            "SELECT * FROM $(TableName)",
            variables: ["TableName": "Users"]
        )
        #expect(result.batches == ["SELECT * FROM Users"])
        #expect(result.warnings.isEmpty)
    }

    @Test func substitutesMultipleVariables() {
        let sql = "SELECT $(Col1), $(Col2) FROM $(Table)"
        let vars = ["Col1": "id", "Col2": "name", "Table": "dbo.Users"]
        let result = SQLCMDPreprocessor.process(sql, variables: vars)
        #expect(result.batches == ["SELECT id, name FROM dbo.Users"])
    }

    @Test func leavesUnknownVariablesUnchanged() {
        let result = SQLCMDPreprocessor.process(
            "SELECT $(Unknown) FROM t",
            variables: [:]
        )
        #expect(result.batches == ["SELECT $(Unknown) FROM t"])
    }

    // MARK: - :setvar

    @Test func setvarDefinesVariable() {
        let sql = """
        :setvar DatabaseName MyDB
        USE $(DatabaseName)
        """
        let result = SQLCMDPreprocessor.process(sql)
        #expect(result.batches == ["USE MyDB"])
    }

    @Test func setvarOverridesExistingVariable() {
        let sql = """
        :setvar Env Dev
        SELECT '$(Env)'
        GO
        :setvar Env Prod
        SELECT '$(Env)'
        """
        let result = SQLCMDPreprocessor.process(sql)
        #expect(result.batches.count == 2)
        #expect(result.batches[0] == "SELECT 'Dev'")
        #expect(result.batches[1] == "SELECT 'Prod'")
    }

    @Test func setvarWithQuotedValue() {
        let sql = """
        :setvar Path "C:\\Scripts\\data.sql"
        SELECT '$(Path)'
        """
        let result = SQLCMDPreprocessor.process(sql)
        #expect(result.batches == ["SELECT 'C:\\Scripts\\data.sql'"])
    }

    @Test func setvarWithEmptyValue() {
        let sql = """
        :setvar EmptyVar
        SELECT '$(EmptyVar)' AS result
        """
        let result = SQLCMDPreprocessor.process(sql)
        #expect(result.batches == ["SELECT '' AS result"])
    }

    // MARK: - GO Batch Splitting

    @Test func splitsOnGO() {
        let sql = """
        SELECT 1
        GO
        SELECT 2
        GO
        SELECT 3
        """
        let result = SQLCMDPreprocessor.process(sql)
        #expect(result.batches.count == 3)
        #expect(result.batches[0] == "SELECT 1")
        #expect(result.batches[1] == "SELECT 2")
        #expect(result.batches[2] == "SELECT 3")
    }

    @Test func goCaseInsensitive() {
        let sql = """
        SELECT 1
        go
        SELECT 2
        Go
        SELECT 3
        """
        let result = SQLCMDPreprocessor.process(sql)
        #expect(result.batches.count == 3)
    }

    @Test func goWithRepeatCount() {
        let sql = """
        INSERT INTO log DEFAULT VALUES
        GO 3
        """
        let result = SQLCMDPreprocessor.process(sql)
        #expect(result.batches.count == 3)
        #expect(result.batches.allSatisfy { $0 == "INSERT INTO log DEFAULT VALUES" })
    }

    @Test func goWithCountOne() {
        let sql = """
        SELECT 1
        GO 1
        """
        let result = SQLCMDPreprocessor.process(sql)
        #expect(result.batches.count == 1)
    }

    @Test func emptyBatchesRemoved() {
        let sql = """
        GO
        GO
        SELECT 1
        GO
        GO
        """
        let result = SQLCMDPreprocessor.process(sql)
        #expect(result.batches == ["SELECT 1"])
    }

    @Test func trailingContentWithoutGO() {
        let sql = """
        SELECT 1
        GO
        SELECT 2
        """
        let result = SQLCMDPreprocessor.process(sql)
        #expect(result.batches.count == 2)
        #expect(result.batches[1] == "SELECT 2")
    }

    // MARK: - :r File Inclusion

    @Test func includesFileContents() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let includedFile = tempDir.appendingPathComponent("setup.sql")
        try "CREATE TABLE t1 (id INT)".write(to: includedFile, atomically: true, encoding: .utf8)

        let sql = """
        :r setup.sql
        GO
        SELECT * FROM t1
        """
        let result = SQLCMDPreprocessor.process(sql, baseDirectory: tempDir)
        #expect(result.batches.count == 2)
        #expect(result.batches[0] == "CREATE TABLE t1 (id INT)")
        #expect(result.batches[1] == "SELECT * FROM t1")
        #expect(result.warnings.isEmpty)
    }

    @Test func includesAbsolutePath() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let includedFile = tempDir.appendingPathComponent("abs.sql")
        try "SELECT 42".write(to: includedFile, atomically: true, encoding: .utf8)

        let sql = ":r \(includedFile.path)"
        let result = SQLCMDPreprocessor.process(sql)
        #expect(result.batches == ["SELECT 42"])
    }

    @Test func nestedInclusion() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let innerFile = tempDir.appendingPathComponent("inner.sql")
        try "SELECT 'inner'".write(to: innerFile, atomically: true, encoding: .utf8)

        let outerFile = tempDir.appendingPathComponent("outer.sql")
        try ":r inner.sql".write(to: outerFile, atomically: true, encoding: .utf8)

        let sql = ":r outer.sql"
        let result = SQLCMDPreprocessor.process(sql, baseDirectory: tempDir)
        #expect(result.batches == ["SELECT 'inner'"])
    }

    @Test func missingFileWarning() {
        let result = SQLCMDPreprocessor.process(
            ":r /nonexistent/file.sql"
        )
        #expect(result.batches.isEmpty)
        #expect(result.warnings.count == 1)
        #expect(result.warnings[0].contains("File not found"))
    }

    @Test func relativePathWithoutBaseDirectoryWarning() {
        let result = SQLCMDPreprocessor.process(
            ":r relative/file.sql"
        )
        #expect(result.batches.isEmpty)
        #expect(result.warnings.count == 1)
        #expect(result.warnings[0].contains("Cannot resolve relative path"))
    }

    @Test func inclusionDepthLimit() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create a self-referencing file
        let selfRef = tempDir.appendingPathComponent("loop.sql")
        try ":r loop.sql\nSELECT 1".write(to: selfRef, atomically: true, encoding: .utf8)

        let result = SQLCMDPreprocessor.process(":r loop.sql", baseDirectory: tempDir)
        #expect(result.warnings.contains { $0.contains("Maximum :r inclusion depth") })
    }

    // MARK: - Unsupported Directives

    @Test func connectWarning() {
        let result = SQLCMDPreprocessor.process(":connect server\\instance -U sa")
        #expect(result.batches.isEmpty)
        #expect(result.warnings.count == 1)
        #expect(result.warnings[0].contains(":connect"))
        #expect(result.warnings[0].contains("not supported"))
    }

    @Test func shellExecWarning() {
        let result = SQLCMDPreprocessor.process(":!! dir")
        #expect(result.batches.isEmpty)
        #expect(result.warnings.count == 1)
        #expect(result.warnings[0].contains("shell execution"))
    }

    @Test func quitStopsExecution() {
        let sql = """
        SELECT 1
        GO
        :quit
        SELECT 2
        """
        let result = SQLCMDPreprocessor.process(sql)
        #expect(result.batches == ["SELECT 1"])
        #expect(result.warnings.contains { $0.contains(":quit") })
    }

    @Test func exitStopsExecution() {
        let sql = """
        SELECT 1
        GO
        :exit
        SELECT 2
        """
        let result = SQLCMDPreprocessor.process(sql)
        #expect(result.batches == ["SELECT 1"])
        #expect(result.warnings.contains { $0.contains(":exit") })
    }

    @Test func errorRedirectWarning() {
        let result = SQLCMDPreprocessor.process(":error stderr")
        #expect(result.warnings.contains { $0.contains(":error") })
    }

    @Test func outRedirectWarning() {
        let result = SQLCMDPreprocessor.process(":out output.txt")
        #expect(result.warnings.contains { $0.contains(":out") })
    }

    @Test func unknownDirectiveWarning() {
        let result = SQLCMDPreprocessor.process(":foobar something")
        #expect(result.warnings.contains { $0.contains("Unknown SQLCMD directive") })
    }

    // MARK: - Combined Scenarios

    @Test func variablesAndBatchSplitting() {
        let sql = """
        :setvar Schema dbo
        :setvar Table Users
        SELECT * FROM $(Schema).$(Table)
        GO
        SELECT COUNT(*) FROM $(Schema).$(Table)
        """
        let result = SQLCMDPreprocessor.process(sql)
        #expect(result.batches.count == 2)
        #expect(result.batches[0] == "SELECT * FROM dbo.Users")
        #expect(result.batches[1] == "SELECT COUNT(*) FROM dbo.Users")
    }

    @Test func passedVariablesMergeWithSetvar() {
        let sql = """
        :setvar Local LocalVal
        SELECT '$(Passed)', '$(Local)'
        """
        let result = SQLCMDPreprocessor.process(sql, variables: ["Passed": "PassedVal"])
        #expect(result.batches == ["SELECT 'PassedVal', 'LocalVal'"])
    }

    @Test func emptyInput() {
        let result = SQLCMDPreprocessor.process("")
        #expect(result.batches.isEmpty)
        #expect(result.warnings.isEmpty)
    }

    @Test func plainSQLWithoutDirectives() {
        let sql = "SELECT 1 AS result"
        let result = SQLCMDPreprocessor.process(sql)
        #expect(result.batches == ["SELECT 1 AS result"])
        #expect(result.warnings.isEmpty)
    }

    @Test func multiLineStatementWithoutGO() {
        let sql = """
        SELECT
            id,
            name
        FROM users
        WHERE active = 1
        """
        let result = SQLCMDPreprocessor.process(sql)
        #expect(result.batches.count == 1)
        #expect(result.batches[0].contains("SELECT"))
        #expect(result.batches[0].contains("WHERE"))
    }

    @Test func colonInStringLiteralNotTreatedAsDirective() {
        let sql = "SELECT ':connect' AS label"
        let result = SQLCMDPreprocessor.process(sql)
        // Colon inside a SQL string is not at start of line, so not a directive
        #expect(result.batches == ["SELECT ':connect' AS label"])
        #expect(result.warnings.isEmpty)
    }
}
