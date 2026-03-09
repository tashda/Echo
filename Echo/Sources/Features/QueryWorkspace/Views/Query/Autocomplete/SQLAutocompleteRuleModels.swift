import Foundation
import EchoSense

struct SQLAutocompleteRuleModels {
    struct Environment {
        var completionContext: SQLEditorCompletionContext?
    }

    struct SuppressionRequest {
        let query: SQLAutoCompletionQuery
        let selection: NSRange
        let caretLocation: Int
        let suggestions: [SQLAutoCompletionSuggestion]
        let tokenRange: NSRange
        let tokenText: String
        let clause: SQLClause
        let objectContextKeywords: Set<String>
        let columnContextKeywords: Set<String>
    }

    struct Suppression {
        var tokenRange: NSRange
        var canonicalText: String
        var hasFollowUps: Bool
    }

    struct SuppressionDiagnostics {
        var normalizedToken: String
        var components: [String]
        var matchedSuggestion: SQLAutoCompletionSuggestion?
        var matchedFromStructure: Bool
        var hasAlternativeObjects: Bool
        var hasColumnFollowUps: Bool
    }

    struct SuppressionResult {
        var suppression: Suppression
        var diagnostics: SuppressionDiagnostics
    }
}

// MARK: - Trace Support

struct SQLAutocompleteTrace: Identifiable {
    enum Topic { case suppression }

    struct Step: Identifiable {
        let id = UUID()
        let title: String
        let details: [String]
    }

    struct SuppressionSummary {
        let canonicalText: String
        let hasFollowUps: Bool
        let diagnostics: [String: String]

        init(from result: SQLAutocompleteRuleModels.SuppressionResult) {
            canonicalText = result.suppression.canonicalText
            hasFollowUps = result.suppression.hasFollowUps
            diagnostics = [
                "Normalized Token": result.diagnostics.normalizedToken,
                "Components": result.diagnostics.components.joined(separator: "."),
                "Matched Source": result.diagnostics.matchedFromStructure ? "Structure" : "Suggestion",
                "Alternative Objects": result.diagnostics.hasAlternativeObjects ? "Yes" : "No",
                "Column Follow-Ups": result.diagnostics.hasColumnFollowUps ? "Yes" : "No"
            ]
        }
    }

    enum Outcome {
        case produced(SuppressionSummary)
        case skipped(reason: String)
    }

    let id = UUID()
    let topic: Topic
    private(set) var metadata: [String: String]
    private(set) var steps: [Step] = []
    private(set) var outcome: Outcome?

    init(topic: Topic, metadata: [String: String] = [:]) {
        self.topic = topic
        self.metadata = metadata
    }

    mutating func addStep(title: String, details: [String] = []) {
        steps.append(Step(title: title, details: details))
    }

    mutating func setMetadataValue(_ value: String, forKey key: String) {
        metadata[key] = value
    }

    mutating func setOutcome(_ outcome: Outcome) {
        self.outcome = outcome
    }

    var metadataItems: [(String, String)] {
        metadata.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }

    var stepItems: [Step] { steps }
}

extension SQLAutocompleteTrace {
    static func suppression(request: SQLAutocompleteRuleModels.SuppressionRequest) -> SQLAutocompleteTrace {
        var metadata: [String: String] = [
            "Token": request.tokenText,
            "Caret": "\(request.caretLocation)",
            "Selection": "loc=\(request.selection.location) len=\(request.selection.length)"
        ]
        if request.tokenRange.location != NSNotFound {
            metadata["Token Range"] = "loc=\(request.tokenRange.location) len=\(request.tokenRange.length)"
        }
        return SQLAutocompleteTrace(topic: .suppression, metadata: metadata)
    }
}

struct SQLAutocompleteRuleTraceConfiguration {
    var isEnabled: Bool
    var onTrace: (SQLAutocompleteTrace) -> Void

    init(isEnabled: Bool = true, onTrace: @escaping (SQLAutocompleteTrace) -> Void) {
        self.isEnabled = isEnabled
        self.onTrace = onTrace
    }
}
