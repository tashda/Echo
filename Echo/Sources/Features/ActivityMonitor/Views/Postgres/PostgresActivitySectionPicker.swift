import SwiftUI

struct PostgresActivitySectionPicker: View {
    typealias Section = PostgresActivityMonitorView.PostgresActivitySection

    @Binding var selection: Section
    let sectionAvailability: [Section: Bool]

    var body: some View {
        TabSectionPicker(
            "Activity Monitor Section",
            selection: $selection,
            itemCount: Section.allCases.count
        ) {
            ForEach(Section.allCases, id: \.self) { section in
                Text(section.rawValue)
                    .tag(section)
                    .disabled(!(sectionAvailability[section] ?? true))
            }
        }
    }
}
