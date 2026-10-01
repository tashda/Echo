import Foundation

/// The ways Run can execute a query tab's SQL (plan K1). A plain click on Run is `.run`; the
/// chevron beside it and the Query menu offer the rest.
enum QueryRunMode: CaseIterable, Identifiable {
    /// The selection when there is one, otherwise the whole script.
    case run
    case statementAtCursor
    /// The estimated plan, without running.
    case explain
    /// Runs the query and shows the actual plan with its results.
    case explainAnalyze

    var id: Self { self }

    var title: String {
        switch self {
        case .run: "Run"
        case .statementAtCursor: "Run Statement at Cursor"
        case .explain: "Explain"
        case .explainAnalyze: "Explain Analyze"
        }
    }

    var systemImage: String {
        switch self {
        case .run: "play.fill"
        case .statementAtCursor: "text.line.first.and.arrowtriangle.forward"
        case .explain: "flowchart"
        case .explainAnalyze: "flowchart.fill"
        }
    }
}
