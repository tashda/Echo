import SwiftUI

/// The sidebar stays short and fixed: the inbox, one row per area, then Test and Reference.
/// Rounds live inside their area, not here.
struct LabSidebar: View {
    @Environment(LabStore.self) private var store
    @Binding var selection: LabDestination?
    @State private var open: Set<String> = ["Window", "Content"]

    /// A group opens when you go into one of its areas; you can still open or close it yourself.
    private func expansion(_ title: String) -> Binding<Bool> {
        Binding(get: { open.contains(title) }, set: { if $0 { open.insert(title) } else { open.remove(title) } })
    }

    private func rows(_ ids: [String]) -> some View {
        ForEach(ids, id: \.self) { id in
            if let area = LabAreas.area(id: id) {
                Label(area.title, systemImage: area.symbol).tag(LabDestination.area(area.id))
            }
        }
    }

    var body: some View {
        List(selection: $selection) {
            Label("Inbox", systemImage: "tray")
                .badge(store.attentionCount)
                .tag(LabDestination.inbox)
            Label("Rounds", systemImage: "clock.arrow.circlepath")
                .tag(LabDestination.rounds)
            ForEach(Array(LabAreas.groups.enumerated()), id: \.offset) { _, group in
                if let title = group.title {
                    Section(title, isExpanded: expansion(title)) { rows(group.ids) }
                } else {
                    Section("Echo, as built") { rows(group.ids) }
                }
            }
            pageSection("Test", .test)
            pageSection("Reference", .reference)
        }
        .listStyle(.sidebar)
        .onChange(of: selection) { _, new in
            if case .area(let id) = new, let title = LabAreas.groupTitle(ofArea: id) { open.insert(title) }
        }
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
