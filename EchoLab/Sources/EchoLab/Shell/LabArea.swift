import SwiftUI

/// One part of Echo (Explorer tree, Tabs, Foundations, …). The sidebar shows only areas; an
/// area page has an Overview (its As built page) and its Rounds (the history that shaped it).
@MainActor
struct LabArea: @MainActor Identifiable {
    let id: String
    let title: String
    let symbol: String
    let summary: String
    let asBuilt: AsBuiltPage

    /// The `LabPage` that carries this area's status and feedback, so an As built page can be
    /// reopened with "this doesn't match the app".
    var asBuiltPageID: String { "asbuilt.\(id)" }

    var asBuiltPage: LabPage {
        LabPage(
            id: asBuiltPageID,
            section: .areas,
            group: title,
            title: "\(title) · As built",
            symbol: symbol,
            status: .decided,
            summary: summary
        ) { AsBuiltView(area: self, page: asBuilt) }
    }
}
