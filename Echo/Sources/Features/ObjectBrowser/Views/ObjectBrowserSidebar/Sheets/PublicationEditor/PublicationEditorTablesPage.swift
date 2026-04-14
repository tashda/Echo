import SwiftUI

struct PublicationEditorTablesPage: View {
    @Bindable var viewModel: PublicationEditorViewModel
    @State private var searchText = ""

    private var filteredTables: [String] {
        if searchText.isEmpty {
            return viewModel.availableTables
        }
        let query = searchText.lowercased()
        return viewModel.availableTables.filter { $0.lowercased().contains(query) }
    }

    var body: some View {
        if viewModel.allTables {
            Section {
                Text("All tables are automatically included when \"All Tables\" is enabled.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        } else {
            Section("Select Tables") {
                PropertyRow(title: "Filter") {
                    TextField("", text: $searchText, prompt: Text("Search tables"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section {
                if filteredTables.isEmpty {
                    Text("No tables available.")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                } else {
                    ForEach(filteredTables, id: \.self) { table in
                        tableRow(table)
                    }
                }
            } header: {
                HStack {
                    Text("Tables")
                    Spacer()
                    Text("\(viewModel.selectedTables.count) selected")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
    }

    private func tableRow(_ table: String) -> some View {
        let isSelected = viewModel.selectedTables.contains(table)
        return Toggle(isOn: Binding(
            get: { isSelected },
            set: { selected in
                if selected {
                    viewModel.selectedTables.insert(table)
                } else {
                    viewModel.selectedTables.remove(table)
                }
            }
        )) {
            Text(table)
                .font(TypographyTokens.formLabel)
        }
        .toggleStyle(.checkbox)
    }
}
