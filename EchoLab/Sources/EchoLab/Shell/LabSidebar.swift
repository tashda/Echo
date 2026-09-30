import SwiftUI

struct LabSidebar: View {
    @Binding var selection: String?

    var body: some View {
        List(selection: $selection) {
            ForEach(LabSection.allCases) { section in
                Section(section.rawValue) {
                    ForEach(groups(in: section), id: \.self) { group in
                        ForEach(LabRegistry.pages(in: section).filter { $0.group == group }) { page in
                            Label(page.title, systemImage: page.symbol)
                                .tag(page.id)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    /// Groups in registration order, without repeats.
    private func groups(in section: LabSection) -> [String] {
        var seen: [String] = []
        for page in LabRegistry.pages(in: section) where !seen.contains(page.group) {
            seen.append(page.group)
        }
        return seen
    }
}
