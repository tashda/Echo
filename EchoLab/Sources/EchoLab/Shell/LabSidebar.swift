import SwiftUI

struct LabSidebar: View {
    @Environment(LabStore.self) private var store
    @Binding var selection: String?

    var body: some View {
        List(selection: $selection) {
            ForEach(LabSection.allCases) { section in
                let pages = LabRegistry.pages.filter { store.section(of: $0) == section }
                if !pages.isEmpty {
                    Section(section.rawValue) {
                        ForEach(groups(of: pages, in: section), id: \.self) { group in
                            let inGroup = pages.filter { store.group(of: $0) == group }
                            if section == .ongoing {
                                DisclosureGroup(group + " · \(inGroup.count)") { rows(inGroup) }
                            } else {
                                DisclosureGroup(group) { rows(inGroup) }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func rows(_ pages: [LabPage]) -> some View {
        ForEach(pages) { page in
            Label(page.title, systemImage: page.symbol).tag(page.id)
        }
    }

    /// Ongoing groups follow the status order; the others keep registration order.
    private func groups(of pages: [LabPage], in section: LabSection) -> [String] {
        var seen: [String] = []
        for page in pages where !seen.contains(store.group(of: page)) { seen.append(store.group(of: page)) }
        guard section == .ongoing else { return seen }
        let order = LabStatus.allCases.map(\.rawValue)
        return seen.sorted { (order.firstIndex(of: $0) ?? 99) < (order.firstIndex(of: $1) ?? 99) }
    }
}
