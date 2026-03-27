import SwiftUI

/// Database-type-aware data type picker. Automatically delegates to
/// PostgresDataTypePicker or MSSQLDataTypePicker based on the database type.
///
/// Set `compact: true` for use inside table cells — renders as plain text
/// with a borderless menu instead of a popup button.
struct DataTypePicker: View {
    @Binding var selection: String
    let databaseType: DatabaseType
    var prompt: String = "Select a data type"
    var compact: Bool = false

    var body: some View {
        if compact {
            compactMenu
        } else {
            switch databaseType {
            case .postgresql:
                PostgresDataTypePicker(selection: $selection, prompt: prompt)
            case .microsoftSQL:
                MSSQLDataTypePicker(selection: $selection, prompt: prompt)
            default:
                TextField("", text: $selection, prompt: Text(prompt))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var typeList: [(category: String, types: [String])] {
        switch databaseType {
        case .microsoftSQL: MSSQLDataTypePicker.commonTypes
        case .postgresql: PostgresDataTypePicker.commonTypes
        default: []
        }
    }

    private var compactMenu: some View {
        Menu {
            ForEach(typeList, id: \.category) { group in
                Section(group.category) {
                    ForEach(group.types, id: \.self) { type in
                        Button(type) { selection = type }
                    }
                }
            }
        } label: {
            Text(selection.isEmpty ? prompt : selection)
                .font(TypographyTokens.Table.category)
                .foregroundStyle(selection.isEmpty ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
        }
        .menuStyle(.borderlessButton)
    }
}
