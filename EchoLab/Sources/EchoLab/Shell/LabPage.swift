import SwiftUI

/// One page in the lab. Pages are plain SwiftUI views with sample data and no app state.
@MainActor struct LabPage: @MainActor Identifiable {
    let id: String
    let section: LabSection
    /// Sidebar group inside the section, for example "Tabs" or "Explorer tree".
    let group: String
    let title: String
    let symbol: String
    /// Ongoing pages carry their stage; other sections leave it nil.
    let status: LabStatus?
    let summary: String
    /// True when the page draws its own header (round pages use `LabRoundInfoBox`).
    var ownsHeader = false
    /// Round pages describe how they are decided; it is shown in the right-hand panel.
    var decision: (@MainActor () -> RoundDecision)?
    /// The round, for pages written as a `RoundSpec` (conformance captures draw its exhibits).
    var roundSpec: RoundSpec?
    let content: () -> AnyView

    init<Content: View>(
        id: String,
        section: LabSection,
        group: String,
        title: String,
        symbol: String,
        status: LabStatus? = nil,
        summary: String,
        ownsHeader: Bool = false,
        decision: (@MainActor () -> RoundDecision)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.id = id
        self.section = section
        self.group = group
        self.title = title
        self.symbol = symbol
        self.status = status
        self.summary = summary
        self.ownsHeader = ownsHeader
        self.decision = decision
        self.content = { AnyView(content()) }
    }
}
