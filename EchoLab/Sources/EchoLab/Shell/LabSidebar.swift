import SwiftUI

/// The sidebar is short and fixed: Inbox, Rounds, Spec (the whole design documentation, on one
/// page), then the Test pages. Areas are inside Spec; a round opens inside its area.
struct LabSidebar: View {
    @Environment(LabStore.self) private var store
    @Binding var selection: LabDestination?

    var body: some View {
        List(selection: $selection) {
            Label("Inbox", systemImage: "tray")
                .badge(store.attentionCount)
                .tag(LabDestination.inbox)
            Label("Rounds", systemImage: "clock.arrow.circlepath")
                .tag(LabDestination.rounds)
            Label("Spec", systemImage: "list.bullet.rectangle")
                .tag(LabDestination.spec)
            pageSection("Test", .test)
            pageSection("Reference", .reference)
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func pageSection(_ title: String, _ section: LabSection) -> some View {
        let pages = LabRegistry.pages(in: section)
        if !pages.isEmpty {
            Section(title) {
                ForEach(pages) { page in
                    Label(page.title, systemImage: page.symbol).tag(LabDestination.page(page.id))
                }
            }
        }
    }
}
