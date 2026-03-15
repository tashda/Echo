import Foundation

/// Preprocesses SQL text containing SQLCMD directives before execution.
///
/// Supports `:setvar`, `$(var)` substitution, `:r` file inclusion,
/// `GO [count]` batch splitting, and reports unsupported directives as warnings.
nonisolated struct SQLCMDPreprocessor {

    struct ProcessedResult: Sendable {
        let batches: [String]
        let warnings: [String]
    }

    // MARK: - Public API

    static func process(
        _ sql: String,
        variables: [String: String] = [:],
        baseDirectory: URL? = nil
    ) -> ProcessedResult {
        var context = ProcessingContext(
            variables: variables,
            baseDirectory: baseDirectory,
            inclusionDepth: 0
        )
        let lines = sql.components(separatedBy: .newlines)
        processLines(lines, into: &context)
        finalizeBatch(in: &context)
        return ProcessedResult(
            batches: context.batches,
            warnings: context.warnings
        )
    }

    // MARK: - Processing Context

    private struct ProcessingContext {
        var variables: [String: String]
        let baseDirectory: URL?
        let inclusionDepth: Int
        var currentBatch: [String] = []
        var batches: [String] = []
        var warnings: [String] = []
        var stopped: Bool = false
    }

    private static let maxInclusionDepth = 8

    // MARK: - Line Processing

    private static func processLines(_ lines: [String], into context: inout ProcessingContext) {
        for line in lines {
            guard !context.stopped else { break }
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if let directive = parseDirective(trimmed) {
                handleDirective(directive, rawLine: line, into: &context)
            } else if isGOLine(trimmed) {
                handleGO(trimmed, into: &context)
            } else {
                let substituted = substituteVariables(line, variables: context.variables)
                context.currentBatch.append(substituted)
            }
        }
    }

    // MARK: - Directive Parsing

    private enum Directive {
        case setvar(name: String, value: String)
        case include(path: String)
        case connect(args: String)
        case shellExec(command: String)
        case quit
        case exit(expression: String?)
        case errorRedirect(target: String)
        case outputRedirect(target: String)
        case unknown(name: String)
    }

    private static func parseDirective(_ trimmed: String) -> Directive? {
        guard trimmed.hasPrefix(":") else { return nil }
        let afterColon = String(trimmed.dropFirst())
        let parts = splitDirectiveArguments(afterColon)
        guard let command = parts.first?.lowercased() else { return nil }

        switch command {
        case "setvar":
            return parseSetvar(parts: parts)
        case "r":
            let path = parts.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespaces)
            return path.isEmpty ? .unknown(name: "r") : .include(path: stripQuotes(path))
        case "connect":
            let args = parts.dropFirst().joined(separator: " ")
            return .connect(args: args)
        case "!!", "shell":
            let cmd = parts.dropFirst().joined(separator: " ")
            return .shellExec(command: cmd)
        case "quit":
            return .quit
        case "exit":
            let expr = parts.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespaces)
            return .exit(expression: expr.isEmpty ? nil : expr)
        case "error":
            let target = parts.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespaces)
            return .errorRedirect(target: target)
        case "out":
            let target = parts.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespaces)
            return .outputRedirect(target: target)
        default:
            return .unknown(name: command)
        }
    }

    private static func parseSetvar(parts: [String]) -> Directive {
        guard parts.count >= 2 else { return .unknown(name: "setvar") }
        let name = parts[1]
        let value: String
        if parts.count >= 3 {
            let raw = parts.dropFirst(2).joined(separator: " ")
            value = stripQuotes(raw)
        } else {
            value = ""
        }
        return .setvar(name: name, value: value)
    }

    private static func splitDirectiveArguments(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var quoteChar: Character = "\""

        for char in text {
            if inQuotes {
                if char == quoteChar {
                    inQuotes = false
                    current.append(char)
                } else {
                    current.append(char)
                }
            } else if char == "\"" || char == "'" {
                inQuotes = true
                quoteChar = char
                current.append(char)
            } else if char == " " || char == "\t" {
                if !current.isEmpty {
                    result.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    private static func stripQuotes(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }

    // MARK: - Directive Handling

    private static func handleDirective(
        _ directive: Directive,
        rawLine: String,
        into context: inout ProcessingContext
    ) {
        switch directive {
        case .setvar(let name, let value):
            context.variables[name] = value

        case .include(let path):
            handleInclude(path: path, into: &context)

        case .connect(let args):
            context.warnings.append("Unsupported directive: :connect \(args) — multi-server execution is not supported")

        case .shellExec(let command):
            context.warnings.append("Unsupported directive: :!! \(command) — OS shell execution is not supported")

        case .quit:
            finalizeBatch(in: &context)
            context.stopped = true
            context.warnings.append("Encountered :quit — execution stopped at this point")

        case .exit(let expression):
            finalizeBatch(in: &context)
            context.stopped = true
            let detail = expression.map { " (\($0))" } ?? ""
            context.warnings.append("Encountered :exit\(detail) — execution stopped at this point")

        case .errorRedirect(let target):
            context.warnings.append("Unsupported directive: :error \(target) — error redirection is not supported")

        case .outputRedirect(let target):
            context.warnings.append("Unsupported directive: :out \(target) — output redirection is not supported")

        case .unknown(let name):
            context.warnings.append("Unknown SQLCMD directive: :\(name)")
        }
    }

    // MARK: - GO Handling

    private static func isGOLine(_ trimmed: String) -> Bool {
        trimmed.wholeMatch(of: /(?i)^GO(?:\s+\d+)?$/) != nil
    }

    private static func handleGO(_ trimmed: String, into context: inout ProcessingContext) {
        let repeatCount = parseGOCount(trimmed)
        let batchText = context.currentBatch.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        context.currentBatch.removeAll()

        guard !batchText.isEmpty else { return }

        let count = max(1, repeatCount)
        for _ in 0..<count {
            context.batches.append(batchText)
        }
    }

    private static func parseGOCount(_ trimmed: String) -> Int {
        if let match = trimmed.wholeMatch(of: /(?i)^GO\s+(\d+)$/) {
            return Int(match.1) ?? 1
        }
        return 1
    }

    // MARK: - Variable Substitution

    static func substituteVariables(_ text: String, variables: [String: String]) -> String {
        guard !variables.isEmpty, text.contains("$(") else { return text }
        var result = text
        // Iterate replacements until stable (handles nested substitution)
        var iterations = 0
        while iterations < 10 {
            var changed = false
            for (name, value) in variables {
                let token = "$(\(name))"
                if result.contains(token) {
                    result = result.replacingOccurrences(of: token, with: value)
                    changed = true
                }
            }
            if !changed { break }
            iterations += 1
        }
        return result
    }

    // MARK: - File Inclusion

    private static func handleInclude(path: String, into context: inout ProcessingContext) {
        guard context.inclusionDepth < maxInclusionDepth else {
            context.warnings.append("Maximum :r inclusion depth (\(maxInclusionDepth)) exceeded for: \(path)")
            return
        }

        let resolvedURL: URL
        if path.hasPrefix("/") || path.hasPrefix("~") {
            let expanded = NSString(string: path).expandingTildeInPath
            resolvedURL = URL(fileURLWithPath: expanded)
        } else if let base = context.baseDirectory {
            resolvedURL = base.appendingPathComponent(path)
        } else {
            context.warnings.append("Cannot resolve relative path for :r \(path) — no base directory")
            return
        }

        guard FileManager.default.fileExists(atPath: resolvedURL.path) else {
            context.warnings.append("File not found for :r directive: \(resolvedURL.path)")
            return
        }

        do {
            let contents = try String(contentsOf: resolvedURL, encoding: .utf8)
            var nestedContext = ProcessingContext(
                variables: context.variables,
                baseDirectory: resolvedURL.deletingLastPathComponent(),
                inclusionDepth: context.inclusionDepth + 1
            )
            let nestedLines = contents.components(separatedBy: .newlines)
            processLines(nestedLines, into: &nestedContext)
            finalizeBatch(in: &nestedContext)

            // Merge nested state back into parent
            context.variables = nestedContext.variables
            context.warnings.append(contentsOf: nestedContext.warnings)

            // Flush any prior content in the current batch before inserting included batches
            if !nestedContext.batches.isEmpty {
                let priorContent = context.currentBatch.joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                context.currentBatch.removeAll()
                if !priorContent.isEmpty {
                    context.batches.append(priorContent)
                }
                context.batches.append(contentsOf: nestedContext.batches)
            }

            if nestedContext.stopped { context.stopped = true }
        } catch {
            context.warnings.append("Failed to read file for :r directive: \(resolvedURL.path) — \(error.localizedDescription)")
        }
    }

    // MARK: - Batch Finalization

    private static func finalizeBatch(in context: inout ProcessingContext) {
        let batchText = context.currentBatch.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        context.currentBatch.removeAll()
        guard !batchText.isEmpty else { return }
        context.batches.append(batchText)
    }
}
