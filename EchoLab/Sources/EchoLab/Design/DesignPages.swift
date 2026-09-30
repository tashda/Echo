import SwiftUI

/// Playgrounds for judging how a design looks and behaves.
enum DesignPages {
    static let all: [LabPage] = [
        LabPage(
            id: "design.tokens",
            section: .design,
            group: "Foundations",
            title: "Design tokens",
            symbol: "paintpalette",
            summary: "The shared EchoDesignSystem tokens, rendered by Echo Lab itself."
        ) { TokensSamplePage() }
    ]
}
