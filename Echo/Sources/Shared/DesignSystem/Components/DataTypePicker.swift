import SwiftUI

/// Database-type-aware data type picker. Automatically delegates to
/// PostgresDataTypePicker or MSSQLDataTypePicker based on the database type.
///
/// Set `compact: true` for use inside table cells — renders as borderless
/// text instead of a popup button, while keeping full parameter support.
struct DataTypePicker: View {
    @Binding var selection: String
    let databaseType: DatabaseType
    var prompt: String = "Select a data type"
    var compact: Bool = false

    var body: some View {
        switch databaseType {
        case .postgresql:
            PostgresDataTypePicker(selection: $selection, prompt: prompt, compact: compact)
        case .microsoftSQL:
            MSSQLDataTypePicker(selection: $selection, prompt: prompt, compact: compact)
        case .mysql:
            MySQLDataTypePicker(selection: $selection, prompt: prompt, compact: compact)
        case .sqlite:
            TextField("", text: $selection, prompt: Text(prompt))
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
        }
    }
}
