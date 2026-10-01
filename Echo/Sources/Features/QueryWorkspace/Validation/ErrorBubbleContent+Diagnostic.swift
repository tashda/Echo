import Foundation

extension ErrorBubbleContent {
    /// Round 28.6: what a mistake found while typing says in its bubble.
    init(diagnostic: SQLDiagnostic) {
        switch diagnostic.kind {
        case .syntaxError:
            self.init(title: "Syntax error", message: diagnostic.message)
        case .unknownTable:
            self.init(title: "Unknown table", message: "No table named '\(diagnostic.token)'.")
        case .unknownSchema:
            self.init(title: "Unknown schema", message: "No schema named '\(diagnostic.token)'.")
        case .unknownColumn:
            self.init(title: "Unknown column", message: "No column named '\(diagnostic.token)'.")
        }
    }
}
