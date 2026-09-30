import SwiftUI

/// One page in the lab. Pages are plain SwiftUI views with sample data and no app state.
struct LabPage: Identifiable {
    let id: String
    let section: LabSection
    /// Sidebar group inside the section, for example "Tabs" or "Explorer tree".
    let group: String
    let title: String
    let symbol: String
    let summary: String
    let content: () -> AnyView

    init<Content: View>(
        id: String,
        section: LabSection,
        group: String,
        title: String,
        symbol: String,
        summary: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.id = id
        self.section = section
        self.group = group
        self.title = title
        self.symbol = symbol
        self.summary = summary
        self.content = { AnyView(content()) }
    }
}
