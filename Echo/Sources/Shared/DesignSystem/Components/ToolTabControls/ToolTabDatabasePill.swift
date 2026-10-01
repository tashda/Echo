import SwiftUI

/// The database a tool works on, as a picker pill on its header line (round 37.3, PK1). It was a
/// menu in the window toolbar for Maintenance; tool actions live in the tab (round 45).
struct ToolTabDatabasePill: View {
    let databases: [String]
    let selected: String?
    let onSelect: (String) -> Void

    @State private var choice = ""

    var body: some View {
        if !databases.isEmpty {
            ToolTabPickerPill(title: "Database", systemImage: "cylinder", selection: $choice, options: databases, label: { $0 })
                .onChange(of: selected, initial: true) { _, current in
                    choice = current ?? databases[0]
                }
                .onChange(of: choice) { _, picked in
                    if picked != (selected ?? databases[0]) { onSelect(picked) }
                }
        }
    }
}
