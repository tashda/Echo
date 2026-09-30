import SwiftUI

/// The sidebar stays short and fixed: the inbox, one row per area, then Test and Reference.
/// Rounds live inside their area, not here.
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
            Section("Echo, as built") {
                ForEach(LabAreas.all) { area in
                    Label(area.title, systemImage: area.symbol)
                        .tag(LabDestination.area(area.id))
                }
            }
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
