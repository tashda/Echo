import SwiftUI

/// The decision library: each decision is a Swift file with its reasoning and every option
/// it considered, rendered live. Empty until the Design Lab's decided rounds are ported.
enum DecisionPages {
    static let all: [LabPage] = [
        LabPage(
            id: "decisions.overview",
            section: .decisions,
            group: "Library",
            title: "Overview",
            symbol: "books.vertical",
            summary: "What was decided, why, and exactly how it was built."
        ) {
            ContentUnavailableView(
                "No decisions yet",
                systemImage: "books.vertical",
                description: Text("Decided rounds from the Design Lab will be ported here as live code.")
            )
        }
    ]
}
