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
    let content: () -> AnyView

    init<Content: View>(
        id: String,
        section: LabSection,
        group: String,
        title: String,
        symbol: String,
        status: LabStatus? = nil,
        summary: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.id = id
        self.section = section
        self.group = group
        self.title = title
        self.symbol = symbol
        self.status = status
        self.summary = summary
        self.content = { AnyView(content()) }
    }
}
