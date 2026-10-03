import Foundation

/// One finding of the quality gate (decision H19). Written for the agent that has to fix it, never shown to the owner.
public struct GateIssue: Codable, Equatable, Sendable {
    public enum Severity: String, Codable, Sendable { case error, warning }
    public var severity: Severity
    /// Stable machine-readable code, such as `echo-today.first`. Tests and tooling match on this, not on the words.
    public var code: String
    public var message: String
    /// What to change, in one sentence.
    public var fix: String

    public init(severity: Severity, code: String, message: String, fix: String) {
        self.severity = severity; self.code = code; self.message = message; self.fix = fix
    }

    public static func error(_ code: String, _ message: String, _ fix: String) -> GateIssue {
        GateIssue(severity: .error, code: code, message: message, fix: fix)
    }

    public static func warning(_ code: String, _ message: String, _ fix: String) -> GateIssue {
        GateIssue(severity: .warning, code: code, message: message, fix: fix)
    }

    public var isError: Bool { severity == .error }
}

public extension Array where Element == GateIssue {
    var errors: [GateIssue] { filter(\.isError) }
    var warnings: [GateIssue] { filter { !$0.isError } }
    var hasErrors: Bool { contains(where: \.isError) }

    /// What `hatch offer` prints back to the agent: one line per finding, the fix indented below it.
    var report: String {
        if isEmpty { return "The quality gate found nothing to fix." }
        return map { "\($0.severity == .error ? "ERROR" : "warning") [\($0.code)] \($0.message)\n    Fix: \($0.fix)" }.joined(separator: "\n")
    }
}
