import Foundation

enum SQLFormatterError: LocalizedError {
    case binaryNotFound
    case formattingFailed(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "sqruff formatter was not found. Install it with 'cargo install sqruff' or place the binary inside the app bundle."
        case .formattingFailed(let message):
            return "SQL formatting failed: \(message)"
        }
    }
}

final class SQLFormatterService: Sendable {
    static let shared = SQLFormatterService()

    enum Dialect: String {
        case postgres
        case mysql
        case sqlite
        case duckdb

        var sqruffConfigValue: String {
            switch self {
            case .postgres:
                return "postgres"
            case .sqlite:
                return "sqlite"
            case .duckdb:
                return "duckdb"
            case .mysql:
                // Sqruff does not yet expose a MySQL dialect; fall back to ANSI.
                return "ansi"
            }
        }
    }

    private let queue = DispatchQueue(label: "dk.tippr.echo.sqlformatter", qos: .userInitiated)

    private init() {}

    func format(sql: String, dialect: Dialect = .postgres) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let formatted = try self.runFormatter(sql: sql, dialect: dialect)
                    continuation.resume(returning: formatted)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private

    private func runFormatter(sql: String, dialect: Dialect) throws -> String {
        guard let executable = locateBinary() else {
            throw SQLFormatterError.binaryNotFound
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let tempFile = tempDir.appendingPathComponent("query.sql")
        let configFile = tempDir.appendingPathComponent(".sqruff")

        // Sqruff expects files to end with a newline for LT12; append one to avoid false positives.
        let newlineTerminatedSQL = sql.hasSuffix("\n") ? sql : sql + "\n"
        try newlineTerminatedSQL.write(to: tempFile, atomically: true, encoding: .utf8)

        let configTemplate = loadConfigTemplate()
        let configContents = applyDialect(dialect, to: configTemplate)
        try configContents.write(to: configFile, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = executable
        process.arguments = ["fix", "--force", tempFile.path]
        process.currentDirectoryURL = tempDir

        let errorPipe = Pipe()
        let outputPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = outputPipe

        do {
            try process.run()
        } catch {
            try? FileManager.default.removeItem(at: tempDir)
            throw error
        }

        process.waitUntilExit()

        let stderrOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrMessage = String(data: stderrOutput, encoding: .utf8) ?? ""

        defer { try? FileManager.default.removeItem(at: tempDir) }

        guard process.terminationStatus == 0 else {
            throw SQLFormatterError.formattingFailed(stderrMessage.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        _ = outputPipe.fileHandleForReading.readDataToEndOfFile()

        guard let formatted = try? String(contentsOf: tempFile, encoding: .utf8) else {
            return sql
        }

        return formatted
    }

    private func locateBinary() -> URL? {
        if let bundled = Bundle.main.url(forResource: "sqruff", withExtension: nil) {
            return bundled
        }

        if let envPath = ProcessInfo.processInfo.environment["SQRUFF_PATH"], !envPath.isEmpty {
            return URL(fileURLWithPath: envPath)
        }

        if let whichURL = try? runWhich("sqruff") {
            return whichURL
        }

        return nil
    }

    private func loadConfigTemplate() -> String {
        if let bundled = Bundle.main.url(forResource: ".sqruff", withExtension: nil),
           let contents = try? String(contentsOf: bundled, encoding: .utf8) {
            return contents
        }

        let fallbackPath = FileManager.default.currentDirectoryPath + "/BuildTools/sqruff/.sqruff"
        if let contents = try? String(contentsOfFile: fallbackPath, encoding: .utf8) {
            return contents
        }

        return "[sqruff]\n"
    }

    private func applyDialect(_ dialect: Dialect, to template: String) -> String {
        let lines = template.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        var output: [String] = []
        output.reserveCapacity(lines.count + 2)

        var replaced = false
        var insideRootSection = false

        for rawLine in lines {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("[") && trimmed.lowercased() == "[sqruff]" {
                insideRootSection = true
                output.append(line)
                continue
            } else if trimmed.hasPrefix("[") {
                insideRootSection = false
            }

            if insideRootSection && trimmed.lowercased().hasPrefix("dialect") {
                output.append("dialect = \(dialect.sqruffConfigValue)")
                replaced = true
            } else {
                output.append(line)
            }
        }

        if !replaced {
            if let index = output.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "[sqruff]" }) {
                output.insert("dialect = \(dialect.sqruffConfigValue)", at: index + 1)
            } else {
                output.insert("[sqruff]", at: 0)
                output.insert("dialect = \(dialect.sqruffConfigValue)", at: 1)
            }
        }

        if output.last.map({ !$0.isEmpty }) ?? false {
            output.append("")
        }

        return output.joined(separator: "\n")
    }

    private func runWhich(_ name: String) throws -> URL? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]

        let output = Pipe()
        process.standardOutput = output

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !path.isEmpty
        else { return nil }

        return URL(fileURLWithPath: path)
    }
}
