import SwiftUI

struct MySQLActivitySectionPicker: View {
    typealias Section = MySQLActivityMonitorView.MySQLActivitySection

    @Binding var selection: Section

    var body: some View {
        TabSectionPicker(
            "Activity Monitor Section",
            selection: $selection,
            itemCount: Section.allCases.count
        ) {
            ForEach(Section.allCases, id: \.self) { section in
                Text(section.rawValue).tag(section)
            }
        }
    }
}
